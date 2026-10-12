/// Leitura de extratos bancários (RF1 e RF2). Funções puras, sem I/O.
library;

import '../text_normalizer.dart';

class ParsedEntry {
  const ParsedEntry({required this.date, required this.description, required this.amountCents});

  final DateTime date;
  final String description;

  /// Negativo para débitos, positivo para créditos.
  final int amountCents;

  /// Chave usada para detectar lançamentos duplicados.
  String get dedupeKey => duplicateKey(date, amountCents, description);

  static String duplicateKey(DateTime date, int signedCents, String description) =>
      '${date.year}-${date.month}-${date.day}|$signedCents|${normalizeText(description)}';
}

class ParseResult {
  const ParseResult(this.entries, this.invalidLines);

  final List<ParsedEntry> entries;

  /// Linhas que pareciam lançamentos mas não puderam ser lidas.
  final int invalidLines;
}

class StatementFormatException implements Exception {
  const StatementFormatException(this.message);
  final String message;

  @override
  String toString() => message;
}

abstract final class StatementParser {
  // OFX

  static final _ofxBlock = RegExp(r'<STMTTRN>(.*?)(?:</STMTTRN>|(?=<STMTTRN>)|(?=</BANKTRANLIST>))',
      caseSensitive: false, dotAll: true);

  static ParseResult ofx(String content) {
    if (!RegExp('<OFX>', caseSensitive: false).hasMatch(content)) {
      throw const StatementFormatException('O arquivo não parece ser um extrato OFX.');
    }
    final entries = <ParsedEntry>[];
    var invalid = 0;
    for (final block in _ofxBlock.allMatches(content)) {
      final body = block.group(1)!;
      String? tag(String name) =>
          RegExp('<$name>([^<\r\n]+)', caseSensitive: false).firstMatch(body)?.group(1)?.trim();

      final rawDate = tag('DTPOSTED');
      final date = rawDate == null || rawDate.length < 8
          ? null
          : DateTime.tryParse('${rawDate.substring(0, 4)}-${rawDate.substring(4, 6)}-${rawDate.substring(6, 8)}');
      final amount = parseAmount(tag('TRNAMT') ?? '');
      final description = tag('MEMO') ?? tag('NAME') ?? '';
      if (date == null || amount == null || amount == 0) {
        invalid++;
        continue;
      }
      entries.add(ParsedEntry(
        date: date,
        description: description.isEmpty ? 'Lançamento' : description,
        amountCents: amount,
      ));
    }
    return ParseResult(entries, invalid);
  }

  // CSV

  static const _dateHeaders = {'data', 'date', 'dt', 'data lancamento', 'data da transacao', 'data movimento'};
  static const _descHeaders = {
    'descricao', 'description', 'historico', 'lancamento', 'memo', 'estabelecimento', 'titulo', 'title', 'detalhes',
  };
  static const _amountHeaders = {'valor', 'amount', 'value', 'quantia', 'valor (r\$)', 'valor r\$'};
  static const _debitHeaders = {'debito', 'saida', 'saidas'};
  static const _creditHeaders = {'credito', 'entrada', 'entradas'};
  static const _typeHeaders = {'tipo', 'type', 'd/c', 'natureza'};

  static ParseResult csv(String content) {
    final lines = content.split(RegExp(r'\r?\n')).where((l) => l.trim().isNotEmpty).toList();
    if (lines.isEmpty) throw const StatementFormatException('O arquivo está vazio.');
    final delimiter = _detectDelimiter(lines.first);
    final rows = lines.map((l) => _splitCsvLine(l, delimiter)).toList();

    final header = rows.first.map(normalizeText).toList();
    int find(Set<String> names) => header.indexWhere(names.contains);
    var dateCol = find(_dateHeaders);
    var descCol = find(_descHeaders);
    var amountCol = find(_amountHeaders);
    final debitCol = find(_debitHeaders);
    final creditCol = find(_creditHeaders);
    final typeCol = find(_typeHeaders);
    final hasHeader = dateCol >= 0 || descCol >= 0 || amountCol >= 0;

    if (!hasHeader) {
      // Sem cabeçalho: deduz as colunas pelo conteúdo da primeira linha.
      final first = rows.first;
      dateCol = first.indexWhere((c) => parseDate(c) != null);
      amountCol = first.lastIndexWhere((c) => parseAmount(c) != null && parseDate(c) == null);
      descCol = first.indexWhere((c) => parseDate(c) == null && parseAmount(c) == null && c.trim().isNotEmpty);
    }
    if (dateCol < 0 || (amountCol < 0 && debitCol < 0 && creditCol < 0)) {
      throw const StatementFormatException(
          'Não encontramos as colunas de data e valor. Verifique se o CSV possui as colunas "Data", "Descrição" e "Valor".');
    }

    final entries = <ParsedEntry>[];
    var invalid = 0;
    for (final row in hasHeader ? rows.skip(1) : rows) {
      String cell(int i) => i >= 0 && i < row.length ? row[i] : '';
      final date = parseDate(cell(dateCol));
      int? amount;
      if (amountCol >= 0) {
        amount = parseAmount(cell(amountCol));
        final type = normalizeText(cell(typeCol));
        if (amount != null && (type == 'd' || type.startsWith('deb'))) amount = -amount.abs();
        if (amount != null && (type == 'c' || type.startsWith('cred'))) amount = amount.abs();
      } else {
        final debit = parseAmount(cell(debitCol));
        final credit = parseAmount(cell(creditCol));
        amount = (debit != null && debit != 0) ? -debit.abs() : credit?.abs();
      }
      final description = cell(descCol).trim();
      if (date == null || amount == null || amount == 0) {
        invalid++;
        continue;
      }
      entries.add(ParsedEntry(
        date: date,
        description: description.isEmpty ? 'Lançamento' : description,
        amountCents: amount,
      ));
    }
    return ParseResult(entries, invalid);
  }

  static String _detectDelimiter(String line) {
    final counts = {';': ';'.allMatches(line).length, ',': ','.allMatches(line).length, '\t': '\t'.allMatches(line).length};
    return counts.entries.reduce((a, b) => b.value > a.value ? b : a).key;
  }

  static List<String> _splitCsvLine(String line, String delimiter) {
    final cells = <String>[];
    final b = StringBuffer();
    var quoted = false;
    for (var i = 0; i < line.length; i++) {
      final ch = line[i];
      if (ch == '"') {
        if (quoted && i + 1 < line.length && line[i + 1] == '"') {
          b.write('"');
          i++;
        } else {
          quoted = !quoted;
        }
      } else if (ch == delimiter && !quoted) {
        cells.add(b.toString().trim());
        b.clear();
      } else {
        b.write(ch);
      }
    }
    cells.add(b.toString().trim());
    return cells;
  }

  // PDF (texto já extraído)

  static final _amountPattern = r'[-+]?\s?(?:R\$\s?)?-?\(?\d{1,3}(?:\.\d{3})*,\d{2}\)?(?:\s?[DC](?![A-Za-z]))?';
  static final _pdfLine = RegExp(
    r'^(\d{2}/\d{2}(?:/\d{2,4})?)\s+(.+?)\s+(' + _amountPattern + r')(?:\s+(' + _amountPattern + r'))?\s*$',
  );
  static final _looksLikeEntry = RegExp(r'^\d{2}/\d{2}');
  static const _skipWords = ['saldo', 'total', 'saldo anterior', 'saldo do dia'];

  static ParseResult pdfText(String text, {int? fallbackYear}) {
    final year = fallbackYear ??
        int.tryParse(RegExp(r'\b(20\d{2})\b').firstMatch(text)?.group(1) ?? '') ??
        DateTime.now().year;
    final entries = <ParsedEntry>[];
    var invalid = 0;
    for (final raw in text.split(RegExp(r'\r?\n'))) {
      final line = raw.trim().replaceAll(RegExp(r'\s+'), ' ');
      if (!_looksLikeEntry.hasMatch(line)) continue;
      final m = _pdfLine.firstMatch(line);
      if (m == null) {
        invalid++;
        continue;
      }
      final description = m.group(2)!.trim();
      if (_skipWords.any((w) => normalizeText(description).startsWith(w))) continue;
      final date = parseDate(m.group(1)!, fallbackYear: year);
      final amount = parseAmount(m.group(3)!);
      if (date == null || amount == null || amount == 0) {
        invalid++;
        continue;
      }
      entries.add(ParsedEntry(date: date, description: description, amountCents: amount));
    }
    if (entries.isEmpty && invalid == 0) {
      throw const StatementFormatException(
          'Não encontramos lançamentos neste PDF. Verifique se é um extrato bancário com texto selecionável.');
    }
    return ParseResult(entries, invalid);
  }

  // Valores e datas

  /// Lê valores como `1.234,56`, `-1234.56`, `R$ 10,00`, `(50,00)` e `50,00 D`.
  static int? parseAmount(String raw) {
    var s = raw.trim().toUpperCase();
    if (s.isEmpty) return null;
    var negative = false;
    if (s.endsWith('D')) {
      negative = true;
      s = s.substring(0, s.length - 1);
    } else if (s.endsWith('C')) {
      s = s.substring(0, s.length - 1);
    }
    if (s.startsWith('(') && s.endsWith(')')) negative = true;
    if (s.contains('-')) negative = true;
    s = s.replaceAll(RegExp(r'[^\d.,]'), '');
    if (s.isEmpty || !RegExp(r'\d').hasMatch(s)) return null;

    final lastComma = s.lastIndexOf(',');
    final lastDot = s.lastIndexOf('.');
    String normalized;
    if (lastComma >= 0 && lastDot >= 0) {
      final decimal = lastComma > lastDot ? ',' : '.';
      final thousands = decimal == ',' ? '.' : ',';
      normalized = s.replaceAll(thousands, '').replaceAll(decimal, '.');
    } else if (lastComma >= 0) {
      normalized = s.replaceAll(',', '.');
    } else if (lastDot >= 0 && s.length - lastDot - 1 != 3) {
      normalized = s;
    } else {
      normalized = s.replaceAll('.', '');
    }
    if ('.'.allMatches(normalized).length > 1) return null;
    final value = double.tryParse(normalized);
    if (value == null) return null;
    final cents = (value * 100).round();
    return negative ? -cents : cents;
  }

  /// Aceita `dd/MM/yyyy`, `dd/MM/yy`, `dd-MM-yyyy`, `yyyy-MM-dd` e `dd/MM`.
  static DateTime? parseDate(String raw, {int? fallbackYear}) {
    final s = raw.trim();
    var m = RegExp(r'^(\d{4})-(\d{2})-(\d{2})').firstMatch(s);
    if (m != null) return _date(int.parse(m[1]!), int.parse(m[2]!), int.parse(m[3]!));
    m = RegExp(r'^(\d{1,2})[/.-](\d{1,2})(?:[/.-](\d{2,4}))?$').firstMatch(s);
    if (m == null) return null;
    int? year = m[3] == null ? fallbackYear : int.parse(m[3]!);
    if (year == null) return null;
    if (year < 100) year += 2000;
    return _date(year, int.parse(m[2]!), int.parse(m[1]!));
  }

  static DateTime? _date(int y, int m, int d) {
    if (m < 1 || m > 12 || d < 1 || d > 31) return null;
    final date = DateTime(y, m, d);
    return date.month == m ? date : null;
  }
}
