package com.clotho.keystore;

import android.content.Context;
import android.os.Handler;
import android.os.Looper;
import android.security.keystore.KeyGenParameterSpec;
import android.security.keystore.KeyProperties;

import androidx.annotation.NonNull;

import java.io.ByteArrayOutputStream;
import java.io.File;
import java.io.FileInputStream;
import java.io.FileOutputStream;
import java.io.IOException;
import java.io.InputStream;
import java.nio.charset.StandardCharsets;
import java.security.KeyStore;
import java.util.Arrays;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.regex.Pattern;

import javax.crypto.Cipher;
import javax.crypto.KeyGenerator;
import javax.crypto.SecretKey;
import javax.crypto.spec.GCMParameterSpec;

import io.flutter.embedding.engine.plugins.FlutterPlugin;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;

/**
 * Saves small secrets as files in the app's no-backup folder, each encrypted
 * with AES-256-GCM under a key that never leaves the Android Keystore.
 *
 * Unlike a shared preferences store, a failed read never deletes anything,
 * and every write lands atomically (temp file, then rename), so a crash or a
 * concurrent background read cannot leave a half-written secret behind.
 */
public class ClothoKeystorePlugin implements FlutterPlugin, MethodChannel.MethodCallHandler {
    private static final String CHANNEL = "clotho/keystore";
    private static final String KEY_ALIAS = "clotho_secret_v1";
    private static final String KEYSTORE = "AndroidKeyStore";
    private static final String TRANSFORM = "AES/GCM/NoPadding";
    private static final int IV_LENGTH = 12;
    private static final int TAG_BITS = 128;
    private static final Pattern NAME = Pattern.compile("[A-Za-z0-9_]{1,64}");

    // Shared by every engine in the process (the app and background work),
    // so reads and writes never interleave.
    private static final Object LOCK = new Object();
    private static final ExecutorService WORKER = Executors.newSingleThreadExecutor();

    private final Handler main = new Handler(Looper.getMainLooper());
    private MethodChannel channel;
    private Context context;

    @Override
    public void onAttachedToEngine(@NonNull FlutterPluginBinding binding) {
        context = binding.getApplicationContext();
        channel = new MethodChannel(binding.getBinaryMessenger(), CHANNEL);
        channel.setMethodCallHandler(this);
    }

    @Override
    public void onDetachedFromEngine(@NonNull FlutterPluginBinding binding) {
        if (channel != null) channel.setMethodCallHandler(null);
        channel = null;
    }

    @Override
    public void onMethodCall(@NonNull MethodCall call, @NonNull MethodChannel.Result result) {
        final String method = call.method;
        final String key = call.argument("key");
        final String value = call.argument("value");
        WORKER.execute(() -> {
            try {
                if (key == null || !NAME.matcher(key).matches()) {
                    throw new IllegalArgumentException("bad key name");
                }
                Object out;
                synchronized (LOCK) {
                    switch (method) {
                        case "read":
                            out = read(key);
                            break;
                        case "write":
                            if (value == null) throw new IllegalArgumentException("missing value");
                            write(key, value);
                            out = null;
                            break;
                        case "delete":
                            delete(key);
                            out = null;
                            break;
                        default:
                            main.post(result::notImplemented);
                            return;
                    }
                }
                final Object reply = out;
                main.post(() -> result.success(reply));
            } catch (Exception e) {
                final String message = e.getClass().getSimpleName() + ": " + e.getMessage();
                main.post(() -> result.error("keystore", message, null));
            }
        });
    }

    private File dir() throws IOException {
        File d = new File(context.getNoBackupFilesDir(), "secrets");
        if (!d.isDirectory() && !d.mkdirs()) throw new IOException("cannot create " + d);
        return d;
    }

    private String read(String key) throws Exception {
        File f = new File(dir(), key + ".bin");
        if (!f.exists()) return null;
        byte[] data = readAll(f);
        if (data.length <= IV_LENGTH) throw new IOException("saved secret is too short");
        SecretKey secret = existingKey();
        if (secret == null) throw new IOException("the encryption key is missing from the Android Keystore");
        Cipher cipher = Cipher.getInstance(TRANSFORM);
        cipher.init(Cipher.DECRYPT_MODE, secret,
                new GCMParameterSpec(TAG_BITS, Arrays.copyOfRange(data, 0, IV_LENGTH)));
        byte[] plain = cipher.doFinal(data, IV_LENGTH, data.length - IV_LENGTH);
        return new String(plain, StandardCharsets.UTF_8);
    }

    private void write(String key, String value) throws Exception {
        Cipher cipher = Cipher.getInstance(TRANSFORM);
        cipher.init(Cipher.ENCRYPT_MODE, keyForWriting());
        byte[] iv = cipher.getIV();
        if (iv == null || iv.length != IV_LENGTH) throw new IOException("unexpected IV length");
        byte[] sealed = cipher.doFinal(value.getBytes(StandardCharsets.UTF_8));

        File d = dir();
        File tmp = new File(d, key + ".tmp");
        try (FileOutputStream out = new FileOutputStream(tmp)) {
            out.write(iv);
            out.write(sealed);
            out.getFD().sync();
        }
        File target = new File(d, key + ".bin");
        if (!tmp.renameTo(target)) {
            tmp.delete();
            throw new IOException("cannot save " + target);
        }
    }

    private void delete(String key) throws IOException {
        File f = new File(dir(), key + ".bin");
        if (f.exists() && !f.delete()) throw new IOException("cannot delete " + f);
    }

    private static SecretKey existingKey() throws Exception {
        KeyStore ks = KeyStore.getInstance(KEYSTORE);
        ks.load(null);
        return (SecretKey) ks.getKey(KEY_ALIAS, null);
    }

    private static SecretKey keyForWriting() throws Exception {
        SecretKey existing = existingKey();
        if (existing != null) return existing;
        KeyGenerator gen = KeyGenerator.getInstance(KeyProperties.KEY_ALGORITHM_AES, KEYSTORE);
        gen.init(new KeyGenParameterSpec.Builder(KEY_ALIAS,
                KeyProperties.PURPOSE_ENCRYPT | KeyProperties.PURPOSE_DECRYPT)
                .setBlockModes(KeyProperties.BLOCK_MODE_GCM)
                .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE)
                .setKeySize(256)
                .build());
        return gen.generateKey();
    }

    private static byte[] readAll(File f) throws IOException {
        try (InputStream in = new FileInputStream(f)) {
            ByteArrayOutputStream buf = new ByteArrayOutputStream();
            byte[] chunk = new byte[4096];
            int n;
            while ((n = in.read(chunk)) != -1) buf.write(chunk, 0, n);
            return buf.toByteArray();
        }
    }
}
