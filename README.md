# video_telemetry

[![pub.dev](https://img.shields.io/pub/v/video_telemetry.svg)](https://pub.dev/packages/video_telemetry)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

A metrics layer that wraps any `VideoPlayerController` and exposes real playback performance data — stalls, buffering ratio, time-to-first-frame, and more.

It attaches **on top of** `video_player` — not instead of it. Your player works exactly as before.

![metrics](https://github.com/jayeshbhole7/flutter_video_telemetry/blob/main/screenshots/metrics.gif?raw=true)

---

## TL;DR

```dart
import 'package:video_player/video_player.dart';
import 'package:video_telemetry/video_telemetry.dart';

final controller = VideoPlayerController.networkUrl(Uri.parse(url));
final telemetry = VideoTelemetry.wrap(controller);

await controller.initialize();
await controller.play();

telemetry.onStall((event) {
  print('Stall #${event.index}: ${event.duration.inMilliseconds}ms');
});

print(telemetry.timeToFirstFrame); // Duration(milliseconds: 187)
print(telemetry.rebufferingRatio); // 0.032 → 3.2% of watch time was stalls
```

## Installation

```yaml
dependencies:
  video_player: ^2.8.0
  video_telemetry: ^0.1.3
```

---

## Guide

### Contents

- [Wrap a controller](#wrap-a-controller)
- [Dispose](#dispose)
- [Listen to stalls](#listen-to-stalls)
- [Listen to first frame](#listen-to-first-frame)
- [Listen to errors](#listen-to-errors)
- [Pull metrics directly](#pull-metrics-directly)
- [Use snapshot stream](#use-snapshot-stream)
- [Report segment switches](#report-segment-switches)
- [Reset a session](#reset-a-session)
- [Configure telemetry](#configure-telemetry)
- [Feeds and lazy loading](#feeds-and-lazy-loading)
- [Send to analytics](#send-to-analytics)

---

### Wrap a controller

Pass any `VideoPlayerController` to `VideoTelemetry.wrap`. The controller can be uninitialized, paused, or already playing.

```dart
final telemetry = VideoTelemetry.wrap(controller);
```

> **Note:** For accurate Time-to-First-Frame (TTFF), call `wrap()` before `initialize()`. If the controller is already playing when `wrap()` is called, TTFF will be unavailable for that session.

---

### Dispose

Always dispose telemetry before the controller:

```dart
telemetry.dispose();
controller.dispose();
```

`dispose()` is idempotent — safe to call multiple times.

---

### Listen to stalls

```dart
telemetry.onStall((event) {
  print('duration: ${event.duration.inMilliseconds}ms');
  print('position: ${event.position.inMilliseconds}ms');
  print('index: ${event.index}');
});
```

Or subscribe to the stream directly:

```dart
telemetry.stallStream.listen((event) { ... });
```

---

### Listen to first frame

```dart
telemetry.onFirstFrame((ttff) {
  print('First frame: ${ttff.inMilliseconds}ms');
});
```

If the first frame has already occurred when you register the callback, it is delivered immediately via microtask.

Or subscribe to the stream:

```dart
telemetry.firstFrameStream.listen((ttff) { ... });
```

---

### Listen to errors

```dart
telemetry.onError((error) {
  print('Playback error: ${error.message}');
});
```

Or subscribe to the stream:

```dart
telemetry.errorStream.listen((error) { ... });
```

---

### Pull metrics directly

All metrics are available as properties at any time:

```dart
Duration?  telemetry.timeToFirstFrame
bool       telemetry.ttffAvailable
int        telemetry.stallCount
Duration   telemetry.totalStallDuration
double     telemetry.rebufferingRatio      // 0.0–1.0
Duration   telemetry.averageStallDuration
int        telemetry.seekCount
int        telemetry.segmentSwitchCount
bool       telemetry.isCurrentlyStalling

List<StallEvent>          telemetry.stallHistory
List<SegmentSwitchEvent>  telemetry.segmentSwitchHistory

TelemetrySnapshot         telemetry.snapshot
```

---

### Use snapshot stream

Enable periodic snapshots via config, then subscribe:

```dart
final telemetry = VideoTelemetry.wrap(
  controller,
  config: const TelemetryConfig(snapshotInterval: Duration(seconds: 1)),
);

telemetry.snapshotStream.listen((snap) {
  print(snap.stallsPerMinute);
  print(snap.rebufferingRatio);
});
```

The snapshot stream is useful for driving a live debug overlay or a real-time dashboard.

---

### Report segment switches

`video_player` does not expose HLS/DASH segment metadata. If your app has access to the native player via platform channels, report switches manually:

```dart
telemetry.reportSegmentSwitch(
  fromBitrateKbps: 800,
  toBitrateKbps: 2400,
  fromResolution: '640x360',
  toResolution: '1280x720',
  reason: 'bandwidth increase',
);
```

---

### Reset a session

Call `reset()` to clear all metrics without stopping monitoring — useful when moving to the next item in a playlist:

```dart
Future<void> playNext(String url) async {
  await controller.pause();
  await controller.load(url);
  telemetry.reset();
  await controller.play();
}
```

---

### Configure telemetry

```dart
VideoTelemetry.wrap(
  controller,
  config: const TelemetryConfig(
    // Stalls shorter than this are ignored.
    minimumStallDuration: Duration(milliseconds: 200),

    // How often the fallback poller runs.
    pollingInterval: Duration(milliseconds: 100),

    // Position jumps larger than this are classified as seeks.
    seekJumpThreshold: Duration(milliseconds: 500),

    // Emit periodic snapshots on snapshotStream.
    snapshotInterval: Duration(seconds: 5),

    // Max stall events retained in stallHistory.
    stallHistoryCapacity: 50,

    // Print internal state transitions (dev only).
    enableDebugLogging: false,
  ),
)
```

---

### Feeds and lazy loading

In production apps, you rarely initialize a video player the moment a widget builds. Instead, you lazy-load when it scrolls into view.

Wrap the controller before `initialize()` so TTFF is captured correctly. Here is a complete pattern using `visibility_detector`:

```dart
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:visibility_detector/visibility_detector.dart';
import 'package:video_telemetry/video_telemetry.dart';

class FeedVideoPlayer extends StatefulWidget {
  final String videoUrl;

  const FeedVideoPlayer({super.key, required this.videoUrl});

  @override
  State<FeedVideoPlayer> createState() => _FeedVideoPlayerState();
}

class _FeedVideoPlayerState extends State<FeedVideoPlayer> {
  VideoPlayerController? _controller;
  VideoTelemetry? _telemetry;
  TelemetrySnapshot? _snapshot;

  Future<void> _initializePlayer() async {
    if (_controller != null) return;

    _controller = VideoPlayerController.networkUrl(
      Uri.parse(widget.videoUrl),
      formatHint: VideoFormat.hls,
    );

    // Wrap BEFORE initialize() so TTFF is captured correctly.
    _telemetry = VideoTelemetry.wrap(
      _controller!,
      config: const TelemetryConfig(snapshotInterval: Duration(seconds: 1)),
    );

    _telemetry!.snapshotStream.listen((snap) {
      if (mounted) setState(() => _snapshot = snap);
    });

    await _controller!.initialize();
    if (mounted) setState(() {});
    await _controller!.play();
  }

  @override
  void dispose() {
    _telemetry?.dispose(); // Always dispose telemetry first
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return VisibilityDetector(
      key: Key(widget.videoUrl),
      onVisibilityChanged: (info) {
        if (!mounted) return;
        if (info.visibleFraction > 0.5) {
          if (_controller == null) {
            _initializePlayer();
          } else {
            _controller!.play();
          }
        } else {
          _controller?.pause();
        }
      },
      child: Stack(
        alignment: Alignment.center,
        children: [
          // The Video
          if (_controller?.value.isInitialized ?? false)
            AspectRatio(
              aspectRatio: _controller!.value.aspectRatio,
              child: VideoPlayer(_controller!),
            )
          else
            const ColoredBox(color: Colors.black),

          // Wrapped in kDebugMode so it is 100% stripped from release builds
          if (kDebugMode && _snapshot != null)
            Positioned(
              top: 8,
              right: 8,
              child: TelemetryOverlay(
                snapshot: _snapshot!,
                // Customize your view! Hide what you don't need:
                showSeeks: false,
                showAverageStall: false,
              ),
            ),
        ],
      ),
    );
  }
}
```

---

### Send to analytics

#### On every stall

```dart
telemetry.onStall((event) {
  FirebaseAnalytics.instance.logEvent(
    name: 'video_stall',
    parameters: {
      'duration_ms': event.duration.inMilliseconds,
      'position_ms': event.position.inMilliseconds,
      'content_id': currentContentId,
    },
  );
});
```

#### On first frame

```dart
telemetry.onFirstFrame((ttff) {
  Datadog.rum.addAction(
    RumActionType.custom,
    'ttff',
    attributes: {
      'ttff_ms': ttff.inMilliseconds,
      'content_type': 'vod',
    },
  );
});
```

---

## Metrics reference

| Metric                 | Property                     | Description                                      |
| ---------------------- | ---------------------------- | ------------------------------------------------ |
| Time-to-first-frame    | `timeToFirstFrame`           | Duration from `play()` to first rendered frame   |
| Stall count            | `stallCount`                 | Number of rebuffering interruptions              |
| Total stall duration   | `totalStallDuration`         | Cumulative time spent rebuffering                |
| Rebuffering ratio      | `rebufferingRatio`           | Stall time / (active play + stall time)          |
| Average stall duration | `averageStallDuration`       | Mean duration of a single stall                  |
| Seek count             | `seekCount`                  | Number of explicit seek operations               |
| Segment switch count   | `segmentSwitchCount`         | Quality/bitrate switches                         |
| Stalls per minute      | `snapshot.stallsPerMinute`   | Normalized stall frequency                       |

---

## Streams reference

All streams are broadcast streams — multiple listeners are supported.

| Stream                                             | Description                                       |
| -------------------------------------------------- | ------------------------------------------------- |
| `Stream<StallEvent> stallStream`                   | Emits on every stall event                        |
| `Stream<Duration> firstFrameStream`                | Emits once when the first frame is rendered       |
| `Stream<SegmentSwitchEvent> segmentSwitchStream`   | Emits on every reported segment switch            |
| `Stream<PlaybackErrorEvent> errorStream`           | Emits on playback error transitions               |
| `Stream<TelemetrySnapshot> snapshotStream`         | Periodic snapshot (requires `snapshotInterval`)   |

---

## Edge cases

| Scenario                                          | Behavior                                                    |
| ------------------------------------------------- | ----------------------------------------------------------- |
| Controller already playing when `wrap()` called   | TTFF unavailable; stall detection works normally            |
| Seek-induced buffering                            | Classified as seek, excluded from stall count               |
| Video loop reset                                  | Not classified as seek (backward jump near end is detected) |
| Micro-stalls `< minimumStallDuration`             | Silently ignored                                            |
| `dispose()` called multiple times                 | No-op after first call                                      |
| Controller disposed before telemetry              | Listener removal wrapped in try/catch                       |
| `reportSegmentSwitch()` after `dispose()`         | No-op                                                       |
| `onFirstFrame` registered after TTFF fired        | Callback invoked via microtask with cached value            |
| App backgrounded during playback                  | `isPlaying` becomes false; not counted as stall             |
| Playback errors                                   | Surfaced on `errorStream`; one event per error transition   |
| High playback speeds (2×, 4×)                     | `seekJumpThreshold` scales with `playbackSpeed`             |

---

## What `video_telemetry` does not do

- **Play video.** It wraps your existing player.
- **Access native HLS/DASH metadata.** It works at the `VideoPlayerController` API surface. For bitrate-level segment data, use `reportSegmentSwitch()` from your native integration.
- **Persist data.** You own the transport to your analytics backend.
- **Replace your error handling.** It surfaces errors from `VideoPlayerValue.hasError`; your app decides what to do with them.

---

## License

This project is licensed under the MIT License — see the [LICENSE](LICENSE) file for details.
