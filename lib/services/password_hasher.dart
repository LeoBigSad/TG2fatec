import 'dart:convert';
import 'dart:isolate';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

/// Hash de senha com PBKDF2-HMAC-SHA256 e salt aleatório (RNF1).
class PasswordHasher {
  const PasswordHasher({this.iterations = 100000});

  final int iterations;

  static final _random = Random.secure();

  String newSalt() => base64Encode(List<int>.generate(16, (_) => _random.nextInt(256)));

  /// Executa em outro isolate para não travar a interface.
  Future<String> hash(String password, String salt) {
    final it = iterations;
    return Isolate.run(() => base64Encode(pbkdf2(utf8.encode(password), base64Decode(salt), it, 32)));
  }

  Future<bool> verify(String password, String salt, String expectedHash) async {
    final actual = base64Decode(await hash(password, salt));
    final expected = base64Decode(expectedHash);
    if (actual.length != expected.length) return false;
    var diff = 0;
    for (var i = 0; i < actual.length; i++) {
      diff |= actual[i] ^ expected[i];
    }
    return diff == 0;
  }

  static Uint8List pbkdf2(List<int> password, List<int> salt, int iterations, int length) {
    final hmac = Hmac(sha256, password);
    final out = BytesBuilder();
    for (var block = 1; out.length < length; block++) {
      final blockIndex = [block >> 24 & 0xff, block >> 16 & 0xff, block >> 8 & 0xff, block & 0xff];
      var u = hmac.convert([...salt, ...blockIndex]).bytes;
      final t = Uint8List.fromList(u);
      for (var i = 1; i < iterations; i++) {
        u = hmac.convert(u).bytes;
        for (var j = 0; j < t.length; j++) {
          t[j] ^= u[j];
        }
      }
      out.add(t);
    }
    return out.toBytes().sublist(0, length);
  }
}
