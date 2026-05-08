# Changelog

## 0.1.3

- Fix README image rendering on pub.dev by using the absolute GitHub blob URL with `?raw=true`.

## 0.1.2

- Bundle the demo GIF locally (`screenshots/metrics.gif`) so it renders correctly under `pub.dev`'s strict Content Security Policy.

## 0.1.1

- Fix `pub.dev` score issues:
  - Add missing dartdoc comments for models and config.
  - Shorten package description to meet the 180-character limit.
  - Update `README.md` to use standard markdown for images rather than HTML tags so they display properly on pub.dev.

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
