# TGII — Gestão Financeira Pessoal

Aplicativo Android em Flutter para controle de receitas, despesas e orçamentos.
Trabalho de Graduação II — Fatec Campinas (ADS), 2026.

- Design: [Figma TGII](https://www.figma.com/design/O5ZJygVsQ6H4NFV0TlFSmz/TGII)
- Somente Android (o projeto não possui a plataforma iOS).

## Como executar

```bash
flutter pub get
flutter run
```

Testes:

```bash
flutter test
```

Neste computador, o Gradle falha com `Unable to establish loopback connection`
se a variável abaixo não estiver definida antes do build:

```powershell
$env:JAVA_TOOL_OPTIONS = '-Djdk.net.unixdomain.tmpdir=C:\gradle-tmp'
```

Extratos de exemplo para testar a importação estão em `samples/`.

## Arquitetura

O app é **local-first**: os dados ficam em SQLite no aparelho. Cada fonte de dados
fica atrás de um repositório (`lib/data/repositories.dart`), que poderá passar a
falar com o servidor (AWS) sem alterar as telas.

```
lib/
  core/        tema (tokens do Figma), formatadores e widgets reutilizáveis
  data/        modelos, banco SQLite e repositórios
  services/    regras de negócio puras (importação, estatísticas, sugestões,
               calculadoras, relatórios, hash de senha, códigos de verificação)
  state/       SessionController (login/sessão) e FinanceController (dados)
  features/    telas, uma pasta por área do app
```

## Requisitos atendidos

| Requisito | Onde |
|---|---|
| RF1/RF2 Importar extrato OFX, CSV e PDF, com detecção de duplicidades | `services/import/`, Transações › Novo › Importar extrato |
| RF3/RF4 Alterar transações e excluir extratos importados | Transações (⋮), Menu › Extratos importados |
| RF5 Nova receita/despesa | Transações › Novo › Manual |
| RF6–RF8 Categorias | Menu › Categorias |
| RF9 Sugestão de categoria | `services/category_suggester.dart` |
| RF10/RF11 Dashboards mensal e anual | Visão Geral (Mês/Ano) |
| RF12–RF16 Orçamentos, sugestão, alertas, edição e exclusão | Orçamento, sino de alertas |
| RF17–RF19 Horas extras e férias | Menu › Calculadora de Horas / Férias |
| RF20 Relatórios em PDF e planilha | Visão Geral › exportar, Menu › Exportar relatório |
| RNF1 Cadastro, login, hash de senha, expiração por inatividade | `state/session_controller.dart` |
| RNF2 LGPD: consentimento, exclusão da conta e dos dados | Cadastro, Perfil › Informações Pessoais |
| RNF6 Log de auditoria imutável | tabela `audit_logs` (triggers bloqueiam UPDATE/DELETE) |

## Pendências que dependem do servidor

- **Envio real dos códigos por e-mail/SMS.** Hoje `LocalCodeDelivery` (`lib/app.dart`)
  mostra o código na própria tela.
- **Login com Google.** Precisa de um projeto no Google Cloud/Firebase.
- **Sincronização, backup e disponibilidade** (RNF3–RNF5).
- **Criptografia do banco local em repouso** (ex.: SQLCipher). Hoje a sessão
  é guardada no Android Keystore, mas o arquivo SQLite fica sem criptografia.
