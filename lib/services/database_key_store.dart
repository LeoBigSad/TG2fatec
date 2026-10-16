import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Chave de criptografia do banco local, gerada no primeiro uso e guardada
/// no armazenamento seguro do Android (Keystore).
class DatabaseKeyStore {
  DatabaseKeyStore([FlutterSecureStorage? storage]) : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  static const _storageKey = 'database_key';

  /// Retorna a chave e se ela acabou de ser criada. Uma chave nova significa
  /// que um banco criptografado já existente não pode mais ser aberto.
  Future<({String key, bool created})> obtain() async {
    try {
      final existing = await _storage.read(key: _storageKey);
      if (existing != null) return (key: existing, created: false);
    } catch (e) {
      // As chaves do Keystore não sobrevivem a uma restauração em outro
      // aparelho; nesse caso o conteúdo do armazenamento seguro é ilegível.
      debugPrint('Armazenamento seguro ilegível, recriando: $e');
      await _storage.deleteAll();
    }
    final random = Random.secure();
    final key = List.generate(32, (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0')).join();
    await _storage.write(key: _storageKey, value: key);
    return (key: key, created: true);
  }
}
