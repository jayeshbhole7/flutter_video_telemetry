# Changelog

## 0.1.0

Initial release.

### Features

- `VideoTelemetry.wrap()` — attaches to any `VideoPlayerController`
- Time-to-first-frame measurement from `play()` to first rendered frame
- Buffer stall detection with configurable minimum duration threshold
- Seek classification — seek-induced buffering excluded from stall count
- Loop reset detection — video loops not misclassified as backward seeks
- Rebuffering ratio computed against effective play time, not wall-clock time
- Manual segment switch reporting via `reportSegmentSwitch()`
- `reset()` for playlist and content-change scenarios
- All metrics available as pull API, streams, or callbacks
- `TelemetryConfig` for tuning all thresholds and intervals
