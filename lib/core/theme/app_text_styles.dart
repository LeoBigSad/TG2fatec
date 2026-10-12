import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Tipografia baseada no Figma.
///
/// O Figma mistura Roboto, Poppins, Rubik e Inter; a maioria dos textos usa
/// Roboto, que também é a fonte padrão do Android, então ela foi adotada como
/// fonte única do app.
abstract final class AppTextStyles {
  static const _base = TextStyle(color: AppColors.textPrimary);

  /// Títulos de tela ("Acesse sua conta", "Bem-vindo (a),").
  static final title = _base.copyWith(fontSize: 24, fontWeight: FontWeight.w700);

  /// Títulos de seção e cabeçalhos ("Esqueci a senha", "Cadastre-se").
  static final heading = _base.copyWith(fontSize: 20, fontWeight: FontWeight.w600);

  /// Subtítulos e valores em destaque ("Orçamentos", "R$10.000,00").
  static final subtitle = _base.copyWith(fontSize: 16, fontWeight: FontWeight.w500);

  static final body = _base.copyWith(fontSize: 14);
  static final bodySmall = _base.copyWith(fontSize: 12);
  static final caption = _base.copyWith(fontSize: 10, color: AppColors.textSecondary);

  static final button = _base.copyWith(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    color: AppColors.onPrimary,
  );

  static final link = _base.copyWith(fontSize: 12, color: AppColors.link);

  /// Rótulo acima dos campos de formulário ("Nome da Transação").
  static final fieldLabel = _base.copyWith(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.textValue);

  /// Valores monetários de destaque.
  static final value = _base.copyWith(fontSize: 16, fontWeight: FontWeight.w500, color: AppColors.textValue);

  static TextTheme get textTheme => TextTheme(
        headlineSmall: title,
        titleLarge: heading,
        titleMedium: subtitle,
        bodyLarge: body.copyWith(fontSize: 16),
        bodyMedium: body,
        bodySmall: bodySmall,
        labelLarge: button,
        labelSmall: caption,
      );
}
