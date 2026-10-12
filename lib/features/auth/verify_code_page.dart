import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/utils/input_formatters.dart';
import '../../core/widgets/app_fields.dart';
import '../../core/widgets/app_sheet.dart';
import '../../services/verification_service.dart';
import '../../state/session_controller.dart';
import 'auth_widgets.dart';

String describeDestination(ContactMethod method, String email, String phoneDigits) =>
    method == ContactMethod.email ? email : '+55 ${PhoneInputFormatter.format(phoneDigits)}';

/// "Digite o código" (Figma: Forgot password #2 e #5).
class VerifyCodePage extends StatefulWidget {
  const VerifyCodePage({
    super.key,
    required this.title,
    required this.email,
    required this.phone,
    required this.initialMethod,
    required this.confirmLabel,
    required this.onVerified,
  });

  final String title;
  final String email;
  final String phone;
  final ContactMethod initialMethod;
  final String confirmLabel;

  /// Executado após o código ser confirmado.
  final Future<void> Function(BuildContext context) onVerified;

  @override
  State<VerifyCodePage> createState() => _VerifyCodePageState();
}

class _VerifyCodePageState extends State<VerifyCodePage> {
  final _code = TextEditingController();
  late ContactMethod _method = widget.initialMethod;
  String? _error;
  bool _loading = false;

  String get _destination => describeDestination(_method, widget.email, widget.phone);
  String get _key => _method == ContactMethod.email ? widget.email : widget.phone;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _send());
  }

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _send() => context.read<VerificationService>().send(_method, _key);

  Future<void> _resend() async {
    _code.clear();
    setState(() => _error = null);
    await _send();
  }

  Future<void> _changeMethod() async {
    final method = await showContactMethodSheet(context, initial: _method);
    if (method == null || !mounted) return;
    setState(() => _method = method);
    await _resend();
  }

  Future<void> _confirm() async {
    final error = context.read<VerificationService>().verify(_key, _code.text);
    setState(() => _error = error);
    if (error != null) return;
    setState(() => _loading = true);
    try {
      await widget.onVerified(context);
    } on AuthException catch (e) {
      if (mounted) showMessage(context, e.message, error: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: flowAppBar(widget.title),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              FormCard(children: [
                Text('Digite o código', style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary)),
                const SizedBox(height: AppSpacing.xs),
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Expanded(
                    child: TextField(
                      controller: _code,
                      autofocus: true,
                      keyboardType: TextInputType.number,
                      maxLength: 4,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      onSubmitted: (_) => _confirm(),
                      style: AppTextStyles.body.copyWith(letterSpacing: 4),
                      decoration: outlinedDecoration(hint: '0000').copyWith(counterText: '', errorText: _error),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  SizedBox(
                    height: 40,
                    child: FilledButton(
                      onPressed: _resend,
                      style: FilledButton.styleFrom(minimumSize: const Size(0, 40), padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md)),
                      child: const Text('Reenviar'),
                    ),
                  ),
                ]),
                const SizedBox(height: AppSpacing.md),
                Text('Nós enviamos um código para $_destination.',
                    style: AppTextStyles.body.copyWith(color: AppColors.textSecondary)),
                const SizedBox(height: AppSpacing.xs),
                Text('O código irá expirar em 10 minutos, reenvie-o caso necessário.',
                    style: AppTextStyles.body.copyWith(color: AppColors.textSecondary)),
                const SizedBox(height: AppSpacing.lg),
                LoadingButton(label: widget.confirmLabel, loading: _loading, onPressed: _confirm),
              ]),
              const SizedBox(height: AppSpacing.lg),
              TextButton(
                onPressed: _changeMethod,
                style: TextButton.styleFrom(foregroundColor: AppColors.textPrimary, textStyle: AppTextStyles.body.copyWith(fontWeight: FontWeight.w500)),
                child: const Text('Escolha um tipo diferente de envio.'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
