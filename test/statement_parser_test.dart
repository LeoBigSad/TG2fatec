import 'package:flutter_test/flutter_test.dart';
import 'package:tg2fatec/services/import/statement_parser.dart';

void main() {
  group('parseAmount', () {
    test('formatos brasileiros e internacionais', () {
      expect(StatementParser.parseAmount('1.234,56'), 123456);
      expect(StatementParser.parseAmount('-1.234,56'), -123456);
      expect(StatementParser.parseAmount('R\$ 10,00'), 1000);
      expect(StatementParser.parseAmount('-50.00'), -5000);
      expect(StatementParser.parseAmount('1,234.56'), 123456);
      expect(StatementParser.parseAmount('(45,90)'), -4590);
      expect(StatementParser.parseAmount('45,90 D'), -4590);
      expect(StatementParser.parseAmount('45,90 C'), 4590);
      expect(StatementParser.parseAmount('1.000'), 100000);
      expect(StatementParser.parseAmount('abc'), isNull);
    });
  });

  group('parseDate', () {
    test('formatos aceitos', () {
      expect(StatementParser.parseDate('20/10/2025'), DateTime(2025, 10, 20));
      expect(StatementParser.parseDate('20/10/25'), DateTime(2025, 10, 20));
      expect(StatementParser.parseDate('2025-10-20'), DateTime(2025, 10, 20));
      expect(StatementParser.parseDate('20/10', fallbackYear: 2024), DateTime(2024, 10, 20));
      expect(StatementParser.parseDate('31/02/2025'), isNull);
      expect(StatementParser.parseDate('texto'), isNull);
    });
  });

  test('OFX em SGML (tags sem fechamento)', () {
    const ofx = '''
OFXHEADER:100
<OFX><BANKMSGSRSV1><STMTTRNRS><STMTRS><BANKTRANLIST>
<STMTTRN><TRNTYPE>DEBIT<DTPOSTED>20251020120000[-3:BRT]<TRNAMT>-145.00<FITID>1<MEMO>LCBO
<STMTTRN><TRNTYPE>CREDIT<DTPOSTED>20251005<TRNAMT>10000.00<FITID>2<NAME>Salario
<STMTTRN><TRNTYPE>DEBIT<DTPOSTED>2025<TRNAMT>-1.00<FITID>3<MEMO>Data ruim
</BANKTRANLIST></STMTRS></STMTTRNRS></BANKMSGSRSV1></OFX>''';
    final r = StatementParser.ofx(ofx);
    expect(r.entries, hasLength(2));
    expect(r.invalidLines, 1);
    expect(r.entries[0].date, DateTime(2025, 10, 20));
    expect(r.entries[0].amountCents, -14500);
    expect(r.entries[0].description, 'LCBO');
    expect(r.entries[1].amountCents, 1000000);
    expect(r.entries[1].description, 'Salario');
  });

  test('OFX inválido gera mensagem amigável', () {
    expect(() => StatementParser.ofx('não é ofx'), throwsA(isA<StatementFormatException>()));
  });

  test('CSV com cabeçalho, ponto e vírgula e linha inválida', () {
    const csv = 'Data;Descrição;Valor\n'
        '20/10/2025;Supermercado;-50,00\n'
        '05/10/2025;"Salário; empresa";10.000,00\n'
        'xx;Linha quebrada;abc\n';
    final r = StatementParser.csv(csv);
    expect(r.entries, hasLength(2));
    expect(r.invalidLines, 1);
    expect(r.entries[1].description, 'Salário; empresa');
    expect(r.entries[1].amountCents, 1000000);
  });

  test('CSV com colunas de débito e crédito', () {
    const csv = 'date,description,debito,credito\n2025-10-01,Uber,23.50,\n2025-10-02,Pix recebido,,100.00\n';
    final r = StatementParser.csv(csv);
    expect(r.entries.map((e) => e.amountCents), [-2350, 10000]);
  });

  test('CSV sem cabeçalho deduz as colunas', () {
    final r = StatementParser.csv('20/10/2025,Farmácia,-30.00\n21/10/2025,Padaria,-12.00\n');
    expect(r.entries, hasLength(2));
    expect(r.entries.first.description, 'Farmácia');
  });

  test('CSV sem colunas reconhecíveis', () {
    expect(() => StatementParser.csv('a;b\nc;d'), throwsA(isA<StatementFormatException>()));
  });

  test('texto de PDF: lê lançamentos e ignora saldos', () {
    const text = '''
Extrato de conta corrente - Outubro 2025
Data Descrição Valor Saldo
01/10 SALDO ANTERIOR 1.000,00
02/10 PIX ENVIADO FULANO -150,00 850,00
05/10 SALARIO EMPRESA 5.000,00 5.850,00
07/10 COMPRA CARTAO MERCADO 89,90 D
09/10 PIX RECEBIDO +R\$ 1.200,00
08/10 LINHA QUEBRADA
''';
    final r = StatementParser.pdfText(text);
    expect(r.entries.map((e) => e.description), ['PIX ENVIADO FULANO', 'SALARIO EMPRESA', 'COMPRA CARTAO MERCADO', 'PIX RECEBIDO']);
    expect(r.entries.map((e) => e.amountCents), [-15000, 500000, -8990, 120000]);
    expect(r.entries.first.date, DateTime(2025, 10, 2));
    expect(r.invalidLines, 1);
  });

  test('chave de duplicidade ignora acentos, caixa e espaços', () {
    expect(
      ParsedEntry.duplicateKey(DateTime(2025, 1, 2), -100, 'Café  da Manhã'),
      ParsedEntry.duplicateKey(DateTime(2025, 1, 2), -100, 'cafe da manha'),
    );
  });
}
