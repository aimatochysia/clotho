package io.github.aimatochysia.clotho

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.os.PowerManager
import android.provider.DocumentsContract
import android.provider.Settings
import java.io.File
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.Result

/**
 * Exposes the "All files access" permission to Dart (Clotho manages repositories
 * in any folder) and hands verified update APKs to the system installer.
 */
class MainActivity : FlutterActivity() {
    private var pendingPick: Result? = null
    private var pendingBattery: Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "clotho/storage")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "hasAllFilesAccess" -> result.success(hasAccess())
                    "requestAllFilesAccess" -> {
                        requestAccess()
                        result.success(null)
                    }
                    // Opens the system folder picker and answers with a real
                    // filesystem path (Git cannot work with content:// URIs).
                    "pickDirectory" -> {
                        pendingPick?.success(null)
                        pendingPick = result
                        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT_TREE).apply {
                            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                        }
                        try {
                            startActivityForResult(intent, PICK_DIRECTORY)
                        } catch (e: Exception) {
                            pendingPick = null
                            result.error("picker", e.message, null)
                        }
                    }
                    // Scheduled fetches only run on time while the app is
                    // closed when battery optimisation is off for Clotho.
                    "isIgnoringBatteryOptimizations" -> result.success(ignoringBattery())
                    "requestIgnoreBatteryOptimizations" -> {
                        if (ignoringBattery()) {
                            result.success(true)
                        } else {
                            pendingBattery?.success(ignoringBattery())
                            pendingBattery = result
                            try {
                                @Suppress("BatteryLife")
                                val intent = Intent(
                                    Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS,
                                    Uri.parse("package:$packageName"),
                                )
                                startActivityForResult(intent, BATTERY)
                            } catch (e: Exception) {
                                pendingBattery = null
                                // Some devices hide the dialog; fall back to the list.
                                try {
                                    startActivity(Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS))
                                } catch (_: Exception) {}
                                result.success(false)
                            }
                        }
                    }
                    else -> result.notImplemented()
                }
            }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "clotho/install")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    // Returns "started", or "permission" when the person first has to
                    // allow installs from Clotho (the settings page is opened).
                    "installApk" -> {
                        val path = call.argument<String>("path")
                        if (path == null) {
                            result.error("args", "path missing", null)
                        } else {
                            try {
                                result.success(installApk(File(path)))
                            } catch (e: Exception) {
                                result.error("install", e.message, null)
                            }
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }

    @Deprecated("Uses the platform activity result API for a single request.")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        if (requestCode == BATTERY) {
            pendingBattery?.success(ignoringBattery())
            pendingBattery = null
            return
        }
        if (requestCode != PICK_DIRECTORY) {
            super.onActivityResult(requestCode, resultCode, data)
            return
        }
        val result = pendingPick ?: return
        pendingPick = null
        val uri = data?.data
        if (resultCode != RESULT_OK || uri == null) {
            result.success(null)
            return
        }
        val path = treeUriToPath(uri)
        if (path == null) {
            result.error(
                "unsupported",
                "That location is not a folder on this device's storage. Pick a folder on internal storage or an SD card.",
                null,
            )
        } else {
            result.success(path)
        }
    }

    private fun ignoringBattery(): Boolean {
        val pm = getSystemService(POWER_SERVICE) as PowerManager
        return pm.isIgnoringBatteryOptimizations(packageName)
    }

    /** Maps a document-tree URI from the system picker to a filesystem path. */
    private fun treeUriToPath(uri: Uri): String? {
        val docId = try {
            DocumentsContract.getTreeDocumentId(uri)
        } catch (_: Exception) {
            return null
        }
        return when (uri.authority) {
            "com.android.externalstorage.documents" -> {
                val volume = docId.substringBefore(':')
                val rel = docId.substringAfter(':', "")
                val base = if (volume.equals("primary", ignoreCase = true)) {
                    Environment.getExternalStorageDirectory().path
                } else {
                    "/storage/$volume"
                }
                if (rel.isEmpty()) base else "$base/$rel"
            }
            "com.android.providers.downloads.documents" -> when {
                docId.startsWith("raw:") -> docId.removePrefix("raw:")
                docId == "downloads" -> Environment
                    .getExternalStoragePublicDirectory(Environment.DIRECTORY_DOWNLOADS).path
                else -> null
            }
            else -> null
        }?.takeIf { File(it).isDirectory }
    }

    private fun installApk(file: File): String {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O &&
            !packageManager.canRequestPackageInstalls()
        ) {
            startActivity(
                Intent(
                    Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES,
                    Uri.parse("package:$packageName"),
                ),
            )
            return "permission"
        }
        val uri = FileProvider.getUriForFile(this, "$packageName.updates", file)
        val intent = Intent(Intent.ACTION_VIEW).apply {
            setDataAndType(uri, "application/vnd.android.package-archive")
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_ACTIVITY_NEW_TASK)
        }
        startActivity(intent)
        return "started"
    }

    private fun hasAccess(): Boolean =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            Environment.isExternalStorageManager()
        } else {
            checkSelfPermission(Manifest.permission.WRITE_EXTERNAL_STORAGE) ==
                PackageManager.PERMISSION_GRANTED
        }

    private fun requestAccess() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            val intent = Intent(
                Settings.ACTION_MANAGE_APP_ALL_FILES_ACCESS_PERMISSION,
                Uri.parse("package:$packageName"),
            )
            try {
                startActivity(intent)
            } catch (_: Exception) {
                startActivity(Intent(Settings.ACTION_MANAGE_ALL_FILES_ACCESS_PERMISSION))
            }
        } else {
            requestPermissions(
                arrayOf(
                    Manifest.permission.READ_EXTERNAL_STORAGE,
                    Manifest.permission.WRITE_EXTERNAL_STORAGE,
                ),
                1,
            )
        }
    }
}

private const val PICK_DIRECTORY = 4101
private const val BATTERY = 4102
