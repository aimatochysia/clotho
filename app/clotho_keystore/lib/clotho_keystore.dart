import 'package:flutter/services.dart';

/// Secrets saved in app-private files and encrypted with an Android Keystore
/// key. Android only. A failed read throws and never deletes anything.
class ClothoKeystore {
  const ClothoKeystore();

  static const channel = MethodChannel('clotho/keystore');

  Future<String?> read(String key) =>
      channel.invokeMethod<String>('read', {'key': key});

  Future<void> write(String key, String value) =>
      channel.invokeMethod<void>('write', {'key': key, 'value': value});

  Future<void> delete(String key) =>
      channel.invokeMethod<void>('delete', {'key': key});
}
