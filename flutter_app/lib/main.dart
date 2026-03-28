import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:household/l10n/app_localizations.dart';
import 'package:household/router.dart';
import 'package:household/services/auth_service.dart';
import 'package:household/services/locale_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ProviderScope(child: AppStartup()));
}

/// Restores token/session from secure storage before showing any screen.
/// While restoring, shows a plain splash. Then hands off to the router.
class AppStartup extends ConsumerStatefulWidget {
  const AppStartup({super.key});

  @override
  ConsumerState<AppStartup> createState() => _AppStartupState();
}

class _AppStartupState extends ConsumerState<AppStartup> {
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    ref.read(authServiceProvider).tryRestoreSession().then((_) {
      if (mounted) setState(() => _ready = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) {
      return const MaterialApp(
        home: Scaffold(
          backgroundColor: Color(0xFF667EEA),
          body: Center(
            child: CircularProgressIndicator(color: Colors.white),
          ),
        ),
      );
    }
    return const HouseholdApp();
  }
}

class HouseholdApp extends ConsumerWidget {
  const HouseholdApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final locale = ref.watch(localeProvider);
    return MaterialApp.router(
      title: 'Household',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF6366F1)),
        useMaterial3: true,
      ),
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      routerConfig: router,
    );
  }
}
