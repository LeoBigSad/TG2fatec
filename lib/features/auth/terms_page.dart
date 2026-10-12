import 'package:flutter/material.dart';

import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_text_styles.dart';
import 'auth_widgets.dart';

/// Termos e Condições e política de privacidade (LGPD).
class TermsPage extends StatelessWidget {
  const TermsPage({super.key});

  static const _sections = [
    (
      'Quais dados coletamos',
      'Nome, e-mail e telefone informados no cadastro, e as transações, categorias e orçamentos '
          'que você registra ou importa de extratos bancários. Coletamos apenas o necessário para o '
          'funcionamento do aplicativo.'
    ),
    (
      'Como usamos os dados',
      'Os dados são usados exclusivamente para exibir seus relatórios financeiros, sugerir categorias '
          'e orçamentos e enviar códigos de verificação. Não vendemos nem compartilhamos seus dados com terceiros.'
    ),
    (
      'Como protegemos os dados',
      'Sua senha é armazenada apenas como hash criptográfico (PBKDF2), e a sessão é guardada no '
          'armazenamento seguro do Android (Keystore). A sessão expira após 15 minutos sem uso. '
          'Operações importantes são registradas em um log de auditoria.'
    ),
    (
      'Seus direitos',
      'Conforme a Lei Geral de Proteção de Dados (Lei nº 13.709/2018), você pode consultar, corrigir e '
          'excluir seus dados a qualquer momento. A exclusão da conta, disponível em Perfil > '
          'Informações Pessoais, apaga definitivamente todos os seus dados do aplicativo.'
    ),
    (
      'Consentimento',
      'Ao criar a conta, você consente com o tratamento dos dados descrito acima. A data do '
          'consentimento é registrada.'
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: flowAppBar('Termos e Condições'),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.screenHorizontal),
        children: [
          for (final (title, body) in _sections) ...[
            Text(title, style: AppTextStyles.subtitle),
            const SizedBox(height: AppSpacing.xs),
            Text(body, style: AppTextStyles.body.copyWith(height: 1.5)),
            const SizedBox(height: AppSpacing.lg),
          ],
        ],
      ),
    );
  }
}
