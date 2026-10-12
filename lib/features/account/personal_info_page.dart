import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/input_formatters.dart';
import '../../core/utils/validators.dart';
import '../../core/widgets/app_fields.dart';
import '../../core/widgets/app_sheet.dart';
import '../../state/session_controller.dart';
import '../auth/auth_widgets.dart';
import '../auth/change_password_page.dart';

/// Informações Pessoais (Figma: account #2), com edição, troca de senha e
/// exclusão da conta (LGPD).
class PersonalInfoPage extends StatefulWidget {
  const PersonalInfoPage({super.key});

  @override
  State<PersonalInfoPage> createState() => _PersonalInfoPageState();
}

class _PersonalInfoPageState extends State<PersonalInfoPage> {
  final _formKey = GlobalKey<FormState>();
  late final _session = context.read<SessionController>();
  late final _name = TextEditingController(text: _session.user!.name);
  late final _email = TextEditingController(text: _session.user!.email);
  late final _phone = TextEditingController(text: PhoneInputFormatter.format(_session.user!.phone));
  bool _saving = false;

  @override
  void dispose() {
    for (final c in [_name, _email, _phone]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await _session.updateProfile(name: _name.text, email: _email.text, phone: _phone.text);
      if (mounted) showMessage(context, 'Dados atualizados.');
    } on AuthException catch (e) {
      if (mounted) showMessage(context, e.message, error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _deleteAccount() async {
    final password = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text('Excluir conta', style: AppTextStyles.subtitle),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(
            'Todos os seus dados (transações, categorias, orçamentos e extratos) serão apagados '
            'definitivamente. Esta ação não pode ser desfeita.',
            style: AppTextStyles.body,
          ),
          const SizedBox(height: AppSpacing.md),
          LabeledField(label: 'Confirme sua senha', controller: password, obscure: true),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Excluir', style: AppTextStyles.body.copyWith(color: AppColors.error, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _session.deleteAccount(password.text);
    } on AuthException catch (e) {
      if (mounted) showMessage(context, e.message, error: true);
    } finally {
      password.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<SessionController>().user;
    if (user == null) return const Scaffold();
    return Scaffold(
      appBar: flowAppBar('Informações Pessoais'),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.md),
          children: [
            LabeledField(label: 'Nome', controller: _name, validator: (v) => Validators.required(v, 'Nome')),
            const SizedBox(height: AppSpacing.sm),
            LabeledField(
              label: 'E-mail',
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              validator: Validators.email,
            ),
            const SizedBox(height: AppSpacing.sm),
            LabeledField(
              label: 'Telefone',
              controller: _phone,
              keyboardType: TextInputType.phone,
              inputFormatters: [PhoneInputFormatter()],
              validator: Validators.phone,
              textInputAction: TextInputAction.done,
            ),
            const SizedBox(height: AppSpacing.lg),
            LoadingButton(label: 'Salvar alterações', loading: _saving, onPressed: _save),
            const SizedBox(height: AppSpacing.sm),
            OutlinedButton.icon(
              onPressed: () =>
                  Navigator.push(context, MaterialPageRoute(builder: (_) => ChangePasswordPage(userId: user.id!))),
              icon: const Icon(Icons.lock_reset),
              label: const Text('Mudar a senha'),
              style: OutlinedButton.styleFrom(foregroundColor: AppColors.textPrimary),
            ),
            const SizedBox(height: AppSpacing.xl),
            Text('Privacidade (LGPD)', style: AppTextStyles.subtitle),
            const SizedBox(height: AppSpacing.xxs),
            Text(
              'Conta criada em ${Fmt.date(user.createdAt)}. Consentimento com os termos registrado em '
              '${Fmt.date(user.consentAt)}.',
              style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: AppSpacing.sm),
            TextButton.icon(
              onPressed: _deleteAccount,
              icon: const Icon(Icons.delete_forever_outlined),
              label: const Text('Excluir minha conta e meus dados'),
              style: TextButton.styleFrom(foregroundColor: AppColors.error, alignment: Alignment.centerLeft),
            ),
          ],
        ),
      ),
    );
  }
}
