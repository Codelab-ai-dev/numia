import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app/theme.dart';
import 'core/providers.dart';
import 'core/token_storage.dart';
import 'core/theme_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
  ));
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  await dotenv.load(fileName: '.env');

  // Check if user has tokens (was logged in)
  final tokenStorage = TokenStorage();
  final hasTokens = await tokenStorage.hasTokens();

  runApp(ProviderScope(
    overrides: [
      authStateProvider.overrideWith((ref) => hasTokens),
    ],
    child: const NumiaApp(),
  ));
}

class NumiaApp extends ConsumerWidget {
  const NumiaApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    return MaterialApp.router(
      title: 'Numia',
      theme: buildNumiaTheme(Brightness.light),
      darkTheme: buildNumiaTheme(Brightness.dark),
      themeMode: themeMode,
      routerConfig: ref.watch(routerProvider),
      debugShowCheckedModeBanner: false,
      locale: const Locale('es', 'MX'),
    );
  }
}
