import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:video_telemetry/video_telemetry.dart';

/// Example app demonstrating VideoTelemetry integration.
///
/// Run with:
///   flutter run example/lib/main.dart
void main() => runApp(const TelemetryExampleApp());

class TelemetryExampleApp extends StatelessWidget {
  const TelemetryExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'VideoTelemetry Example',
      theme: ThemeData.dark(useMaterial3: true),
      home: const PlayerScreen(),
    );
  }
}

class PlayerScreen extends StatefulWidget {
  const PlayerScreen({super.key});

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  late final VideoPlayerController _controller;
  late final VideoTelemetry _telemetry;

  TelemetrySnapshot? _latest;
  final List<String> _log = [];

  @override
  void initState() {
    super.initState();

    _controller = VideoPlayerController.networkUrl(
      // Replace with any HLS/MP4 URL. Using Big Buck Bunny for the example.
      Uri.parse(
        'https://commondatastorage.googleapis.com/gtv-videos-bucket/'
        'sample/BigBuckBunny.mp4',
      ),
    );

    _telemetry = VideoTelemetry.wrap(
      _controller,
      config: const TelemetryConfig(
        minimumStallDuration: Duration(milliseconds: 200),
        snapshotInterval: Duration(seconds: 1),
        enableDebugLogging: true, // Disable in production
      ),
    );

    // Register listeners 

    _telemetry.onFirstFrame((ttff) {
      _appendLog('🎬 First frame in ${ttff.inMilliseconds}ms');
    });

    _telemetry.onStall((event) {
      _appendLog(
        '⏸ Stall #${event.index}: ${event.duration.inMilliseconds}ms '
        'at ${event.position.inSeconds}s',
      );
    });

    _telemetry.onSegmentSwitch((event) {
      final dir = event.isUpgrade ? '↑' : '↓';
      _appendLog(
        '$dir Quality switch: '
        '${event.fromBitrateKbps ?? "?"}→${event.toBitrateKbps ?? "?"}kbps',
      );
    });

    _telemetry.onError((event) {
      _appendLog('❌ Error: ${event.errorDescription}');
    });

    _telemetry.snapshotStream.listen((snap) {
      if (mounted) setState(() => _latest = snap);
    });

    //  Initialize controller 
    _controller.initialize().then((_) {
      if (mounted) setState(() {});
    });
  }

  void _appendLog(String message) {
    if (!mounted) return;
    setState(() {
      _log.insert(0, message);
      if (_log.length > 30) _log.removeLast();
    });
  }

  @override
  void dispose() {
    // Always dispose telemetry before the controller.
    _telemetry.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('VideoTelemetry Example')),
      body: Column(
        children: [
          // Player
          AspectRatio(
            aspectRatio: 16 / 9,
            child: _controller.value.isInitialized
                ? VideoPlayer(_controller)
                : const Center(child: CircularProgressIndicator()),
          ),

          // Controls
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                icon: Icon(
                  _controller.value.isPlaying
                      ? Icons.pause
                      : Icons.play_arrow,
                ),
                onPressed: () {
                  if (_controller.value.isPlaying) {
                    _controller.pause();
                  } else {
                    _controller.play();
                  }
                },
              ),
              TextButton(
                onPressed: () {
                  // Example: simulate a manual segment switch report.
                  _telemetry.reportSegmentSwitch(
                    fromBitrateKbps: 800,
                    toBitrateKbps: 2400,
                    reason: 'manual test',
                  );
                },
                child: const Text('Fake Quality Switch'),
              ),
              TextButton(
                onPressed: _telemetry.reset,
                child: const Text('Reset Metrics'),
              ),
            ],
          ),

          // Metrics panel
          if (_latest != null) _MetricsPanel(snapshot: _latest!),

          // Event log
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(8),
              itemCount: _log.length,
              itemBuilder: (_, i) => Text(
                _log[i],
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricsPanel extends StatelessWidget {
  const _MetricsPanel({required this.snapshot});

  final TelemetrySnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final ttff = snapshot.timeToFirstFrame;
    return Card(
      margin: const EdgeInsets.all(8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Wrap(
          spacing: 16,
          runSpacing: 8,
          children: [
            _Metric(
              label: 'TTFF',
              value: ttff != null ? '${ttff.inMilliseconds}ms' : '—',
            ),
            _Metric(
              label: 'Stalls',
              value: '${snapshot.stallCount}',
            ),
            _Metric(
              label: 'Stall time',
              value: '${snapshot.totalStallDuration.inMilliseconds}ms',
            ),
            _Metric(
              label: 'Rebuffering',
              value: snapshot.rebufferingPercent,
              warning: snapshot.rebufferingRatio > 0.02,
            ),
            _Metric(
              label: 'Avg stall',
              value: '${snapshot.averageStallDuration.inMilliseconds}ms',
            ),
            _Metric(
              label: 'Seeks',
              value: '${snapshot.seekCount}',
            ),
            _Metric(
              label: 'Quality switches',
              value: '${snapshot.segmentSwitchCount}',
            ),
            _Metric(
              label: 'Stalls/min',
              value: snapshot.stallsPerMinute.toStringAsFixed(1),
              warning: snapshot.stallsPerMinute > 1.0,
            ),
            if (snapshot.isCurrentlyStalling)
              const _Metric(
                label: 'Status',
                value: '⏸ STALLING',
                warning: true,
              ),
          ],
        ),
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({
    required this.label,
    required this.value,
    this.warning = false,
  });

  final String label;
  final String value;
  final bool warning;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: Colors.grey,
              ),
        ),
        Text(
          value,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: warning ? Colors.orange : null,
                fontWeight: FontWeight.bold,
                fontFamily: 'monospace',
              ),
        ),
      ],
    );
  }
}
