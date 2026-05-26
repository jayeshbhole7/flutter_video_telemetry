import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:video_telemetry/video_telemetry.dart';

import 'video_player_observer.dart';

void main() => runApp(const TelemetryExampleApp());

/// The root example application showcasing [VideoTelemetry] usage.
class TelemetryExampleApp extends StatelessWidget {
  /// Create the example app.
  const TelemetryExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'video_telemetry',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(useMaterial3: true).copyWith(
        scaffoldBackgroundColor: const Color(0xFF121212),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF1E1E1E),
          elevation: 0,
        ),
        navigationBarTheme: NavigationBarThemeData(
          backgroundColor: const Color(0xFF1E1E1E),
          indicatorColor: Colors.deepPurple.withValues(alpha: 0.3),
        ),
      ),
      home: const _RootScreen(),
    );
  }
}

class _RootScreen extends StatefulWidget {
  const _RootScreen();

  @override
  State<_RootScreen> createState() => _RootScreenState();
}

class _RootScreenState extends State<_RootScreen> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _tab,
        children: const [
          RealAppScreen(),
          ShowcaseScreen(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.play_circle_outline),
            selectedIcon: Icon(Icons.play_circle),
            label: 'Demo',
          ),
          NavigationDestination(
            icon: Icon(Icons.bar_chart_outlined),
            selectedIcon: Icon(Icons.bar_chart),
            label: 'Showcase',
          ),
        ],
      ),
    );
  }
}

/// Tab 1: Real App
/// Demonstrates what the package looks like in a production environment.
class RealAppScreen extends StatefulWidget {
  /// Create the real app demo.
  const RealAppScreen({super.key});

  @override
  State<RealAppScreen> createState() => _RealAppScreenState();
}

class _RealAppScreenState extends State<RealAppScreen> {
  late final VideoPlayerController _controller;
  late final VideoTelemetry _telemetry;
  TelemetrySnapshot? _snapshot;

  @override
  void initState() {
    super.initState();

    _controller = VideoPlayerController.networkUrl(
      Uri.parse(
        'https://test-videos.co.uk/vids/bigbuckbunny/mp4/h264/720/'
        'Big_Buck_Bunny_720_10s_20MB.mp4',
      ),
    );

    // Initialize telemetry wrapper
    _telemetry = VideoTelemetry.wrap(
      VideoPlayerObserver(_controller),
      config: const TelemetryConfig(snapshotInterval: Duration(seconds: 1)),
    );
    _telemetry.snapshotStream.listen((snap) {
      if (mounted) setState(() => _snapshot = snap);
    });
    _telemetry.onFirstFrame((ttff) {
      if (mounted) setState(() => _snapshot = _telemetry.snapshot);
    });
    _telemetry.onStall((_) {
      if (mounted) setState(() => _snapshot = _telemetry.snapshot);
    });

    _controller.addListener(() {
      if (mounted) setState(() {});
    });
    _controller.initialize().then((_) {
      if (mounted) {
        setState(() {});
        _controller.play();
      }
    });
  }

  @override
  void dispose() {
    _telemetry.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final val = _controller.value;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Big Buck Bunny'),
        actions: [
          IconButton(icon: const Icon(Icons.cast_outlined), onPressed: () {}),
          IconButton(icon: const Icon(Icons.more_vert), onPressed: () {}),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 16 / 9,
            child: Stack(
              children: [
                Container(
                  color: Colors.black,
                  child: val.isInitialized
                      ? VideoPlayer(_controller)
                      : const Center(child: CircularProgressIndicator()),
                ),

                // kDebugMode ensures this overlay is completely stripped out in release builds
                if (kDebugMode && _snapshot != null)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: _TelemetryOverlay(snapshot: _snapshot!),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Column(
              children: [
                if (val.isInitialized)
                  VideoProgressIndicator(
                    _controller,
                    allowScrubbing: true,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    colors: VideoProgressColors(
                      playedColor: Colors.deepPurpleAccent,
                      bufferedColor: Colors.white24,
                      backgroundColor: Colors.white12,
                    ),
                  ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.replay_10),
                      onPressed: val.isInitialized
                          ? () => _controller.seekTo(
                                val.position - const Duration(seconds: 10),
                              )
                          : null,
                    ),
                    IconButton(
                      iconSize: 48,
                      icon: Icon(
                        val.isPlaying
                            ? Icons.pause_circle_filled
                            : Icons.play_circle_filled,
                        color: Colors.white,
                      ),
                      onPressed: val.isInitialized
                          ? () => val.isPlaying
                              ? _controller.pause()
                              : _controller.play()
                          : null,
                    ),
                    IconButton(
                      icon: const Icon(Icons.forward_10),
                      onPressed: val.isInitialized
                          ? () => _controller.seekTo(
                                val.position + const Duration(seconds: 10),
                              )
                          : null,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TelemetryOverlay extends StatelessWidget {
  const _TelemetryOverlay({required this.snapshot});

  final TelemetrySnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final ttff = snapshot.timeToFirstFrame;
    final stalling = snapshot.isCurrentlyStalling;

    return Container(
      width: 158,
      padding: const EdgeInsets.fromLTRB(10, 7, 10, 8),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: stalling
              ? Colors.white.withValues(alpha: 0.9)
              : Colors.white.withValues(alpha: 0.15),
          width: stalling ? 1.5 : 1,
        ),
      ),
      child: DefaultTextStyle(
        style: const TextStyle(
          fontFamily: 'monospace',
          fontSize: 10.5,
          height: 1.55,
          color: Colors.white,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const Text(
                  'video_telemetry',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 9,
                    letterSpacing: 0.6,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 5),
            const Divider(height: 1, color: Colors.white10),
            const SizedBox(height: 5),
            _row('TTFF', ttff != null ? '${ttff.inMilliseconds}ms' : 'N/A',
                alert: ttff != null && ttff.inMilliseconds > 2000),
            _row('Stalls', '${snapshot.stallCount}',
                alert: snapshot.stallCount > 0),
            _row(
                'Stall time', '${snapshot.totalStallDuration.inMilliseconds}ms',
                alert: snapshot.totalStallDuration.inMilliseconds > 0),
            _row('Rebuffering', snapshot.rebufferingPercent,
                alert: snapshot.rebufferingRatio > 0.02),
            _row('Avg stall',
                '${snapshot.averageStallDuration.inMilliseconds}ms'),
            _row('Seeks', '${snapshot.seekCount}'),
            _row('Stalls/min', snapshot.stallsPerMinute.toStringAsFixed(1),
                alert: snapshot.stallsPerMinute > 1),
            _row('Switches', '${snapshot.segmentSwitchCount}'),
            if (stalling) ...[
              const SizedBox(height: 5),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(3),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.5),
                  ),
                ),
                child: const Text(
                  'STALLING',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _row(String label, String value, {bool alert = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 0.5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.white38)),
          Text(
            value,
            style: TextStyle(
              color: alert ? Colors.orange : Colors.white,
              fontWeight: alert ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}

/// Tab 2: Showcase
/// Contains the deterministic failure demo for package documentation.
class ShowcaseScreen extends StatefulWidget {
  /// Create the showcase screen.
  const ShowcaseScreen({super.key});

  @override
  State<ShowcaseScreen> createState() => _ShowcaseScreenState();
}

class _ShowcaseScreenState extends State<ShowcaseScreen> {
  late final VideoPlayerController _controller;
  late final VideoTelemetry _telemetry;

  TelemetrySnapshot? _latest;
  final List<_LogEntry> _log = [];
  bool _slowMode = false;
  final List<StreamSubscription<dynamic>> _subs = [];

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.networkUrl(
      Uri.parse(
        'https://test-videos.co.uk/vids/bigbuckbunny/mp4/h264/720/'
        'Big_Buck_Bunny_720_10s_20MB.mp4',
      ),
    );
    _telemetry = VideoTelemetry.wrap(
      VideoPlayerObserver(_controller),
      config: const TelemetryConfig(snapshotInterval: Duration(seconds: 1)),
    );

    _subs.add(_telemetry.firstFrameStream.listen((ttff) {
      _log_('Video started after ${ttff.inMilliseconds}ms', LogLevel.ttff);
      if (mounted) setState(() => _latest = _telemetry.snapshot);
    }));
    _subs.add(_telemetry.stallStream.listen((e) {
      _log_(
        'Freeze #${e.index}: ${e.duration.inMilliseconds}ms '
        'at ${e.position.inSeconds}s into video',
        LogLevel.stall,
      );
      if (mounted) setState(() => _latest = _telemetry.snapshot);
    }));
    _subs.add(_telemetry.segmentSwitchStream.listen((e) {
      _log_(
        'Quality ${e.isUpgrade ? "↑" : "↓"}: '
        '${e.fromBitrateKbps} -> ${e.toBitrateKbps}kbps',
        LogLevel.segment,
      );
    }));
    _subs.add(_telemetry.errorStream.listen((e) {
      _log_('Error: ${e.errorDescription}', LogLevel.error);
    }));
    _subs.add(_telemetry.snapshotStream.listen((snap) {
      if (mounted) setState(() => _latest = snap);
    }));

    _controller.addListener(() {
      if (mounted) setState(() {});
    });
    _controller.initialize().then((_) {
      if (mounted) setState(() {});
    });
  }

  Future<void> _simulateStall() async {
    if (!_controller.value.isInitialized) return;
    final pos = _controller.value.position;
    await _controller.pause();
    _log_('Simulating freeze...', LogLevel.info);
    await Future<void>.delayed(const Duration(seconds: 2));
    await _controller.seekTo(pos - const Duration(seconds: 3));
    await _controller.play();
  }

  void _toggleSlowMode() {
    setState(() => _slowMode = !_slowMode);
    if (_slowMode) {
      Future.doWhile(() async {
        if (!mounted || !_slowMode) return false;
        await Future<void>.delayed(const Duration(seconds: 5));
        if (_slowMode && mounted) await _simulateStall();
        return _slowMode;
      });
    }
  }

  void _log_(String msg, LogLevel level) {
    if (!mounted) return;
    setState(() {
      _log.insert(0, _LogEntry(msg, level));
      if (_log.length > 40) _log.removeLast();
    });
  }

  @override
  void dispose() {
    _slowMode = false;
    for (final s in _subs) {
      s.cancel();
    }
    _telemetry.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final val = _controller.value;
    return Scaffold(
      appBar: AppBar(title: const Text('Package Showcase')),
      body: Column(
        children: [
          AspectRatio(
            aspectRatio: 16 / 9,
            child: Container(
              color: Colors.black,
              child: val.isInitialized
                  ? VideoPlayer(_controller)
                  : val.hasError
                      ? Center(child: Text(val.errorDescription ?? 'Error'))
                      : const Center(child: CircularProgressIndicator()),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
            child: Wrap(
              alignment: WrapAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: [
                FloatingActionButton.small(
                  heroTag: 'play2',
                  onPressed: val.isInitialized
                      ? () => val.isPlaying
                          ? _controller.pause()
                          : _controller.play()
                      : null,
                  child: Icon(
                    val.isPlaying ? Icons.pause : Icons.play_arrow,
                  ),
                ),
                FilledButton.icon(
                  onPressed: val.isInitialized ? _simulateStall : null,
                  icon: const Icon(Icons.hourglass_empty_rounded, size: 18),
                  label: const Text('Freeze Video'),
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.orange.shade800,
                  ),
                ),
                FilledButton.tonalIcon(
                  onPressed: _toggleSlowMode,
                  icon: Icon(
                    _slowMode ? Icons.stop_circle_outlined : Icons.repeat,
                    size: 18,
                  ),
                  label: Text(
                    _slowMode ? 'Auto-Freeze: ON' : 'Auto-Freeze: OFF',
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: () {
                    _telemetry.reportSegmentSwitch(
                      fromBitrateKbps: 800,
                      toBitrateKbps: 2400,
                      reason: 'manual',
                    );
                    _log_(
                        'Quality switched: 800 -> 2400kbps', LogLevel.segment);
                  },
                  icon: const Icon(Icons.hd_outlined, size: 18),
                  label: const Text('Switch Quality'),
                ),
                OutlinedButton.icon(
                  onPressed: () {
                    _telemetry.reset();
                    if (mounted) {
                      setState(() {
                        _log.clear();
                        _latest = null;
                      });
                    }
                  },
                  icon: const Icon(Icons.restart_alt, size: 18),
                  label: const Text('Reset Stats'),
                ),
              ],
            ),
          ),
          if (_latest != null) _HealthPanel(snapshot: _latest!),
          Expanded(
            child: Container(
              margin: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF1E1E1E),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
                    child: Text(
                      'What just happened',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade500,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Expanded(
                    child: _log.isEmpty
                        ? Center(
                            child: Text(
                              'Press Play to start',
                              style: TextStyle(color: Colors.grey.shade600),
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                            itemCount: _log.length,
                            itemBuilder: (_, i) => Padding(
                              padding: const EdgeInsets.symmetric(vertical: 3),
                              child: Text(
                                '• ${_log[i].message}',
                                style: TextStyle(
                                  color: _log[i].level.color,
                                  fontFamily: 'monospace',
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HealthPanel extends StatelessWidget {
  const _HealthPanel({required this.snapshot});
  final TelemetrySnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final ttff = snapshot.timeToFirstFrame;
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8),
      color: const Color(0xFF252525),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            if (snapshot.isCurrentlyStalling)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.orange.shade900,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orangeAccent),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.hourglass_empty, color: Colors.white, size: 18),
                    SizedBox(width: 6),
                    Text(
                      'Video is frozen, waiting for data',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            Wrap(
              spacing: 20,
              runSpacing: 12,
              alignment: WrapAlignment.center,
              children: [
                _stat('Time to start',
                    ttff != null ? '${ttff.inMilliseconds}ms' : '--',
                    green: ttff != null),
                _stat('Freezes', '${snapshot.stallCount}',
                    orange: snapshot.stallCount > 0),
                _stat('Time frozen',
                    '${snapshot.totalStallDuration.inMilliseconds}ms',
                    orange: snapshot.totalStallDuration.inMilliseconds > 0),
                _stat('Buffering %', snapshot.rebufferingPercent,
                    orange: snapshot.rebufferingRatio > 0.02),
                _stat('Avg freeze',
                    '${snapshot.averageStallDuration.inMilliseconds}ms'),
                _stat('Seeks', '${snapshot.seekCount}'),
                _stat('Quality changes', '${snapshot.segmentSwitchCount}'),
                _stat(
                    'Freezes/min', snapshot.stallsPerMinute.toStringAsFixed(1),
                    orange: snapshot.stallsPerMinute > 1),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _stat(
    String label,
    String value, {
    bool orange = false,
    bool green = false,
  }) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
        ),
        const SizedBox(height: 3),
        Text(
          value,
          style: TextStyle(
            fontSize: 15,
            fontFamily: 'monospace',
            fontWeight: FontWeight.bold,
            color: orange
                ? Colors.orangeAccent
                : green
                    ? Colors.greenAccent
                    : Colors.white,
          ),
        ),
      ],
    );
  }
}

enum LogLevel {
  ttff(Colors.greenAccent),
  stall(Colors.orange),
  segment(Colors.lightBlueAccent),
  error(Colors.redAccent),
  info(Colors.white38);

  const LogLevel(this.color);
  final Color color;
}

class _LogEntry {
  const _LogEntry(this.message, this.level);
  final String message;
  final LogLevel level;
}
