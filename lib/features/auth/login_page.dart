import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/utils/validators.dart';
import '../../core/widgets/app_fields.dart';
import '../../core/widgets/app_sheet.dart';
import '../../state/session_controller.dart';
import 'auth_widgets.dart';
import 'forgot_password_page.dart';
import 'signup_page.dart';

/// Tela de Login (Figma: Login).
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      await context.read<SessionController>().login(_email.text, _password.text);
    } on AuthException catch (e) {
      if (mounted) showMessage(context, e.message, error: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenHorizontal),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: IntrinsicHeight(
                child: Form(
                  key: _formKey,
                  child: AutofillGroup(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Spacer(flex: 3),
                        Text('Acesse sua conta', style: AppTextStyles.title.copyWith(color: AppColors.primary)),
                        const SizedBox(height: AppSpacing.xs),
                        AuthField(
                          controller: _email,
                          hint: 'E-mail',
                          icon: Icons.mail_outline,
                          keyboardType: TextInputType.emailAddress,
                          autofillHints: const [AutofillHints.email],
                          validator: Validators.email,
                        ),
                        const SizedBox(height: 15),
                        AuthField(
                          controller: _password,
                          hint: 'Senha',
                          icon: Icons.lock_outline,
                          obscure: true,
                          textInputAction: TextInputAction.done,
                          autofillHints: const [AutofillHints.password],
                          validator: (v) => (v == null || v.isEmpty) ? 'Informe a senha' : null,
                          onSubmitted: (_) => _submit(),
                        ),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: () => Navigator.push(
                                context, MaterialPageRoute(builder: (_) => const ForgotPasswordPage())),
                            style: TextButton.styleFrom(
                              foregroundColor: const Color(0xFF2992F0),
                              padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                              textStyle: AppTextStyles.link.copyWith(decoration: TextDecoration.underline),
                            ),
                            child: const Text('Esqueci minha senha'),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        LoadingButton(label: 'Entrar', loading: _loading, onPressed: _submit),
                        const SizedBox(height: 35),
                        const _OrDivider(),
                        const SizedBox(height: 15),
                        Center(
                          child: OutlinedButton.icon(
                            onPressed: () => showMessage(context,
                                'O login com Google estará disponível quando o servidor do app for configurado.'),
                            icon: Image.asset('assets/images/google.png', width: 24, height: 24),
                            label: const Text('Google'),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Color(0xFFE4E9EF)),
                              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
                            ),
                          ),
                        ),
                        const Spacer(flex: 4),
                        Text.rich(
                          TextSpan(
                            text: 'Ainda não tem conta? ',
                            style: AppTextStyles.body.copyWith(color: AppColors.textPrimary),
                            children: [
                              TextSpan(
                                text: 'Cadastre-se.',
                                style: const TextStyle(color: AppColors.link, decoration: TextDecoration.underline),
                                recognizer: TapGestureRecognizer()
                                  ..onTap = () => Navigator.push(
                                      context, MaterialPageRoute(builder: (_) => const SignupPage())),
                              ),
                            ],
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: AppSpacing.xl),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _OrDivider extends StatelessWidget {
  const _OrDivider();

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: 0.6,
      child: Row(children: [
        const Expanded(child: Divider(color: AppColors.textHint)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          child: Text('ou continue com', style: AppTextStyles.bodySmall.copyWith(color: AppColors.textHint)),
        ),
        const Expanded(child: Divider(color: AppColors.textHint)),
      ]),
    );
  }
}
