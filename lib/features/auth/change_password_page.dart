import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_dimens.dart';
import '../../core/utils/validators.dart';
import '../../core/widgets/app_fields.dart';
import '../../core/widgets/app_sheet.dart';
import '../../state/session_controller.dart';
import 'auth_widgets.dart';

/// "Mudar a senha" (Figma: Change password #1).
class ChangePasswordPage extends StatefulWidget {
  const ChangePasswordPage({super.key, required this.userId});

  final int userId;

  @override
  State<ChangePasswordPage> createState() => _ChangePasswordPageState();
}

class _ChangePasswordPageState extends State<ChangePasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final session = context.read<SessionController>();
    setState(() => _loading = true);
    try {
      await session.resetPassword(widget.userId, _password.text);
      if (!mounted) return;
      if (session.isLoggedIn) {
        Navigator.pop(context);
        showMessage(context, 'Senha alterada com sucesso.');
      } else {
        Navigator.popUntil(context, (r) => r.isFirst);
        showMessage(context, 'Senha alterada. Entre com a nova senha.');
      }
    } on AuthException catch (e) {
      if (mounted) showMessage(context, e.message, error: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: flowAppBar('Mudar a senha'),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Form(
            key: _formKey,
            child: FormCard(children: [
              LabeledField(
                label: 'Digite a nova senha',
                controller: _password,
                obscure: true,
                validator: Validators.password,
              ),
              const SizedBox(height: AppSpacing.md),
              LabeledField(
                label: 'Confirme a senha',
                controller: _confirm,
                obscure: true,
                textInputAction: TextInputAction.done,
                validator: (v) => v != _password.text ? 'As senhas não conferem' : null,
              ),
              const SizedBox(height: AppSpacing.xl),
              LoadingButton(label: 'Mudar a senha', loading: _loading, onPressed: _submit),
            ]),
          ),
        ),
      ),
    );
  }
}
