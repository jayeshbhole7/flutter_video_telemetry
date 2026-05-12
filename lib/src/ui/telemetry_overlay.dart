import 'package:flutter/material.dart';
import '../models/telemetry_snapshot.dart';

class TelemetryOverlay extends StatelessWidget {
  const TelemetryOverlay({
    required this.snapshot,
    super.key,
    this.showTtff = true,
    this.showStalls = true,
    this.showStallTime = true,
    this.showRebufferingRatio = true,
    this.showAverageStall = true,
    this.showSeeks = true,
    this.showStallsPerMinute = true,
    this.showSwitches = true,
  });

  final TelemetrySnapshot snapshot;

  // Customization flags
  final bool showTtff;
  final bool showStalls;
  final bool showStallTime;
  final bool showRebufferingRatio;
  final bool showAverageStall;
  final bool showSeeks;
  final bool showStallsPerMinute;
  final bool showSwitches;

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
          color: stalling ? Colors.orange : Colors.white24,
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
            const Text(
              'video_telemetry',
              style: TextStyle(color: Colors.white38, fontSize: 9),
            ),
            const Divider(height: 8, color: Colors.white10),
            if (showTtff)
              _row(
                'TTFF',
                ttff != null ? '${ttff.inMilliseconds}ms' : '—',
                alert: ttff != null && ttff.inMilliseconds > 2000,
              ),
            if (showStalls)
              _row(
                'Stalls',
                '${snapshot.stallCount}',
                alert: snapshot.stallCount > 0,
              ),
            if (showStallTime)
              _row(
                'Stall time',
                '${snapshot.totalStallDuration.inMilliseconds}ms',
                alert: snapshot.totalStallDuration.inMilliseconds > 0,
              ),
            if (showRebufferingRatio)
              _row(
                'Rebuffering',
                snapshot.rebufferingPercent,
                alert: snapshot.rebufferingRatio > 0.02,
              ),
            if (showAverageStall)
              _row(
                'Avg stall',
                '${snapshot.averageStallDuration.inMilliseconds}ms',
              ),
            if (showSeeks) _row('Seeks', '${snapshot.seekCount}'),
            if (showStallsPerMinute)
              _row(
                'Stalls/min',
                snapshot.stallsPerMinute.toStringAsFixed(1),
                alert: snapshot.stallsPerMinute > 1,
              ),
            if (showSwitches)
              _row('Switches', '${snapshot.segmentSwitchCount}'),
            if (stalling) ...[
              const SizedBox(height: 4),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(3),
                  border:
                      Border.all(color: Colors.orange.withValues(alpha: 0.5)),
                ),
                child: const Text(
                  'STALLING',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.orange,
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
