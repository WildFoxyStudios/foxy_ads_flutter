import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:foxy_ads/firebase_options.dart';
import 'package:foxy_ads/l10n/app_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/deeplink/deep_link_service.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_mode_provider.dart';
import 'core/router/app_router.dart';
import 'core/providers/locale_provider.dart';
import 'features/chat/presentation/widgets/chat_bubble.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  // Load environment variables
  await dotenv.load(fileName: ".env");

  // Initialize Supabase
  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL'] ?? '',
    anonKey: dotenv.env['SUPABASE_ANON_KEY'] ?? '',
  );

  // AdMob is intentionally NOT initialized here while disabled: the
  // google_mobile_ads package's native MobileAdsInitProvider runs at
  // process start (before any Dart code) and crashes the app when the
  // AdMob app-id <meta-data> is missing from AndroidManifest.xml. The
  // package has been removed from pubspec.yaml; re-add it together with
  // the manifest meta-data when ads are ready to ship. See
  // docs/ADMOB_SETUP.md.

  // Set preferred orientations
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Set system UI overlay style
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ),
  );

  runApp(const ProviderScope(child: FoxyAdsApp()));
}

class FoxyAdsApp extends ConsumerStatefulWidget {
  const FoxyAdsApp({super.key});

  @override
  ConsumerState<FoxyAdsApp> createState() => _FoxyAdsAppState();
}

class _FoxyAdsAppState extends ConsumerState<FoxyAdsApp> {
  // The GoRouter is a Riverpod Provider (singleton for the container's
  // lifetime), not rebuilt per-frame, so it's safe to capture once here and
  // hand the same instance to both MaterialApp.router and DeepLinkService.
  late final GoRouter _router;
  late final DeepLinkService _deepLinkService;

  @override
  void initState() {
    super.initState();
    _router = ref.read(appRouterProvider);
    _deepLinkService = DeepLinkService(_router);
    // Defer until after the first frame so there's a live navigator for
    // router.go() to act on.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _deepLinkService.handleInitialLink();
      _deepLinkService.startListening();
    });
  }

  @override
  void dispose() {
    _deepLinkService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final locale = ref.watch(localeProvider);

    return MaterialApp.router(
      title: 'Foxy Ads',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ref.watch(themeModeProvider),
      routerConfig: _router,
      locale: locale,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: LocaleNotifier.supported,
      // Overlay the Foxy chat bubble above the routed content on every
      // screen (Sprint 10, Task 2). `builder`'s `child` is the go_router
      // `Router` widget itself, and it is placed INSIDE this Stack, not an
      // ancestor of it — so anything else in the Stack (namely `ChatBubble`)
      // has no `Navigator`/`Overlay` ancestor of its own. `ChatBubble`'s
      // `Tooltip` needs an `Overlay` ancestor to build at all (verified: it
      // throws "No Overlay widget found" without this wrapper), so a local
      // `Overlay` is introduced here purely to satisfy that. `ChatBubble`'s
      // `showModalBottomSheet` call additionally can't just use its own
      // context either (no Navigator ancestor) — it instead opens the sheet
      // against `rootNavigatorKeyProvider`'s `currentContext`, which is a
      // real descendant of the go_router Navigator inside `child` (see that
      // provider's doc comment in `core/router/app_router.dart`).
      builder: (context, child) {
        return Overlay(
          initialEntries: [
            OverlayEntry(
              builder: (context) => Stack(
                children: [
                  child ?? const SizedBox.shrink(),
                  const ChatBubble(),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

// Supabase client getter
final supabase = Supabase.instance.client;
