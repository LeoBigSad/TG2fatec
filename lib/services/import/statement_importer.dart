import 'dart:convert';
import 'dart:typed_data';

import 'package:pdfrx/pdfrx.dart';

import '../../data/models/models.dart';
import 'statement_parser.dart';

/// Lançamento lido do extrato, pronto para revisão antes de importar.
class ImportCandidate {
  ImportCandidate(this.entry, {required this.duplicate, this.categoryId});

  final ParsedEntry entry;

  /// Já existe uma transação igual (mesma data, valor e descrição).
  final bool duplicate;
  int? categoryId;
  bool selected = true;

  TransactionType get type => entry.amountCents < 0 ? TransactionType.expense : TransactionType.income;
}

class ImportPreview {
  const ImportPreview({
    required this.fileName,
    required this.source,
    required this.candidates,
    required this.invalidLines,
    required this.duplicatesInFile,
  });

  final String fileName;
  final TransactionSource source;
  final List<ImportCandidate> candidates;
  final int invalidLines;

  /// Lançamentos repetidos dentro do próprio arquivo (descartados).
  final int duplicatesInFile;

  int get duplicates => candidates.where((c) => c.duplicate).length;
}

/// Lê o arquivo, identifica o formato e remove duplicidades (RF1 e RF2).
class StatementImporter {
  static const supportedExtensions = ['ofx', 'csv', 'pdf'];

  static TransactionSource? sourceFor(String fileName) => switch (fileName.split('.').last.toLowerCase()) {
        'ofx' => TransactionSource.ofx,
        'csv' => TransactionSource.csv,
        'pdf' => TransactionSource.pdf,
        _ => null,
      };

  Future<ImportPreview> preview({
    required String fileName,
    required Uint8List bytes,
    required Set<String> existingKeys,
    required int? Function(String description, TransactionType type) suggestCategory,
  }) async {
    final source = sourceFor(fileName);
    if (source == null) {
      throw const StatementFormatException('Formato não suportado. Use arquivos OFX, CSV ou PDF.');
    }
    if (bytes.isEmpty) throw const StatementFormatException('O arquivo está vazio.');

    final ParseResult result;
    try {
      result = switch (source) {
        TransactionSource.ofx => StatementParser.ofx(_decode(bytes)),
        TransactionSource.csv => StatementParser.csv(_decode(bytes)),
        TransactionSource.pdf => StatementParser.pdfText(await _pdfText(bytes)),
        TransactionSource.manual => throw StateError('manual'),
      };
    } on StatementFormatException {
      rethrow;
    } catch (_) {
      throw const StatementFormatException('Não foi possível ler o arquivo. Ele pode estar corrompido.');
    }

    final seen = <String>{};
    var duplicatesInFile = 0;
    final candidates = <ImportCandidate>[];
    for (final e in result.entries) {
      if (!seen.add(e.dedupeKey)) {
        duplicatesInFile++;
        continue;
      }
      final type = e.amountCents < 0 ? TransactionType.expense : TransactionType.income;
      final duplicate = existingKeys.contains(e.dedupeKey);
      candidates.add(ImportCandidate(e, duplicate: duplicate, categoryId: suggestCategory(e.description, type))
        ..selected = !duplicate);
    }
    return ImportPreview(
      fileName: fileName,
      source: source,
      candidates: candidates,
      invalidLines: result.invalidLines,
      duplicatesInFile: duplicatesInFile,
    );
  }

  /// Extratos brasileiros costumam vir em Latin-1 quando não são UTF-8.
  static String _decode(Uint8List bytes) {
    try {
      return utf8.decode(bytes);
    } on FormatException {
      return latin1.decode(bytes);
    }
  }

  static Future<String> _pdfText(Uint8List bytes) async {
    await pdfrxFlutterInitialize();
    final doc = await PdfDocument.openData(bytes);
    try {
      final b = StringBuffer();
      for (final page in doc.pages) {
        b.writeln((await page.loadText())?.fullText ?? '');
      }
      return b.toString();
    } finally {
      await doc.dispose();
    }
  }
}
