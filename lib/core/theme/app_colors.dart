import 'package:flutter/material.dart';

/// Paleta extraída do Figma (arquivo TGII).
///
/// O arquivo não possui estilos de cor definidos; os valores abaixo foram
/// consolidados a partir das cores efetivamente usadas nas telas.
abstract final class AppColors {
  // Fundos
  static const background = Color(0xFFF7FAFE);
  static const surface = Color(0xFFFFFFFF);
  static const surfaceAlt = Color(0xFFFBFCFB);
  static const bottomBar = Color(0xFF2D2C2C);

  // Ações primárias (botões pretos)
  static const primary = Color(0xFF000000);
  static const onPrimary = Color(0xFFFFFFFF);

  // Texto
  static const textPrimary = Color(0xFF0C0C0C);
  static const textValue = Color(0xFF333333);
  static const textSecondary = Color(0xFF868686);
  static const textTertiary = Color(0xFFADADAD);
  static const textMuted = Color(0xFFB1B1B1);
  static const textHint = Color(0xFF7A8A98);
  static const link = Color(0xFF0088FF);

  // Bordas e divisores
  static const border = Color(0xFFCBCBCB);
  static const divider = Color(0xFFDADADA);
  static const disabled = Color(0xFFC4C4C4);

  // Destaques
  static const accent = Color(0xFF125A93);
  static const accentDark = Color(0xFF1F436D);

  // Semânticas financeiras
  static const income = Color(0xFF34C759);
  static const expense = Color(0xFFFF383C);
  static const balance = Color(0xFF6155F5);

  // Estados
  static const success = Color(0xFF009618);
  static const warning = Color(0xFFFF9900);
  static const error = Color(0xFFC30000);
}

/// Cores das categorias de despesa, como aparecem nas telas de Orçamento.
abstract final class CategoryColors {
  static const alimentacao = Color(0xFF87C55F);
  static const roupas = Color(0xFFC9DB74);
  static const beleza = Color(0xFFEE9D95);
  static const transporte = Color(0xFFDCB0F2);
  static const remedios = Color(0xFF1F436D);

  static const all = [alimentacao, roupas, beleza, transporte, remedios];
}
