import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/utils/input_formatters.dart';
import '../../core/utils/validators.dart';
import '../../core/widgets/app_fields.dart';
import '../../core/widgets/app_sheet.dart';
import '../../services/verification_service.dart';
import '../../state/session_controller.dart';
import 'auth_widgets.dart';
import 'change_password_page.dart';
import 'verify_code_page.dart';

/// "Esqueci a Senha" (Figma: Forgot password #1 e #4).
class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key, this.method = ContactMethod.email});

  final ContactMethod method;

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final _contact = TextEditingController();
  late ContactMethod _method = widget.method;
  bool _loading = false;

  bool get _isEmail => _method == ContactMethod.email;

  @override
  void dispose() {
    _contact.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final session = context.read<SessionController>();
    setState(() => _loading = true);
    final user = await session.findByContact(_contact.text);
    if (!mounted) return;
    setState(() => _loading = false);
    if (user == null) {
      showMessage(context, 'Não encontramos uma conta com esse ${_isEmail ? 'e-mail' : 'telefone'}.', error: true);
      return;
    }
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => VerifyCodePage(
          title: 'Esqueci a senha',
          email: user.email,
          phone: user.phone,
          initialMethod: _method,
          confirmLabel: 'Mudar a Senha',
          onVerified: (ctx) => Navigator.pushReplacement(
            ctx,
            MaterialPageRoute(builder: (_) => ChangePasswordPage(userId: user.id!)),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: flowAppBar('Esqueci a Senha'),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Form(
                key: _formKey,
                child: FormCard(children: [
                  Text(_isEmail ? 'Digite o seu E-mail' : 'Digite o seu número de telefone',
                      style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary)),
                  const SizedBox(height: AppSpacing.xs),
                  TextFormField(
                    key: ValueKey(_method),
                    controller: _contact,
                    autofocus: true,
                    keyboardType: _isEmail ? TextInputType.emailAddress : TextInputType.phone,
                    inputFormatters: _isEmail ? null : [PhoneInputFormatter()],
                    validator: _isEmail ? Validators.email : Validators.phone,
                    style: AppTextStyles.body,
                    decoration: outlinedDecoration(hint: _isEmail ? 'nome@email.com' : '(00) 00000-0000').copyWith(
                      prefixText: _isEmail ? null : '+55 ',
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text('Nós enviaremos um código para confirmar sua identidade.',
                      style: AppTextStyles.body.copyWith(color: AppColors.textSecondary)),
                  const SizedBox(height: AppSpacing.lg),
                  LoadingButton(label: 'Enviar', loading: _loading, onPressed: _submit),
                ]),
              ),
              const SizedBox(height: AppSpacing.lg),
              TextButton(
                onPressed: () async {
                  final m = await showContactMethodSheet(context, initial: _method);
                  if (m != null && m != _method) {
                    setState(() {
                      _method = m;
                      _contact.clear();
                    });
                  }
                },
                style: TextButton.styleFrom(
                    foregroundColor: AppColors.textPrimary,
                    textStyle: AppTextStyles.body.copyWith(fontWeight: FontWeight.w500)),
                child: const Text('Escolha um tipo diferente de envio.'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
