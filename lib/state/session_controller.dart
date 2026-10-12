import 'package:flutter/foundation.dart';

import '../core/utils/input_formatters.dart';
import '../data/models/models.dart';
import '../data/repositories.dart';
import '../services/password_hasher.dart';
import '../services/session_storage.dart';

class AuthException implements Exception {
  const AuthException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Cadastro, login e sessão do usuário (RNF1).
class SessionController extends ChangeNotifier {
  SessionController({
    required this._users,
    required this._storage,
    required this._audit,
    this._hasher = const PasswordHasher(),
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final UserRepository _users;
  final SessionStorage _storage;
  final AuditLog _audit;
  final PasswordHasher _hasher;
  final DateTime Function() _clock;

  /// A sessão expira após este tempo sem uso.
  static const inactivityTimeout = Duration(minutes: 15);

  AppUser? _user;
  AppUser? get user => _user;
  bool get isLoggedIn => _user != null;

  bool _restoring = true;
  bool get restoring => _restoring;

  DateTime _lastActivity = DateTime.fromMillisecondsSinceEpoch(0);
  bool _expiredByInactivity = false;

  /// Indica (uma única vez) que a última sessão expirou por inatividade.
  bool consumeExpiredFlag() {
    final value = _expiredByInactivity;
    _expiredByInactivity = false;
    return value;
  }

  Future<void> restore() async {
    try {
      final saved = await _storage.read();
      if (saved == null) return;
      if (_clock().difference(saved.lastActivity) > inactivityTimeout) {
        await _storage.clear();
        _expiredByInactivity = true;
        return;
      }
      _user = await _users.byId(saved.userId);
      if (_user == null) {
        await _storage.clear();
      } else {
        await _touch(force: true);
      }
    } finally {
      _restoring = false;
      notifyListeners();
    }
  }

  Future<void> login(String email, String password) async {
    final user = await _users.byEmail(email);
    if (user == null || !await _hasher.verify(password, user.passwordSalt, user.passwordHash)) {
      await _audit.record(user?.id, 'login_failed');
      throw const AuthException('E-mail ou senha incorretos.');
    }
    await _start(user);
    await _audit.record(user.id, 'login');
  }

  Future<void> ensureEmailAvailable(String email) async {
    if (await _users.byEmail(email) != null) {
      throw const AuthException('Já existe uma conta com este e-mail.');
    }
  }

  Future<void> register({
    required String name,
    required String email,
    required String phone,
    required String password,
  }) async {
    await ensureEmailAvailable(email);
    final salt = _hasher.newSalt();
    final now = _clock();
    final user = await _users.create(AppUser(
      name: name.trim(),
      email: email.trim(),
      phone: PhoneInputFormatter.digitsOf(phone),
      passwordHash: await _hasher.hash(password, salt),
      passwordSalt: salt,
      createdAt: now,
      consentAt: now,
    ));
    await _audit.record(user.id, 'user_created');
    await _start(user);
  }

  /// Localiza a conta pelo e-mail ou telefone (recuperação de senha).
  Future<AppUser?> findByContact(String contact) => contact.contains('@')
      ? _users.byEmail(contact)
      : _users.byPhone(PhoneInputFormatter.digitsOf(contact));

  Future<void> resetPassword(int userId, String newPassword) async {
    final user = await _users.byId(userId);
    if (user == null) throw const AuthException('Conta não encontrada.');
    final salt = _hasher.newSalt();
    final updated = user.copyWith(passwordHash: await _hasher.hash(newPassword, salt), passwordSalt: salt);
    await _users.update(updated);
    await _audit.record(userId, 'password_changed');
    if (_user?.id == userId) {
      _user = updated;
      notifyListeners();
    }
  }

  Future<void> updateProfile({required String name, required String email, required String phone}) async {
    final current = _user!;
    if (email.trim().toLowerCase() != current.email.toLowerCase()) await ensureEmailAvailable(email);
    final updated = current.copyWith(name: name.trim(), email: email.trim(), phone: PhoneInputFormatter.digitsOf(phone));
    await _users.update(updated);
    await _audit.record(current.id, 'profile_updated');
    _user = updated;
    notifyListeners();
  }

  /// Exclui a conta e todos os dados do usuário (LGPD, direito ao esquecimento).
  Future<void> deleteAccount(String password) async {
    final current = _user!;
    if (!await _hasher.verify(password, current.passwordSalt, current.passwordHash)) {
      throw const AuthException('Senha incorreta.');
    }
    await _users.delete(current.id!);
    await _audit.record(current.id, 'user_deleted');
    await logout(record: false);
  }

  Future<void> logout({bool record = true}) async {
    if (record && _user != null) await _audit.record(_user!.id, 'logout');
    _user = null;
    await _storage.clear();
    notifyListeners();
  }

  /// Chamado a cada interação do usuário com o app.
  void registerActivity() => _touch();

  /// Ao voltar do segundo plano, encerra a sessão se ficou inativa demais.
  Future<void> checkInactivity() async {
    if (_user == null) return;
    if (_clock().difference(_lastActivity) > inactivityTimeout) {
      _expiredByInactivity = true;
      await logout();
    } else {
      await _touch(force: true);
    }
  }

  Future<void> _start(AppUser user) async {
    _user = user;
    _lastActivity = _clock();
    await _storage.save(user.id!, _lastActivity);
    notifyListeners();
  }

  Future<void> _touch({bool force = false}) async {
    if (_user == null) return;
    final now = _clock();
    // Evita gravar no armazenamento seguro a cada toque.
    if (!force && now.difference(_lastActivity) < const Duration(seconds: 30)) return;
    _lastActivity = now;
    await _storage.touch(now);
  }
}
