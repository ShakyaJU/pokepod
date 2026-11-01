import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/audio/sound_service.dart';
import '../data/providers.dart';
import '../features/trainer_profile/profile_controller.dart';
import 'shell.dart';
import 'theme/app_theme.dart';
import 'theme/system_ui.dart';
import 'theme/tokens.dart';

class PokePodApp extends ConsumerWidget {
  /// The branded Flutter splash (supplied PokéPod wordmark) is shown for
  /// [splashDuration] while the app warms up, and the main interface is not
  /// built until the splash sound has finished. Pass [Duration.zero] to skip
  /// it, as the tests do.
  const PokePodApp({
    super.key,
    this.splashDuration = const Duration(milliseconds: 800),
  });

  /// Minimum time the branded splash is shown (it then waits for the catalogue
  /// to load and the splash sound to finish, each with a cap). [Duration.zero]
  /// skips it.
  final Duration splashDuration;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accent = ref.watch(accentColorProvider);
    final themeMode = ref.watch(themeModeProvider);
    return MaterialApp(
      title: 'PokéPod',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.build(Brightness.light, accent),
      darkTheme: AppTheme.build(Brightness.dark, accent),
      themeMode: themeMode,
      // One place for status-bar and navigation-bar styling in both themes.
      builder: (context, child) =>
          SystemUiScope(child: child ?? const SizedBox.shrink()),
      home: _SplashGate(duration: splashDuration),
    );
  }
}

class _SplashGate extends ConsumerStatefulWidget {
  const _SplashGate({required this.duration});

  final Duration duration;

  @override
  ConsumerState<_SplashGate> createState() => _SplashGateState();
}

class _SplashGateState extends ConsumerState<_SplashGate> {
  /// Bounded fallback for the splash sound. Playback completion is the real
  /// signal; this only caps how long a missing or hung audio system may delay
  /// startup. [SoundService.playToCompletion] enforces its own bound first.
  static const _soundFallback = Duration(seconds: 6);

  Timer? _minTimer;
  Timer? _dataTimer;
  Timer? _failSafeTimer;
  late bool _ready = widget.duration == Duration.zero;
  bool _minElapsed = false;
  bool _dataReady = false;
  bool _soundDone = false;

  @override
  void initState() {
    super.initState();
    if (_ready) {
      return;
    }
    final sound = ref.read(soundServiceProvider);
    // initState runs exactly once per launch, before the first frame is
    // painted, so the splash artwork appears in the same frame the splash
    // sound starts — and rebuilds, navigation or a second gate can never ask
    // for it twice (SoundService also drops a repeat inside its window).
    unawaited(_awaitSplashSound(sound));
    // The other game effects load in parallel so the first guess has no delay.
    unawaited(sound.preload(const [Sfx.game, Sfx.correct, Sfx.error]));
    // The splash stays for at least [duration] so the logo is readable, and no
    // longer than needed afterwards: it ends as soon as the catalogue (the real
    // startup work) has loaded, the splash sound has finished and the minimum
    // time has passed. Each wait has its own cap so nothing can hang.
    _minTimer = Timer(widget.duration, () {
      _minElapsed = true;
      _finishIfReady();
    });
    _dataTimer = Timer(
      widget.duration + const Duration(milliseconds: 2500),
      () {
        // The catalogue is normally ready long before this; if it never is,
        // start anyway rather than wait for a request that will not finish.
        _dataReady = true;
        _finishIfReady();
      },
    );
    // Last resort: SoundService already bounds the sound wait, so this only
    // fires if that guarantee ever breaks. The app must not stay on the splash.
    _failSafeTimer = Timer(
      widget.duration + _soundFallback + const Duration(seconds: 2),
      _finish,
    );
    ref.listenManual(catalogProvider, (previous, next) {
      if (!next.isLoading) {
        _dataReady = true;
        _finishIfReady();
      }
    }, fireImmediately: true);
  }

  /// Resolves when the splash sound has finished (or failed, or hit its
  /// bounded wait), then lets the gate open. It never throws and never leaves
  /// the splash stuck, so the app opens even with no working audio.
  Future<void> _awaitSplashSound(SoundService sound) async {
    try {
      await sound.playToCompletion(Sfx.splash, maxWait: _soundFallback);
    } catch (_) {
      // Audio is optional: a failure here only means no splash sound.
    }
    if (!mounted) {
      return;
    }
    setState(() => _soundDone = true);
    _finishIfReady();
  }

  void _finishIfReady() {
    if (_minElapsed && _dataReady && _soundDone) {
      _finish();
    }
  }

  void _finish() {
    if (mounted && !_ready) {
      setState(() => _ready = true);
    }
  }

  @override
  void dispose() {
    _minTimer?.cancel();
    _dataTimer?.cancel();
    _failSafeTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: Motion.medium,
      child: _ready
          ? const HomeShell(key: ValueKey('shell'))
          : const _BrandedSplash(key: ValueKey('splash')),
    );
  }
}

/// Launch screen built from the supplied PokéPod wordmark, a soft glow behind
/// it and a short tagline. The native launch screen is the same dark colour with
/// no icon, so this is the only branded launch screen. The wordmark keeps its
/// aspect ratio and is sized from both the width and the height of the screen,
/// so it fits phones and tablets in either orientation.
class _BrandedSplash extends StatelessWidget {
  const _BrandedSplash({super.key});

  /// Width / height of assets/branding/pokepod_splash_text.png.
  static const double _aspect = 1600 / 457;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.obsidian,
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0, -0.08),
            radius: 0.85,
            colors: [Color(0xFF15212C), AppColors.obsidian],
          ),
        ),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final width = math.min(
                math.min(constraints.maxWidth * 0.8, 460.0),
                constraints.maxHeight * 0.4 * _aspect,
              );
              return Center(
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: 1),
                  duration: const Duration(milliseconds: 450),
                  curve: Curves.easeOutCubic,
                  builder: (context, t, child) => Opacity(
                    opacity: t,
                    child: Transform.scale(
                      scale: 0.94 + 0.06 * t,
                      child: child,
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Image.asset(
                        'assets/branding/pokepod_splash_text.png',
                        width: width,
                        fit: BoxFit.contain,
                        filterQuality: FilterQuality.high,
                        semanticLabel: 'PokéPod',
                      ),
                      const SizedBox(height: Space.lg),
                      const Text(
                        'BEYOND THE POKÉDEX',
                        style: TextStyle(
                          color: AppColors.textDim,
                          letterSpacing: 4,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
