import 'dart:math';

enum ContactMethod {
  email('E-mail'),
  sms('SMS');

  const ContactMethod(this.label);
  final String label;
}

/// Entrega do código ao usuário. Em produção, o backend envia por e-mail ou
/// SMS; enquanto não existe backend, o app usa uma entrega local.
abstract interface class CodeDelivery {
  Future<void> deliver(ContactMethod method, String destination, String code);
}

/// Códigos de confirmação de 4 dígitos, válidos por 10 minutos.
class VerificationService {
  VerificationService(this._delivery, {DateTime Function()? clock}) : _clock = clock ?? DateTime.now;

  final CodeDelivery _delivery;
  final DateTime Function() _clock;
  final _random = Random.secure();

  static const validity = Duration(minutes: 10);
  static const maxAttempts = 5;

  final _pending = <String, ({String code, DateTime expiresAt, int attempts})>{};

  Future<void> send(ContactMethod method, String destination) async {
    final code = (_random.nextInt(9000) + 1000).toString();
    _pending[destination] = (code: code, expiresAt: _clock().add(validity), attempts: 0);
    await _delivery.deliver(method, destination, code);
  }

  /// Retorna `null` se o código estiver correto, ou a mensagem de erro.
  String? verify(String destination, String code) {
    final entry = _pending[destination];
    if (entry == null) return 'Solicite um novo código.';
    if (_clock().isAfter(entry.expiresAt)) {
      _pending.remove(destination);
      return 'O código expirou. Reenvie o código.';
    }
    if (entry.attempts >= maxAttempts) {
      _pending.remove(destination);
      return 'Muitas tentativas. Reenvie o código.';
    }
    if (entry.code != code.trim()) {
      _pending[destination] = (code: entry.code, expiresAt: entry.expiresAt, attempts: entry.attempts + 1);
      return 'Código incorreto.';
    }
    _pending.remove(destination);
    return null;
  }
}
