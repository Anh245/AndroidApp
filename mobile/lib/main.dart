import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'core/api.dart';
import 'core/theme.dart';
import 'core/session.dart';
import 'screens/auth_screen.dart';
import 'screens/home_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ExpenseApp());
}

class ExpenseApp extends StatefulWidget {
  const ExpenseApp({super.key});
  @override
  State<ExpenseApp> createState() => _ExpenseAppState();
}

class _ExpenseAppState extends State<ExpenseApp> {
  late final Session session;
  final navigatorKey = GlobalKey<NavigatorState>();
  @override
  void initState() {
    super.initState();
    session = Session(Api());
    session.addListener(onSessionChanged);
    session.restore();
  }

  void onSessionChanged() {
    if (session.user == null && !session.loading) {
      navigatorKey.currentState?.popUntil((route) => route.isFirst);
    }
  }

  @override
  void dispose() {
    session.removeListener(onSessionChanged);
    session.api.close();
    session.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    navigatorKey: navigatorKey,
    title: 'Sổ Chi Tiêu',
    debugShowCheckedModeBanner: false,
    locale: const Locale('vi'),
    supportedLocales: const [Locale('vi'), Locale('en')],
    localizationsDelegates: GlobalMaterialLocalizations.delegates,
    theme: expenseTheme(),
    home: ListenableBuilder(
      listenable: session,
      builder: (context, _) {
        if (session.loading) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (session.startupError != null) {
          return Scaffold(
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSpace.xl),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(session.startupError!, textAlign: TextAlign.center),
                    const SizedBox(height: AppSpace.lg),
                    FilledButton(
                      onPressed: session.restore,
                      child: const Text('Thử kết nối lại'),
                    ),
                  ],
                ),
              ),
            ),
          );
        }
        return session.user == null
            ? AuthScreen(session: session)
            : HomeScreen(key: ValueKey(session.user!['id']), session: session);
      },
    ),
  );
}
