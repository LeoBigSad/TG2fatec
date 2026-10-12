import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_colors.dart';
import '../theme/app_dimens.dart';
import '../theme/app_text_styles.dart';

/// Sombra suave dos campos das telas de autenticação (Figma: Input).
const fieldShadow = [
  BoxShadow(color: Color(0x0A00255B), offset: Offset(0, 32), blurRadius: 24, spreadRadius: -16),
];

/// Campo branco com ícone, usado no Login e no Cadastro.
class AuthField extends StatefulWidget {
  const AuthField({
    super.key,
    required this.controller,
    required this.hint,
    required this.icon,
    this.obscure = false,
    this.keyboardType,
    this.textInputAction = TextInputAction.next,
    this.validator,
    this.inputFormatters,
    this.autofillHints,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final bool obscure;
  final TextInputType? keyboardType;
  final TextInputAction textInputAction;
  final FormFieldValidator<String>? validator;
  final List<TextInputFormatter>? inputFormatters;
  final Iterable<String>? autofillHints;
  final ValueChanged<String>? onSubmitted;

  @override
  State<AuthField> createState() => _AuthFieldState();
}

class _AuthFieldState extends State<AuthField> {
  late bool _hidden = widget.obscure;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(AppRadius.md), boxShadow: fieldShadow),
      child: TextFormField(
        controller: widget.controller,
        obscureText: _hidden,
        keyboardType: widget.keyboardType,
        textInputAction: widget.textInputAction,
        validator: widget.validator,
        inputFormatters: widget.inputFormatters,
        autofillHints: widget.autofillHints,
        onFieldSubmitted: widget.onSubmitted,
        style: AppTextStyles.body,
        decoration: InputDecoration(
          hintText: widget.hint,
          prefixIcon: Icon(widget.icon, size: AppSizes.icon),
          suffixIcon: widget.obscure
              ? IconButton(
                  tooltip: _hidden ? 'Mostrar senha' : 'Ocultar senha',
                  icon: Icon(_hidden ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                  onPressed: () => setState(() => _hidden = !_hidden),
                )
              : null,
        ),
      ),
    );
  }
}

/// Campo com rótulo acima, usado nos formulários em bottom sheet.
class LabeledField extends StatefulWidget {
  const LabeledField({
    super.key,
    required this.label,
    this.controller,
    this.hint,
    this.keyboardType,
    this.validator,
    this.inputFormatters,
    this.obscure = false,
    this.readOnly = false,
    this.enabled = true,
    this.onTap,
    this.suffixIcon,
    this.prefixText,
    this.maxLines = 1,
    this.textInputAction = TextInputAction.next,
    this.onChanged,
  });

  final String label;
  final TextEditingController? controller;
  final String? hint;
  final TextInputType? keyboardType;
  final FormFieldValidator<String>? validator;
  final List<TextInputFormatter>? inputFormatters;
  final bool obscure;
  final bool readOnly;
  final bool enabled;
  final VoidCallback? onTap;
  final Widget? suffixIcon;
  /// Texto fixo antes do valor, como `R$ `.
  final String? prefixText;
  final int maxLines;
  final TextInputAction textInputAction;
  final ValueChanged<String>? onChanged;

  @override
  State<LabeledField> createState() => _LabeledFieldState();
}

class _LabeledFieldState extends State<LabeledField> {
  late bool _hidden = widget.obscure;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(widget.label, style: AppTextStyles.fieldLabel),
        const SizedBox(height: AppSpacing.xxs),
        TextFormField(
          controller: widget.controller,
          keyboardType: widget.keyboardType,
          validator: widget.validator,
          inputFormatters: widget.inputFormatters,
          obscureText: _hidden,
          readOnly: widget.readOnly,
          enabled: widget.enabled,
          onTap: widget.onTap,
          maxLines: widget.maxLines,
          textInputAction: widget.textInputAction,
          onChanged: widget.onChanged,
          style: AppTextStyles.body,
          decoration: outlinedDecoration(
            hint: widget.hint,
            prefixText: widget.prefixText,
            suffixIcon: widget.obscure
                ? IconButton(
                    tooltip: _hidden ? 'Mostrar senha' : 'Ocultar senha',
                    icon: Icon(_hidden ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 20),
                    onPressed: () => setState(() => _hidden = !_hidden),
                  )
                : widget.suffixIcon,
          ),
        ),
      ],
    );
  }
}

InputDecoration outlinedDecoration({String? hint, Widget? suffixIcon, String? prefixText}) {
  OutlineInputBorder border(Color color) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        borderSide: BorderSide(color: color),
      );
  return InputDecoration(
    hintText: hint,
    hintStyle: AppTextStyles.body.copyWith(color: AppColors.textTertiary),
    isDense: true,
    constraints: const BoxConstraints(minHeight: 40),
    contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 11),
    suffixIcon: suffixIcon,
    prefixText: prefixText,
    prefixStyle: AppTextStyles.body,
    suffixIconColor: AppColors.textSecondary,
    border: border(AppColors.border),
    enabledBorder: border(AppColors.border),
    disabledBorder: border(AppColors.divider),
    focusedBorder: border(AppColors.primary),
    errorBorder: border(AppColors.error),
    focusedErrorBorder: border(AppColors.error),
  );
}

/// Campo que abre um seletor ao ser tocado (categoria, data...).
class PickerField extends StatelessWidget {
  const PickerField({
    super.key,
    required this.label,
    required this.value,
    required this.onTap,
    this.hint = 'Selecione',
    this.leading,
    this.trailingIcon = Icons.keyboard_arrow_down,
    this.errorText,
  });

  final String label;
  final String? value;
  final String hint;
  final Widget? leading;
  final IconData trailingIcon;
  final VoidCallback onTap;
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTextStyles.fieldLabel),
        const SizedBox(height: AppSpacing.xxs),
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.md),
          child: InputDecorator(
            isEmpty: value == null,
            decoration: outlinedDecoration(hint: hint, suffixIcon: Icon(trailingIcon, size: 20))
                .copyWith(errorText: errorText),
            child: value == null
                ? null
                : Row(children: [
                    if (leading != null) ...[leading!, const SizedBox(width: AppSpacing.xs)],
                    Expanded(child: Text(value!, style: AppTextStyles.body, overflow: TextOverflow.ellipsis)),
                  ]),
          ),
        ),
      ],
    );
  }
}
