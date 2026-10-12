import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Sessão persistida de forma criptografada (Android Keystore) via
/// Flutter Secure Storage.
class SessionStorage {
  SessionStorage([FlutterSecureStorage? storage]) : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  static const _userKey = 'session_user_id';
  static const _activityKey = 'session_last_activity';

  Future<({int userId, DateTime lastActivity})?> read() async {
    final id = int.tryParse(await _storage.read(key: _userKey) ?? '');
    final activity = DateTime.tryParse(await _storage.read(key: _activityKey) ?? '');
    if (id == null || activity == null) return null;
    return (userId: id, lastActivity: activity);
  }

  Future<void> save(int userId, DateTime lastActivity) async {
    await _storage.write(key: _userKey, value: '$userId');
    await touch(lastActivity);
  }

  Future<void> touch(DateTime lastActivity) =>
      _storage.write(key: _activityKey, value: lastActivity.toIso8601String());

  Future<void> clear() async {
    await _storage.delete(key: _userKey);
    await _storage.delete(key: _activityKey);
  }
}
