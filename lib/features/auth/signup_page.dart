import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/utils/input_formatters.dart';
import '../../core/utils/validators.dart';
import '../../core/widgets/app_fields.dart';
import '../../core/widgets/app_sheet.dart';
import '../../state/session_controller.dart';
import 'auth_widgets.dart';
import 'terms_page.dart';
import 'verify_code_page.dart';

/// Cadastro (Figma: Sign up #1 e #2).
class SignupPage extends StatefulWidget {
  const SignupPage({super.key});

  @override
  State<SignupPage> createState() => _SignupPageState();
}

class _SignupPageState extends State<SignupPage> {
  static const _headerColor = Color(0xFFD2D5DB);

  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _phone = TextEditingController();
  bool _accepted = false;
  bool _showConsentError = false;
  bool _loading = false;

  @override
  void dispose() {
    for (final c in [_name, _email, _password, _phone]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    final valid = _formKey.currentState!.validate();
    setState(() => _showConsentError = !_accepted);
    if (!valid || !_accepted) return;

    final session = context.read<SessionController>();
    setState(() => _loading = true);
    try {
      await session.ensureEmailAvailable(_email.text);
    } on AuthException catch (e) {
      if (mounted) showMessage(context, e.message, error: true);
      return;
    } finally {
      if (mounted) setState(() => _loading = false);
    }
    if (!mounted) return;

    final method = await showContactMethodSheet(context);
    if (method == null || !mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => VerifyCodePage(
          title: 'Cadastre-se',
          email: _email.text.trim(),
          phone: PhoneInputFormatter.digitsOf(_phone.text),
          initialMethod: method,
          confirmLabel: 'Confirmar cadastro',
          onVerified: (ctx) => session.register(
            name: _name.text,
            email: _email.text,
            phone: _phone.text,
            password: _password.text,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _headerColor,
      appBar: flowAppBar('Cadastre-se', background: _headerColor),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl + 14)),
        ),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(AppSpacing.screenHorizontal, AppSpacing.xxl, AppSpacing.screenHorizontal, AppSpacing.lg),
            child: Form(
              key: _formKey,
              child: AutofillGroup(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('Bem-vindo (a),', style: AppTextStyles.title),
                    const SizedBox(height: AppSpacing.md),
                    AuthField(
                      controller: _name,
                      hint: 'Nome',
                      icon: Icons.account_circle,
                      autofillHints: const [AutofillHints.name],
                      validator: (v) => Validators.required(v, 'Nome'),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    AuthField(
                      controller: _email,
                      hint: 'E-mail',
                      icon: Icons.mail_outline,
                      keyboardType: TextInputType.emailAddress,
                      autofillHints: const [AutofillHints.email],
                      validator: Validators.email,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    AuthField(
                      controller: _password,
                      hint: 'Senha',
                      icon: Icons.lock_outline,
                      obscure: true,
                      autofillHints: const [AutofillHints.newPassword],
                      validator: Validators.password,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    AuthField(
                      controller: _phone,
                      hint: 'Telefone',
                      icon: Icons.phone_outlined,
                      keyboardType: TextInputType.phone,
                      textInputAction: TextInputAction.done,
                      inputFormatters: [PhoneInputFormatter()],
                      autofillHints: const [AutofillHints.telephoneNumberNational],
                      validator: Validators.phone,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Checkbox(
                          value: _accepted,
                          activeColor: AppColors.primary,
                          side: BorderSide(color: _showConsentError ? AppColors.error : AppColors.border),
                          onChanged: (v) => setState(() {
                            _accepted = v ?? false;
                            if (_accepted) _showConsentError = false;
                          }),
                        ),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(top: 12),
                            child: Text.rich(TextSpan(
                              text: 'Ao criar a sua conta você concorda com nossos ',
                              style: AppTextStyles.body,
                              children: [
                                TextSpan(
                                  text: 'Termos e Condições',
                                  style: const TextStyle(color: AppColors.link, decoration: TextDecoration.underline),
                                  recognizer: TapGestureRecognizer()
                                    ..onTap = () => Navigator.push(
                                        context, MaterialPageRoute(builder: (_) => const TermsPage())),
                                ),
                                const TextSpan(text: '.'),
                              ],
                            )),
                          ),
                        ),
                      ],
                    ),
                    if (_showConsentError)
                      Padding(
                        padding: const EdgeInsets.only(left: AppSpacing.md),
                        child: Text('Aceite os termos para continuar',
                            style: AppTextStyles.bodySmall.copyWith(color: AppColors.error)),
                      ),
                    const SizedBox(height: AppSpacing.lg),
                    LoadingButton(label: 'Cadastrar-se', loading: _loading, onPressed: _submit),
                    const SizedBox(height: AppSpacing.xxl),
                    Text.rich(
                      TextSpan(
                        text: 'Tem uma conta? ',
                        style: AppTextStyles.body.copyWith(color: const Color(0xFF343434)),
                        children: [
                          TextSpan(
                            text: 'Entre.',
                            style: const TextStyle(color: AppColors.link, decoration: TextDecoration.underline),
                            recognizer: TapGestureRecognizer()..onTap = () => Navigator.pop(context),
                          ),
                        ],
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
