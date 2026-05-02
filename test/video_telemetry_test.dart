import 'package:flutter_test/flutter_test.dart';
import 'package:video_player/video_player.dart';
import 'package:video_telemetry/video_telemetry.dart';

// fake controller, no platform channel junk.
class FakeVideoPlayerController extends VideoPlayerController {
  FakeVideoPlayerController()
    : super.networkUrl(Uri.parse('https://fake.test/video.mp4'));

  VideoPlayerValue _fakeValue = const VideoPlayerValue(
    duration: Duration(minutes: 5),
  );

  @override
  VideoPlayerValue get value => _fakeValue;

  void setValue(VideoPlayerValue next) {
    _fakeValue = next;
    notifyListeners();
  }

  void setPlaying({bool buffering = false, Duration? position}) {
    setValue(
      value.copyWith(
        isInitialized: true,
        isPlaying: true,
        isBuffering: buffering,
        position: position ?? value.position,
      ),
    );
  }

  void setPaused({Duration? position}) {
    setValue(
      value.copyWith(
        isInitialized: true,
        isPlaying: false,
        isBuffering: false,
        position: position ?? value.position,
      ),
    );
  }

  void setBuffering() {
    setValue(value.copyWith(isPlaying: true, isBuffering: true));
  }

  void setResumed({Duration? position}) {
    setValue(
      value.copyWith(
        isPlaying: true,
        isBuffering: false,
        position: position ?? value.position,
      ),
    );
  }

  void setError(String description) {
    setValue(VideoPlayerValue.erroneous(description));
  }

  @override
  Future<void> initialize() async {}

  @override
  // ignore: must_call_super
  Future<void> dispose() async {
    notifyListeners();
  }
}

VideoPlayerValue _base({
  bool isInitialized = true,
  bool isPlaying = false,
  bool isBuffering = false,
  Duration position = Duration.zero,
  String? errorDescription,
}) {
  return VideoPlayerValue(
    duration: const Duration(minutes: 5),
    isInitialized: isInitialized,
    isPlaying: isPlaying,
    isBuffering: isBuffering,
    position: position,
    errorDescription: errorDescription,
  );
}

void main() {
  late FakeVideoPlayerController controller;
  late VideoTelemetry telemetry;

  setUp(() {
    controller = FakeVideoPlayerController();
    controller.setValue(_base());
    telemetry = VideoTelemetry.wrap(
      controller,
      config: const TelemetryConfig(
        minimumStallDuration: Duration(milliseconds: 200),
        seekJumpThreshold: Duration(milliseconds: 500),
        enableDebugLogging: false,
      ),
    );
  });

  tearDown(() {
    telemetry.dispose();
  });

  group('time-to-first-frame', () {
    test('is null before play() is called', () {
      expect(telemetry.timeToFirstFrame, isNull);
    });

    test('is null while buffering on startup', () {
      controller.setPlaying(buffering: true);
      expect(telemetry.timeToFirstFrame, isNull);
    });

    test('emits on firstFrameStream when first frame arrives', () async {
      final ttffValues = <Duration>[];
      final sub = telemetry.firstFrameStream.listen(ttffValues.add);
      addTearDown(sub.cancel);

      controller.setPlaying(position: Duration.zero);
      await Future<void>.delayed(const Duration(milliseconds: 10));
      controller.setResumed(position: const Duration(milliseconds: 100));

      await Future<void>.delayed(const Duration(milliseconds: 1));
      expect(ttffValues, hasLength(1));
      expect(ttffValues.first.inMilliseconds, greaterThan(0));
    });

    test('does not emit TTFF twice', () async {
      final ttffValues = <Duration>[];
      final sub = telemetry.firstFrameStream.listen(ttffValues.add);
      addTearDown(sub.cancel);

      controller.setPlaying(position: Duration.zero);
      controller.setResumed(position: const Duration(milliseconds: 100));
      controller.setResumed(position: const Duration(milliseconds: 200));

      await Future<void>.delayed(const Duration(milliseconds: 1));
      expect(ttffValues, hasLength(1));
    });

    test('ttffAvailable is false when wrapped while playing', () {
      final controller2 = FakeVideoPlayerController();
      controller2.setValue(_base(isPlaying: true));
      final t2 = VideoTelemetry.wrap(controller2);
      addTearDown(t2.dispose);
      addTearDown(controller2.dispose);

      expect(t2.ttffAvailable, isFalse);
      expect(t2.timeToFirstFrame, isNull);
    });

    test(
      'onFirstFrame delivers cached value after first frame fires',
      () async {
        controller.setPlaying();
        controller.setResumed(position: const Duration(milliseconds: 50));

        await Future<void>.delayed(const Duration(milliseconds: 1));

        final received = <Duration>[];
        final sub = telemetry.onFirstFrame(received.add);
        addTearDown(sub.cancel);
        await Future<void>.microtask(() {});

        expect(received, hasLength(1));
      },
    );
  });

  group('stall detection', () {
    test('stallCount is 0 before any stall', () {
      expect(telemetry.stallCount, 0);
    });

    test('detects a stall and emits StallEvent', () async {
      final stalls = <StallEvent>[];
      final sub = telemetry.stallStream.listen(stalls.add);
      addTearDown(sub.cancel);

      controller.setPlaying();
      controller.setResumed(position: const Duration(milliseconds: 100));
      controller.setBuffering();
      await Future<void>.delayed(const Duration(milliseconds: 300));
      controller.setResumed(position: const Duration(milliseconds: 200));

      await Future<void>.delayed(const Duration(milliseconds: 1));

      expect(stalls, hasLength(1));
      expect(stalls.first.duration.inMilliseconds, greaterThanOrEqualTo(200));
      expect(stalls.first.index, 1);
      expect(telemetry.stallCount, 1);
    });

    test('ignores micro-stalls below minimumStallDuration', () async {
      final stalls = <StallEvent>[];
      final sub = telemetry.stallStream.listen(stalls.add);
      addTearDown(sub.cancel);

      controller.setPlaying();
      controller.setBuffering();
      controller.setResumed(position: const Duration(milliseconds: 50));

      await Future<void>.delayed(const Duration(milliseconds: 1));
      expect(stalls, isEmpty);
      expect(telemetry.stallCount, 0);
    });

    test('tracks multiple stalls', () async {
      final stalls = <StallEvent>[];
      final sub = telemetry.stallStream.listen(stalls.add);
      addTearDown(sub.cancel);

      for (var i = 1; i <= 3; i++) {
        controller.setPlaying();
        controller.setResumed(position: Duration(milliseconds: (i - 1) * 100));
        controller.setBuffering();
        await Future<void>.delayed(const Duration(milliseconds: 250));
        controller.setResumed(position: Duration(milliseconds: i * 100));
      }

      await Future<void>.delayed(const Duration(milliseconds: 5));

      expect(stalls, hasLength(3));
      expect(telemetry.stallCount, 3);
      for (var i = 0; i < 3; i++) {
        expect(stalls[i].index, i + 1);
      }
    });

    test('totalStallDuration accumulates correctly', () async {
      controller.setPlaying();

      controller.setBuffering();
      await Future<void>.delayed(const Duration(milliseconds: 250));
      controller.setResumed(position: const Duration(milliseconds: 100));

      controller.setBuffering();
      await Future<void>.delayed(const Duration(milliseconds: 300));
      controller.setResumed(position: const Duration(milliseconds: 200));

      await Future<void>.delayed(const Duration(milliseconds: 1));

      expect(
        telemetry.totalStallDuration.inMilliseconds,
        greaterThanOrEqualTo(450),
      );
    });

    test('isCurrentlyStalling reflects live stall state', () {
      controller.setPlaying();
      expect(telemetry.isCurrentlyStalling, isFalse);

      controller.setBuffering();
      expect(telemetry.isCurrentlyStalling, isTrue);

      controller.setResumed(position: const Duration(milliseconds: 100));
    });

    test('stall history capacity is respected', () async {
      final limitedTelemetry = VideoTelemetry.wrap(
        controller,
        config: const TelemetryConfig(
          stallHistoryCapacity: 3,
          minimumStallDuration: Duration(milliseconds: 100),
        ),
      );
      addTearDown(limitedTelemetry.dispose);

      controller.setPlaying();

      for (var i = 0; i < 5; i++) {
        controller.setBuffering();
        await Future<void>.delayed(const Duration(milliseconds: 150));
        controller.setResumed(position: Duration(milliseconds: (i + 1) * 100));
      }

      await Future<void>.delayed(const Duration(milliseconds: 1));

      expect(limitedTelemetry.stallHistory.length, 3);
      expect(limitedTelemetry.stallCount, 5);
    });
  });

  group('seek detection', () {
    test('counts explicit seeks', () {
      controller.setPlaying();
      controller.setResumed(position: const Duration(milliseconds: 400));

      controller.setResumed(position: const Duration(seconds: 11));

      expect(telemetry.seekCount, 1);
    });

    test('does not count normal playback advancement as a seek', () {
      controller.setPlaying();
      controller.setResumed(position: Duration.zero);
      controller.setResumed(position: const Duration(milliseconds: 150));
      controller.setResumed(position: const Duration(milliseconds: 300));

      expect(telemetry.seekCount, 0);
    });

    test('seek-induced buffering is not counted as a stall', () async {
      final stalls = <StallEvent>[];
      final sub = telemetry.stallStream.listen(stalls.add);
      addTearDown(sub.cancel);

      controller.setPlaying();
      controller.setResumed(position: const Duration(milliseconds: 400));

      controller.setPlaying(
        buffering: true,
        position: const Duration(seconds: 30),
      );
      await Future<void>.delayed(const Duration(milliseconds: 400));
      controller.setResumed(position: const Duration(seconds: 30));

      await Future<void>.delayed(const Duration(milliseconds: 1));

      expect(stalls, isEmpty);
      expect(telemetry.seekCount, 1);
    });

    test('stall after seek is counted as a new event', () async {
      final stalls = <StallEvent>[];
      final sub = telemetry.stallStream.listen(stalls.add);
      addTearDown(sub.cancel);

      controller.setPlaying();
      controller.setResumed(position: const Duration(milliseconds: 400));

      controller.setPlaying(
        buffering: true,
        position: const Duration(seconds: 30),
      );
      await Future<void>.delayed(const Duration(milliseconds: 250));
      controller.setResumed(position: const Duration(seconds: 30));

      controller.setBuffering();
      await Future<void>.delayed(const Duration(milliseconds: 350));
      controller.setResumed(position: const Duration(milliseconds: 30100));

      await Future<void>.delayed(const Duration(milliseconds: 5));

      expect(stalls, hasLength(1));
    });

    test('backward seek increments seek count', () {
      final seekController = FakeVideoPlayerController();
      seekController.setValue(
        _base(isPlaying: true, position: const Duration(milliseconds: 700)),
      );
      final seekTelemetry = VideoTelemetry.wrap(
        seekController,
        config: const TelemetryConfig(
          seekJumpThreshold: Duration(milliseconds: 500),
        ),
      );
      addTearDown(seekTelemetry.dispose);
      addTearDown(seekController.dispose);

      seekController.setResumed(position: Duration.zero);

      expect(seekTelemetry.seekCount, 1);
    });
  });

  group('loop detection', () {
    test('loop reset is not counted as a seek', () {
      final loopController = FakeVideoPlayerController();
      loopController.setValue(
        _base(
          isPlaying: true,
          position: const Duration(minutes: 4, seconds: 58),
        ),
      );
      final loopTelemetry = VideoTelemetry.wrap(
        loopController,
        config: const TelemetryConfig(
          seekJumpThreshold: Duration(milliseconds: 500),
        ),
      );
      addTearDown(loopTelemetry.dispose);
      addTearDown(loopController.dispose);

      loopController.setResumed(position: const Duration(seconds: 1));

      expect(loopTelemetry.seekCount, 0);
    });
  });

  group('rebufferingRatio', () {
    test('is 0.0 before any playback', () {
      expect(telemetry.rebufferingRatio, 0.0);
    });

    test('is between 0 and 1 after a stall', () async {
      controller.setPlaying();
      controller.setResumed(position: const Duration(milliseconds: 1));
      controller.setBuffering();
      await Future<void>.delayed(const Duration(milliseconds: 250));
      controller.setResumed(position: const Duration(milliseconds: 500));

      await Future<void>.delayed(const Duration(milliseconds: 100));

      expect(telemetry.rebufferingRatio, inInclusiveRange(0.0, 1.0));
    });
  });

  group('error handling', () {
    test('fires on errorStream when controller has error', () async {
      final errors = <PlaybackErrorEvent>[];
      final sub = telemetry.errorStream.listen(errors.add);
      addTearDown(sub.cancel);

      controller.setError('Network timeout');

      await Future<void>.delayed(const Duration(milliseconds: 1));

      expect(errors, hasLength(1));
      expect(errors.first.errorDescription, contains('Network timeout'));
    });

    test('does not fire duplicate error events for same error state', () async {
      final errors = <PlaybackErrorEvent>[];
      final sub = telemetry.errorStream.listen(errors.add);
      addTearDown(sub.cancel);

      controller.setError('Error A');
      controller.setError('Error A');

      await Future<void>.delayed(const Duration(milliseconds: 1));

      expect(errors, hasLength(1));
    });
  });

  group('segment switches', () {
    test('manual reportSegmentSwitch increments count', () {
      telemetry.reportSegmentSwitch(fromBitrateKbps: 800, toBitrateKbps: 2400);
      expect(telemetry.segmentSwitchCount, 1);
    });

    test('fires on segmentSwitchStream', () async {
      final events = <SegmentSwitchEvent>[];
      final sub = telemetry.segmentSwitchStream.listen(events.add);
      addTearDown(sub.cancel);

      telemetry.reportSegmentSwitch(
        fromBitrateKbps: 800,
        toBitrateKbps: 2400,
        reason: 'bandwidth increase',
      );

      await Future<void>.delayed(const Duration(milliseconds: 1));

      expect(events, hasLength(1));
      expect(events.first.isUpgrade, isTrue);
      expect(events.first.isEstimated, isFalse);
    });
  });

  group('dispose', () {
    test('is idempotent', () {
      expect(() {
        telemetry.dispose();
        telemetry.dispose();
        telemetry.dispose();
      }, returnsNormally);
    });

    test('stops emitting events after dispose', () async {
      final stalls = <StallEvent>[];
      final sub = telemetry.stallStream.listen(
        stalls.add,
        onDone: () {},
        cancelOnError: false,
      );
      addTearDown(sub.cancel);

      telemetry.dispose();

      controller.setPlaying();
      controller.setBuffering();
      await Future<void>.delayed(const Duration(milliseconds: 300));
      controller.setResumed(position: const Duration(milliseconds: 100));

      await Future<void>.delayed(const Duration(milliseconds: 1));
      expect(stalls, isEmpty);
    });

    test('reportSegmentSwitch after dispose is a no-op', () {
      telemetry.dispose();
      expect(
        () => telemetry.reportSegmentSwitch(fromBitrateKbps: 800),
        returnsNormally,
      );
    });
  });

  group('snapshot', () {
    test('snapshot reflects current metrics', () async {
      controller.setPlaying();
      controller.setBuffering();
      await Future<void>.delayed(const Duration(milliseconds: 300));
      controller.setResumed(position: const Duration(milliseconds: 100));

      await Future<void>.delayed(const Duration(milliseconds: 1));

      final snap = telemetry.snapshot;
      expect(snap.stallCount, 1);
      expect(snap.totalStallDuration.inMilliseconds, greaterThan(200));
    });

    test('snapshotStream fires periodically', () async {
      final periodicTelemetry = VideoTelemetry.wrap(
        controller,
        config: const TelemetryConfig(
          snapshotInterval: Duration(milliseconds: 50),
        ),
      );
      addTearDown(periodicTelemetry.dispose);

      final snapshots = <TelemetrySnapshot>[];
      final sub = periodicTelemetry.snapshotStream.listen(snapshots.add);
      addTearDown(sub.cancel);

      await Future<void>.delayed(const Duration(milliseconds: 175));

      expect(snapshots.length, greaterThanOrEqualTo(2));
    });
  });

  group('averageStallDuration', () {
    test('is zero when no stalls', () {
      expect(telemetry.averageStallDuration, Duration.zero);
    });

    test('computes mean across multiple stalls', () async {
      controller.setPlaying();

      controller.setBuffering();
      await Future<void>.delayed(const Duration(milliseconds: 300));
      controller.setResumed(position: const Duration(milliseconds: 100));

      controller.setBuffering();
      await Future<void>.delayed(const Duration(milliseconds: 500));
      controller.setResumed(position: const Duration(milliseconds: 200));

      await Future<void>.delayed(const Duration(milliseconds: 5));

      expect(
        telemetry.averageStallDuration.inMilliseconds,
        greaterThanOrEqualTo(300),
      );
    });
  });
  
}
