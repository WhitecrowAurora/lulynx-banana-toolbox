import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'l10n/app_i18n.dart';
import 'providers/providers.dart';
import 'screens/home_screen.dart';

void main() {
  runApp(const ProviderScope(child: NanoBananaApp()));
}

class NanoBananaApp extends ConsumerWidget {
  const NanoBananaApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final configReady = ref.watch(apiConfigReadyProvider);
    if (configReady.isLoading) {
      return const MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2.4),
            ),
          ),
        ),
      );
    }

    final locale = ref.watch(appLocaleProvider);
    return MaterialApp(
      title: 'Nano Banana',
      debugShowCheckedModeBanner: false,
      locale: locale,
      supportedLocales: AppI18n.supportedLocales,
      localizationsDelegates: AppI18n.localizationsDelegates,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      themeMode: ThemeMode.system,
      home: const HomeScreen(),
    );
  }
}
