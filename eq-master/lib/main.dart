import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'core/animated_button.dart';
import 'core/app_background.dart';
import 'core/app_error_view.dart';
import 'core/app_localizations.dart';
import 'core/preferences_service.dart';
import 'core/app_bloc.dart';
import 'team/team_bloc.dart'; // Added
import 'event/event_bloc.dart';
import 'home/home_bloc.dart';
import 'notifications/notification_bloc.dart';
import 'auth/LoginView.dart';
import 'auth/SignUpView.dart';
import 'core/app_transitions.dart';
import 'core/design_tokens.dart';
import 'core/responsive_system.dart';
import 'navigation/MainNavigation.dart';
import 'session/session_bloc.dart';
import 'core/deep_link_service.dart';

void main() async {
  // Replace Flutter's raw red error screen with a calm, branded fallback so
  // users always see a message they can understand instead of a crash dump.
  installFriendlyErrorWidget();

  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();
    await PreferencesService.init();

    runApp(
      MultiBlocProvider(
        providers: [
          BlocProvider(create: (context) => AppBloc()..add(AppStarted())),
          BlocProvider(
            create: (context) => SessionBloc()..add(SessionRestoreRequested()),
          ),
          BlocProvider(create: (context) => TeamBloc()..add(LoadTeamMembers())),
          BlocProvider(create: (context) => HomeBloc()..add(LoadHomeData())),
          BlocProvider(create: (context) => EventBloc()..add(LoadEvents())),
          BlocProvider(create: (context) => NotificationBloc()),
        ],
        child: const MyApp(),
      ),
    );
  }, (error, stack) {
    // Uncaught async errors land here. Logging keeps the app alive instead of
    // letting an unhandled exception take it down.
    debugPrint('Uncaught error: $error\n$stack');
  });
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});
  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    DeepLinkService().init();
  }

  @override
  void dispose() {
    DeepLinkService().dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      final bloc = context.read<NotificationBloc>();
      bloc.add(const RefreshUnreadCount());
      bloc.add(const LoadNotifications());
      bloc.startRealtime();
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AppBloc, AppState>(
      builder: (context, state) {
        return MaterialApp(
          navigatorKey: MyApp.navigatorKey,
          title: 'Equipex',
          debugShowCheckedModeBanner: false,
          // Localization: our hand-written strings + Flutter's Material/Widgets/
          // Cupertino delegates. Setting `locale` to Arabic also flips the whole
          // app to RTL automatically (Flutter resolves text direction from the
          // active locale).
          locale: state.locale,
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          theme: ThemeData.light().copyWith(
            colorScheme: ColorScheme.fromSeed(seedColor: AppColors.primary),
            primaryColor: AppColors.primary,
            pageTransitionsTheme: appPageTransitionsTheme,
            textTheme: ThemeData.light().textTheme.apply(fontFamily: 'SFPro'),
            primaryTextTheme: ThemeData.light().primaryTextTheme.apply(
              fontFamily: 'SFPro',
            ),
            inputDecorationTheme: InputDecorationTheme(
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 15,
              ),
              labelStyle: const TextStyle(
                fontFamily: 'SFPro',
                color: Colors.black54,
                fontSize: 14,
              ),
              hintStyle: const TextStyle(
                fontFamily: 'SFPro',
                color: Colors.black26,
              ),
              border: OutlineInputBorder(
                borderSide: const BorderSide(color: Colors.green),
                borderRadius: BorderRadius.circular(28),
              ),
              enabledBorder: OutlineInputBorder(
                borderSide: const BorderSide(color: Colors.green),
                borderRadius: BorderRadius.circular(28),
              ),
              focusedBorder: OutlineInputBorder(
                borderSide: const BorderSide(color: Colors.green, width: 2),
                borderRadius: BorderRadius.circular(28),
              ),
              errorBorder: OutlineInputBorder(
                borderSide: const BorderSide(color: Colors.red),
                borderRadius: BorderRadius.circular(28),
              ),
              focusedErrorBorder: OutlineInputBorder(
                borderSide: const BorderSide(color: Colors.red, width: 2),
                borderRadius: BorderRadius.circular(28),
              ),
            ),
            elevatedButtonTheme: ElevatedButtonThemeData(
              style: ElevatedButton.styleFrom(
                foregroundColor: Colors.white,
                backgroundColor: Colors.green,
                minimumSize: const Size(64, 50),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
                textStyle: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  fontFamily: 'SFPro',
                ),
              ),
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: Colors.green,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
              ),
            ),
            outlinedButtonTheme: OutlinedButtonThemeData(
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.black87,
                minimumSize: const Size(64, 50),
                side: const BorderSide(color: Colors.green),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
                textStyle: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  fontFamily: 'SFPro',
                ),
              ),
            ),
            filledButtonTheme: FilledButtonThemeData(
              style: FilledButton.styleFrom(
                foregroundColor: Colors.black,
                minimumSize: const Size(64, 50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
              ),
            ),
          ),
          darkTheme: ThemeData(
            brightness: Brightness.dark,
            colorScheme: ColorScheme.fromSeed(
              seedColor: AppColors.primary,
              brightness: Brightness.dark,
            ),
            fontFamily: 'SFPro',
            pageTransitionsTheme: appPageTransitionsTheme,
            scaffoldBackgroundColor: Colors.black,
            appBarTheme: const AppBarTheme(
              backgroundColor: Colors.transparent,
              elevation: 0,
              iconTheme: IconThemeData(color: Colors.white),
              titleTextStyle: TextStyle(
                fontFamily: 'SFPro',
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            textTheme: const TextTheme(
              bodyMedium: TextStyle(fontFamily: 'SFPro', color: Colors.white),
              bodyLarge: TextStyle(fontFamily: 'SFPro', color: Colors.white),
            ),
            inputDecorationTheme: InputDecorationTheme(
              filled: true,
              fillColor: Colors.grey.shade900,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 15,
              ),
              labelStyle: const TextStyle(
                fontFamily: 'SFPro',
                color: Colors.white54,
                fontSize: 14,
              ),
              hintStyle: const TextStyle(
                fontFamily: 'SFPro',
                color: Colors.white24,
              ),
              border: OutlineInputBorder(
                borderSide: const BorderSide(color: Colors.white24),
                borderRadius: BorderRadius.circular(28),
              ),
              enabledBorder: OutlineInputBorder(
                borderSide: const BorderSide(color: Colors.white24),
                borderRadius: BorderRadius.circular(28),
              ),
              focusedBorder: OutlineInputBorder(
                borderSide: const BorderSide(color: Colors.green, width: 2),
                borderRadius: BorderRadius.circular(28),
              ),
              errorBorder: OutlineInputBorder(
                borderSide: const BorderSide(color: Colors.redAccent),
                borderRadius: BorderRadius.circular(28),
              ),
              focusedErrorBorder: OutlineInputBorder(
                borderSide: const BorderSide(color: Colors.redAccent, width: 2),
                borderRadius: BorderRadius.circular(28),
              ),
            ),
            elevatedButtonTheme: ElevatedButtonThemeData(
              style: ElevatedButton.styleFrom(
                foregroundColor: Colors.white,
                backgroundColor: Colors.green,
                minimumSize: const Size(64, 50),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
                textStyle: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  fontFamily: 'SFPro',
                ),
              ),
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: Colors.white60,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
              ),
            ),
            outlinedButtonTheme: OutlinedButtonThemeData(
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                minimumSize: const Size(64, 50),
                side: const BorderSide(color: Colors.white30),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
                textStyle: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  fontFamily: 'SFPro',
                ),
              ),
            ),
            filledButtonTheme: FilledButtonThemeData(
              style: FilledButton.styleFrom(
                foregroundColor: Colors.white,
                minimumSize: const Size(64, 50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
              ),
            ),
          ),
          themeMode: state.themeMode,
          // `home` is kept structurally stable (always SplashView) so a theme
          // toggle — which rebuilds this whole MaterialApp via BlocBuilder —
          // never swaps the Navigator's child tree and can't disturb the
          // pushed route stack. Preferences are already loaded (main() awaits
          // PreferencesService.init() before runApp), so there's nothing to
          // gate on; AppStarted only refines themeMode, applied above.
          home: const SplashView(),
        );
      },
    );
  }
}

class SplashView extends StatefulWidget {
  const SplashView({super.key});

  @override
  State<SplashView> createState() => _SplashViewState();
}

class _SplashViewState extends State<SplashView>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  bool _minTimePassed = false;
  bool _navigated = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5),
    )..repeat();

    // Ensure the splash screen is visible for at least 2.5 seconds
    Timer(const Duration(milliseconds: 2500), () {
      if (!mounted) return;
      setState(() => _minTimePassed = true);
      _checkAndNavigate(context.read<SessionBloc>().state);
    });
  }

  void _checkAndNavigate(SessionState state) {
    if (!_minTimePassed) return;
    if (state.status == SessionStatus.unknown) return;
    if (_navigated) return;
    
    _navigated = true;
    final destination = state.status == SessionStatus.authenticated
        ? MainNavigation(
            userRole: state.currentRole ?? '',
            userId: state.user?.userId ?? '',
          )
        : (PreferencesService.hasSeenOnboarding()
            ? const LoginView()
            : const OnboardingView());
            
    Navigator.pushReplacement(
      context,
      AppFadeRoute(
        settings: const RouteSettings(name: '/'),
        child: destination,
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    double logoSize = MediaQuery.of(context).size.width * 0.8;
    if (logoSize > 630) logoSize = 630;
    
    return BlocListener<SessionBloc, SessionState>(
      listener: (context, state) => _checkAndNavigate(state),
      child: Scaffold(
        body: AppBackground(
          child: Stack(
            children: [
              Center(
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      RotationTransition(
                        turns: _controller,
                        child: Image.asset(
                          'assets/logo.png',
                          width: logoSize,
                          height: logoSize,
                        ),
                      ),
                      Text(
                        'EQUIPEX',
                        style: TextStyle(
                          fontFamily: 'Facon',
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).brightness == Brightness.dark
                              ? Colors.white
                              : Colors.black,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class OnboardingView extends StatefulWidget {
  final int initialPage;

  const OnboardingView({super.key, this.initialPage = 0});

  @override
  State<OnboardingView> createState() => _OnboardingViewState();
}

class _OnboardingViewState extends State<OnboardingView> {
  late PageController _pageController;
  late int _currentPage;

  @override
  void initState() {
    super.initState();
    _currentPage = widget.initialPage;
    _pageController = PageController(initialPage: widget.initialPage);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _goToLogin() {
    PreferencesService.setHasSeenOnboarding(true);
    Navigator.pushReplacement(
      context,
      AppFadeRoute(
        settings: const RouteSettings(name: '/'),
        child: const LoginView(),
      ),
    );
  }

  void _goToPeak() {
    _pageController.animateToPage(
      2,
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeInOutCubic,
    );
  }

  void _goBack() {
    _pageController.previousPage(
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeInOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return Scaffold(
      body: AppBackground(
        child: PageView(
          controller: _pageController,
          onPageChanged: (index) => setState(() => _currentPage = index),
          children: [
            OnboardingPage(
              pageIndex: 0,
              title: t.obUniteTitle,
              description: t.obUniteDesc,
              imagePath: 'assets/unite.png',
              showNext: true,
              nextLabel: t.next,
              onNext: () => _pageController.nextPage(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
              ),
              onSkip: _goToPeak,
              onBack: null,
              currentPage: _currentPage,
            ),
            OnboardingPage(
              pageIndex: 1,
              title: t.obTacticalTitle,
              description: t.obTacticalDesc,
              imagePath: 'assets/tactical.png',
              showNext: true,
              nextLabel: t.next,
              onNext: () => _pageController.nextPage(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
              ),
              onSkip: _goToPeak,
              onBack: _goBack,
              currentPage: _currentPage,
            ),
            OnboardingPage(
              pageIndex: 2,
              title: t.obPeakTitle,
              description: t.obPeakDesc,
              imagePath: 'assets/peak.png',
              showNext: false,
              nextLabel: t.obLetsStart,
              onNext: _goToLogin,
              onSkip: null,
              onBack: _goBack,
              extraButtons: [
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 50),
                    side: const BorderSide(color: Colors.green),
                  ),
                  onPressed: () {
                    PreferencesService.setHasSeenOnboarding(true);
                    Navigator.pushReplacement(
                      context,
                      AppFadeRoute(
                        settings: const RouteSettings(name: '/'),
                        child: const SignUpView(),
                      ),
                    );
                  },
                  child: Text(t.createAccount),
                ),
              ],
              currentPage: _currentPage,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Onboarding page ───────────────────────────────────────────────────────────
// StatefulWidget so each page plays a staggered enter animation the moment it
// becomes the active page (image scales up, title + description + buttons slide
// up and fade in with individual delays).
class OnboardingPage extends StatefulWidget {
  final int pageIndex;
  final String title;
  final String description;
  final String imagePath;
  final VoidCallback onNext;
  final VoidCallback? onSkip;
  final VoidCallback? onBack;
  final List<Widget>? extraButtons;
  final String nextLabel;
  final bool showNext;
  final int currentPage;

  const OnboardingPage({
    super.key,
    required this.pageIndex,
    required this.title,
    required this.description,
    required this.imagePath,
    required this.onNext,
    required this.onSkip,
    required this.onBack,
    this.extraButtons,
    this.nextLabel = 'Next',
    this.showNext = true,
    required this.currentPage,
  });

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  // ── per-element animations ──
  late final Animation<double> _imageFade;
  late final Animation<double> _imageScale;
  late final Animation<double> _titleFade;
  late final Animation<Offset> _titleSlide;
  late final Animation<double> _descFade;
  late final Animation<Offset> _descSlide;
  late final Animation<double> _btnFade;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 620),
    );

    _imageFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _ctrl,
        curve: const Interval(0.00, 0.55, curve: Curves.easeOut),
      ),
    );
    _imageScale = Tween<double>(begin: 0.82, end: 1.0).animate(
      CurvedAnimation(
        parent: _ctrl,
        curve: const Interval(0.00, 0.65, curve: Curves.easeOutBack),
      ),
    );

    _titleFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _ctrl,
        curve: const Interval(0.18, 0.62, curve: Curves.easeOut),
      ),
    );
    _titleSlide = Tween<Offset>(begin: const Offset(0, 0.18), end: Offset.zero)
        .animate(
          CurvedAnimation(
            parent: _ctrl,
            curve: const Interval(0.18, 0.72, curve: Curves.easeOutCubic),
          ),
        );

    _descFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _ctrl,
        curve: const Interval(0.32, 0.74, curve: Curves.easeOut),
      ),
    );
    _descSlide = Tween<Offset>(begin: const Offset(0, 0.14), end: Offset.zero)
        .animate(
          CurvedAnimation(
            parent: _ctrl,
            curve: const Interval(0.32, 0.82, curve: Curves.easeOutCubic),
          ),
        );

    _btnFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _ctrl,
        curve: const Interval(0.50, 1.00, curve: Curves.easeOut),
      ),
    );

    if (widget.currentPage == widget.pageIndex) _ctrl.forward();
  }

  @override
  void didUpdateWidget(OnboardingPage old) {
    super.didUpdateWidget(old);
    // Replay animation whenever this page becomes active.
    if (widget.currentPage != old.currentPage &&
        widget.currentPage == widget.pageIndex) {
      _ctrl.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final t = AppLocalizations.of(context);

    return SafeArea(
      child: Center(
        child: Container(
          margin: const EdgeInsets.all(24),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: isDark
                ? const Color(0xFF10251C).withValues(alpha: 0.7)
                : Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Back / Skip row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    if (widget.onBack != null)
                      TextButton(
                        style: TextButton.styleFrom(
                          foregroundColor: isDark ? Colors.white : Colors.green,
                          textStyle: const TextStyle(
                            fontFamily: 'SFPro',
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        onPressed: widget.onBack,
                        child: Text(t.back),
                      )
                    else
                      const SizedBox.shrink(),
                    if (widget.onSkip != null)
                      TextButton(
                        style: TextButton.styleFrom(
                          foregroundColor: isDark ? Colors.white : Colors.green,
                          textStyle: const TextStyle(
                            fontFamily: 'SFPro',
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        onPressed: widget.onSkip,
                        child: Text(t.skip),
                      )
                    else
                      const SizedBox.shrink(),
                  ],
                ),
                const SizedBox(height: 10),

                // ── Image ──────────────────────────────────────────────────
                FadeTransition(
                  opacity: _imageFade,
                  child: ScaleTransition(
                    scale: _imageScale,
                    child: Image.asset(
                      widget.imagePath,
                      height: ResponsiveSystem.height(context) * 0.3,
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // ── Title ──────────────────────────────────────────────────
                FadeTransition(
                  opacity: _titleFade,
                  child: SlideTransition(
                    position: _titleSlide,
                    child: Text(
                      widget.title,
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
                const SizedBox(height: 10),

                // ── Description ────────────────────────────────────────────
                FadeTransition(
                  opacity: _descFade,
                  child: SlideTransition(
                    position: _descSlide,
                    child: Text(
                      widget.description,
                      style: TextStyle(
                        fontSize: 16,
                        color: isDark ? Colors.white70 : Colors.black54,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
                const SizedBox(height: 30),

                // ── Buttons ────────────────────────────────────────────────
                FadeTransition(
                  opacity: _btnFade,
                  child: Column(
                    children: [
                      if (widget.showNext)
                        AnimatedButton.primary(child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            minimumSize: const Size(double.infinity, 50),
                          ),
                          onPressed: widget.onNext,
                          child: Text(widget.nextLabel),
                        ))
                      else ...[
                        AnimatedButton.primary(child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            minimumSize: const Size(double.infinity, 50),
                          ),
                          onPressed: widget.onNext,
                          child: Text(widget.nextLabel),
                        )),
                        const SizedBox(height: 10),
                        ...?widget.extraButtons,
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // ── Animated dots ──────────────────────────────────────────
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(3, (index) {
                    final isActive = widget.currentPage == index;
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      width: isActive ? 24 : 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: isActive
                            ? Colors.green
                            : (isDark ? Colors.white38 : Colors.black26),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    );
                  }),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
