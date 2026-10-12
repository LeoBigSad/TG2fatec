import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'core/theme/app_colors.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/login_page.dart';
import 'features/shell/main_shell.dart';
import 'services/verification_service.dart';
import 'state/finance_controller.dart';
import 'state/session_controller.dart';

final scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();
final navigatorKey = GlobalKey<NavigatorState>();

/// Sem backend, o código de verificação é exibido na própria tela.
/// Quando houver servidor, substituir por uma entrega real (e-mail/SMS).
class LocalCodeDelivery implements CodeDelivery {
  @override
  Future<void> deliver(ContactMethod method, String destination, String code) async {
    scaffoldMessengerKey.currentState
      ?..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        duration: const Duration(seconds: 12),
        backgroundColor: AppColors.accent,
        content: Text('Modo local (sem servidor de ${method.label}): seu código é $code'),
      ));
  }
}

class App extends StatefulWidget {
  const App({super.key, required this.session, required this.finance});

  final SessionController session;
  final FinanceController finance;

  @override
  State<App> createState() => _AppState();
}

class _AppState extends State<App> with WidgetsBindingObserver {
  final _verification = VerificationService(LocalCodeDelivery());
  bool? _wasLoggedIn;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.session.addListener(_onSessionChanged);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.session.removeListener(_onSessionChanged);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) widget.session.checkInactivity();
  }

  void _onSessionChanged() {
    final session = widget.session;
    widget.finance.loadFor(session.user?.id);
    if (_wasLoggedIn != null && _wasLoggedIn != session.isLoggedIn) {
      // Entrou ou saiu: descarta as telas empilhadas sobre a tela inicial.
      navigatorKey.currentState?.popUntil((r) => r.isFirst);
      if (!session.isLoggedIn && session.consumeExpiredFlag()) {
        scaffoldMessengerKey.currentState?.showSnackBar(
          const SnackBar(content: Text('Sua sessão expirou por inatividade. Entre novamente.')),
        );
      }
    }
    if (!session.restoring) _wasLoggedIn = session.isLoggedIn;
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: widget.session),
        ChangeNotifierProvider.value(value: widget.finance),
        Provider.value(value: _verification),
      ],
      child: Listener(
        behavior: HitTestBehavior.translucent,
        onPointerDown: (_) => widget.session.registerActivity(),
        child: MaterialApp(
          title: 'TGII',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light,
          navigatorKey: navigatorKey,
          scaffoldMessengerKey: scaffoldMessengerKey,
          locale: const Locale('pt', 'BR'),
          supportedLocales: const [Locale('pt', 'BR')],
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          home: const _AuthGate(),
        ),
      ),
    );
  }
}

class _AuthGate extends StatelessWidget {
  const _AuthGate();

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionController>();
    if (session.restoring) {
      return const Scaffold(body: Center(child: CircularProgressIndicator(color: AppColors.primary)));
    }
    return session.isLoggedIn ? const MainShell() : const LoginPage();
  }
}
