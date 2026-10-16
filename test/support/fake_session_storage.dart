import 'package:tg2fatec/services/session_storage.dart';

/// Armazenamento de sessão em memória para os testes.
class FakeSessionStorage implements SessionStorage {
  int? userId;
  DateTime? lastActivity;

  /// Simula o armazenamento seguro ilegível (chaves do Keystore perdidas).
  bool unreadable = false;

  @override
  Future<({int userId, DateTime lastActivity})?> read() async {
    if (unreadable) throw Exception('BadPaddingException');
    return userId == null || lastActivity == null ? null : (userId: userId!, lastActivity: lastActivity!);
  }

  @override
  Future<void> save(int userId, DateTime lastActivity) async {
    this.userId = userId;
    this.lastActivity = lastActivity;
  }

  @override
  Future<void> touch(DateTime lastActivity) async => this.lastActivity = lastActivity;

  @override
  Future<void> clear() async {
    userId = null;
    lastActivity = null;
  }
}
