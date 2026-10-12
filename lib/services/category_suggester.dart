import '../data/models/models.dart';
import 'text_normalizer.dart';

/// Sugere a categoria de uma transação (RF9): primeiro pelo histórico de
/// transações com descrição parecida; depois por palavras-chave conhecidas.
class CategorySuggester {
  const CategorySuggester(this.categories, this.history);

  final List<FinanceCategory> categories;
  final List<FinanceTransaction> history;

  static const _keywordsByCategory = {
    'mercado': ['mercado', 'supermercado', 'carrefour', 'assai', 'atacadao', 'pao de acucar', 'extra', 'hortifruti', 'walmart'],
    'restaurante': ['restaurante', 'ifood', 'lanchonete', 'pizzaria', 'burger', 'mcdonalds', 'outback', 'padaria', 'bar '],
    'alimentacao': ['alimentacao', 'comida', 'lanche', 'acougue'],
    'transporte': ['uber', '99app', '99 pop', 'posto', 'combustivel', 'gasolina', 'onibus', 'metro', 'estacionamento', 'pedagio', 'shell', 'ipiranga'],
    'remedios': ['farmacia', 'drogaria', 'droga raia', 'drogasil', 'pague menos', 'remedio', 'cvs'],
    'contas': ['energia', 'luz', 'agua', 'sabesp', 'cpfl', 'internet', 'telefone', 'aluguel', 'condominio', 'vivo', 'claro', 'tim', 't-mobile', 'boleto'],
    'beleza': ['salao', 'barbearia', 'cabeleireiro', 'manicure', 'estetica', 'boticario', 'natura', 'sephora'],
    'roupas': ['renner', 'riachuelo', 'zara', 'c&a', 'hering', 'centauro', 'moda', 'roupa', 'calcados'],
    'entretenimento': ['netflix', 'spotify', 'cinema', 'disney', 'prime video', 'steam', 'playstation', 'ingresso', 'show'],
    'salario': ['salario', 'folha', 'pagamento salario', 'proventos'],
    'investimentos': ['rendimento', 'dividendo', 'juros', 'resgate', 'cdb', 'tesouro'],
  };

  FinanceCategory? suggest(String description, TransactionType type) {
    final candidates = categories.where((c) => c.type == type).toList();
    if (candidates.isEmpty || description.trim().isEmpty) return null;
    final ids = candidates.map((c) => c.id).toSet();

    // 1. Histórico: transações com palavras em comum.
    final words = keywords(description);
    if (words.isNotEmpty) {
      final votes = <int, double>{};
      for (final t in history) {
        if (t.categoryId == null || !ids.contains(t.categoryId) || t.type != type) continue;
        final other = keywords(t.title);
        if (other.isEmpty) continue;
        final common = words.intersection(other).length;
        final similarity = common / words.union(other).length;
        if (similarity >= 0.5) votes[t.categoryId!] = (votes[t.categoryId!] ?? 0) + similarity;
      }
      if (votes.isNotEmpty) {
        final best = votes.entries.reduce((a, b) => b.value > a.value ? b : a).key;
        return candidates.firstWhere((c) => c.id == best);
      }
    }

    // 2. Palavras-chave conhecidas.
    final text = ' ${normalizeText(description)} ';
    for (final entry in _keywordsByCategory.entries) {
      if (!entry.value.any(text.contains)) continue;
      for (final c in candidates) {
        if (normalizeText(c.name) == entry.key) return c;
      }
    }
    return null;
  }
}
