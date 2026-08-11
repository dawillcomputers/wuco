import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_dimensions.dart';
import '../../domain/learner_course.dart';
import '../../domain/learner_enums.dart';

/// Playback position and transport for a lesson.
///
/// Kept separate from the widgets so the inline and fullscreen surfaces share
/// one state, and so completion can be judged on *watched* time rather than on
/// the lesson merely having been opened. When a real media backend is wired in,
/// it replaces the ticker here and nothing above this class changes.
class LessonPlaybackController extends ChangeNotifier {
  LessonPlaybackController({required this.duration, required TickerProvider vsync}) {
    _ticker = vsync.createTicker(_onTick);
  }

  final Duration duration;
  late final Ticker _ticker;

  Duration _position = Duration.zero;
  Duration _lastTick = Duration.zero;
  double _speed = 1;
  double _volume = 1;
  bool _playing = false;

  /// The furthest point actually reached, so scrubbing forward does not count
  /// as having watched the material.
  Duration _watched = Duration.zero;

  Duration get position => _position;
  double get speed => _speed;
  double get volume => _volume;
  bool get isPlaying => _playing;
  bool get isMuted => _volume == 0;

  double get fraction => duration.inMilliseconds == 0
      ? 0
      : (_position.inMilliseconds / duration.inMilliseconds).clamp(0, 1);

  double get watchedFraction => duration.inMilliseconds == 0
      ? 0
      : (_watched.inMilliseconds / duration.inMilliseconds).clamp(0, 1);

  /// Completion criterion for a timed lesson: effectively watched through.
  bool get meetsCompletionCriteria => watchedFraction >= .95;

  void toggle() => _playing ? pause() : play();

  void play() {
    if (_playing) return;
    if (_position >= duration) _position = Duration.zero;
    _playing = true;
    _lastTick = Duration.zero;
    _ticker.start();
    notifyListeners();
  }

  void pause() {
    if (!_playing) return;
    _playing = false;
    _ticker.stop();
    notifyListeners();
  }

  void seek(Duration to) {
    _position = Duration(
      milliseconds: to.inMilliseconds.clamp(0, duration.inMilliseconds),
    );
    if (_position > _watched) _watched = _position;
    notifyListeners();
  }

  void skip(Duration delta) => seek(_position + delta);

  void setSpeed(double value) {
    _speed = value;
    notifyListeners();
  }

  void setVolume(double value) {
    _volume = value.clamp(0, 1);
    notifyListeners();
  }

  void toggleMute() => setVolume(isMuted ? 1 : 0);

  void _onTick(Duration elapsed) {
    final delta = elapsed - _lastTick;
    _lastTick = elapsed;
    final next = _position + delta * _speed;
    if (next >= duration) {
      _position = duration;
      _watched = duration;
      pause();
      return;
    }
    _position = next;
    if (_position > _watched) _watched = _position;
    notifyListeners();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }
}

String formatPlaybackTime(Duration value) {
  final minutes = value.inMinutes;
  final seconds = value.inSeconds.remainder(60).toString().padLeft(2, '0');
  return '$minutes:$seconds';
}

/// The lesson media surface: poster, transport controls and progress.
class LessonPlayer extends StatelessWidget {
  const LessonPlayer({
    super.key,
    required this.lesson,
    required this.posterUrl,
    required this.controller,
    this.onRequestFullscreen,
    this.fullscreen = false,
  });

  final Lesson lesson;
  final String posterUrl;
  final LessonPlaybackController controller;
  final VoidCallback? onRequestFullscreen;
  final bool fullscreen;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (context, _) => ClipRRect(
      borderRadius: BorderRadius.circular(
        fullscreen ? 0 : WEAInsets.smallRadius,
      ),
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.network(
              posterUrl,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) =>
                  const ColoredBox(color: WEAColors.navyDeep),
            ),
            // Keeps the controls and title readable over any poster.
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0x730A1E3D), Color(0xD90A1E3D)],
                ),
              ),
            ),
            Center(
              child: _PlayButton(
                playing: controller.isPlaying,
                onPressed: controller.toggle,
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: _Controls(
                controller: controller,
                onRequestFullscreen: onRequestFullscreen,
                fullscreen: fullscreen,
              ),
            ),
            Positioned(
              left: WEAInsets.md,
              top: WEAInsets.md,
              right: WEAInsets.md,
              child: Text(
                lesson.type.label.toUpperCase(),
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: WEAColors.accentSoft,
                  letterSpacing: 1.6,
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _PlayButton extends StatelessWidget {
  const _PlayButton({required this.playing, required this.onPressed});

  final bool playing;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: playing ? 'Pause lesson' : 'Play lesson',
    child: Material(
      color: WEAColors.offWhite.withValues(alpha: .92),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onPressed,
        child: Padding(
          padding: const EdgeInsets.all(WEAInsets.md),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            child: Icon(
              playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
              key: ValueKey(playing),
              size: 30,
              color: WEAColors.navy,
            ),
          ),
        ),
      ),
    ),
  );
}

class _Controls extends StatelessWidget {
  const _Controls({
    required this.controller,
    required this.fullscreen,
    this.onRequestFullscreen,
  });

  final LessonPlaybackController controller;
  final bool fullscreen;
  final VoidCallback? onRequestFullscreen;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final compact = MediaQuery.sizeOf(context).width < 560;
    final light = WEAColors.offWhite;

    return Container(
      padding: const EdgeInsets.fromLTRB(
        WEAInsets.sm,
        0,
        WEAInsets.sm,
        WEAInsets.xs,
      ),
      color: WEAColors.navyDeep.withValues(alpha: .28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SliderTheme(
            data: SliderThemeData(
              trackHeight: 3,
              activeTrackColor: WEAColors.accentBright,
              inactiveTrackColor: light.withValues(alpha: .28),
              thumbColor: light,
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
            ),
            child: Slider(
              value: controller.fraction,
              label: formatPlaybackTime(controller.position),
              onChanged: (value) => controller.seek(
                Duration(
                  milliseconds:
                      (controller.duration.inMilliseconds * value).round(),
                ),
              ),
            ),
          ),
          Row(
            children: [
              IconButton(
                tooltip: 'Back 10 seconds',
                color: light,
                iconSize: 20,
                visualDensity: compact ? VisualDensity.compact : null,
                onPressed: () =>
                    controller.skip(const Duration(seconds: -10)),
                icon: const Icon(Icons.replay_10),
              ),
              IconButton(
                tooltip: 'Forward 10 seconds',
                color: light,
                iconSize: 20,
                visualDensity: compact ? VisualDensity.compact : null,
                onPressed: () => controller.skip(const Duration(seconds: 10)),
                icon: const Icon(Icons.forward_10),
              ),
              const SizedBox(width: 4),
              // Expanded rather than text-then-Spacer: the elapsed readout
              // then absorbs the slack instead of pushing the transport
              // controls off a narrow player.
              Expanded(
                child: Text(
                  '${formatPlaybackTime(controller.position)} / '
                  '${formatPlaybackTime(controller.duration)}',
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelSmall?.copyWith(color: light),
                ),
              ),
              if (!compact) ...[
                IconButton(
                  tooltip: controller.isMuted ? 'Unmute' : 'Mute',
                  color: light,
                  iconSize: 20,
                  onPressed: controller.toggleMute,
                  icon: Icon(
                    controller.isMuted
                        ? Icons.volume_off_outlined
                        : Icons.volume_up_outlined,
                  ),
                ),
                SizedBox(
                  width: 88,
                  child: SliderTheme(
                    data: SliderThemeData(
                      trackHeight: 2,
                      activeTrackColor: light,
                      inactiveTrackColor: light.withValues(alpha: .28),
                      thumbColor: light,
                      thumbShape: const RoundSliderThumbShape(
                        enabledThumbRadius: 5,
                      ),
                    ),
                    child: Slider(
                      value: controller.volume,
                      onChanged: controller.setVolume,
                    ),
                  ),
                ),
              ],
              PopupMenuButton<double>(
                tooltip: 'Playback speed',
                initialValue: controller.speed,
                onSelected: controller.setSpeed,
                itemBuilder: (context) => [
                  for (final speed in const [0.75, 1.0, 1.25, 1.5, 2.0])
                    PopupMenuItem(value: speed, child: Text('${speed}x')),
                ],
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: WEAInsets.xs),
                  child: Text(
                    '${controller.speed}x',
                    style: theme.textTheme.labelSmall?.copyWith(color: light),
                  ),
                ),
              ),
              IconButton(
                tooltip: fullscreen ? 'Exit fullscreen' : 'Fullscreen',
                color: light,
                iconSize: 20,
                visualDensity: compact ? VisualDensity.compact : null,
                onPressed: onRequestFullscreen,
                icon: Icon(
                  fullscreen
                      ? Icons.fullscreen_exit
                      : Icons.fullscreen_outlined,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Stand-in surface for lesson types that are not timed media.
class LessonStaticSurface extends StatelessWidget {
  const LessonStaticSurface({
    super.key,
    required this.type,
    required this.posterUrl,
  });

  final LessonType type;
  final String posterUrl;

  IconData get _icon => switch (type) {
    LessonType.pdf => Icons.picture_as_pdf_outlined,
    LessonType.presentation => Icons.slideshow_outlined,
    LessonType.quiz => Icons.quiz_outlined,
    LessonType.assignment => Icons.assignment_outlined,
    LessonType.caseStudy => Icons.cases_outlined,
    LessonType.liveSession => Icons.videocam_outlined,
    LessonType.externalResource => Icons.link_outlined,
    _ => Icons.article_outlined,
  };

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(WEAInsets.smallRadius),
    child: AspectRatio(
      aspectRatio: 21 / 7,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.network(
            posterUrl,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) =>
                const ColoredBox(color: WEAColors.navyDeep),
          ),
          const ColoredBox(color: Color(0xCC0A1E3D)),
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(_icon, size: 30, color: WEAColors.accentSoft),
                const SizedBox(height: WEAInsets.xs),
                Text(
                  type.label.toUpperCase(),
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: WEAColors.offWhite,
                    letterSpacing: 1.6,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}
