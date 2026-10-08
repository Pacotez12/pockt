import 'dart:io';
import 'package:flutter_driver/flutter_driver.dart' as driver;
import 'package:integration_test/integration_test_driver.dart';

Future<void> main() => integrationDriver(
      responseDataCallback: (data) async {
        if (data != null) {
          final timelineData = data['transiciones'] as Map<String, dynamic>;
          final timeline = driver.Timeline.fromJson(timelineData);
          final summary = driver.TimelineSummary.summarize(timeline);
          await summary.writeTimelineToFile(
            'transiciones',
            pretty: true,
            includeSummary: true,
          );

          _printTopRasterEvents(timelineData);
        }
      },
    );

void _printTopRasterEvents(Map<String, dynamic> timelineData) {
  final events = (timelineData['traceEvents'] as List<dynamic>?)
          ?.cast<Map<String, dynamic>>() ??
      const [];

  final rasterTids = <int>{};
  for (final e in events) {
    if (e['ph'] == 'M' && e['name'] == 'thread_name') {
      final tname = (e['args']?['name'] as String? ?? '').toLowerCase();
      if (tname.contains('raster')) {
        final tid = e['tid'] as int?;
        if (tid != null) rasterTids.add(tid);
      }
    }
  }

  final stacks = <String, List<int>>{};
  final durations = <String, int>{};

  for (final e in events) {
    final tid = e['tid'] as int?;
    if (rasterTids.isNotEmpty && (tid == null || !rasterTids.contains(tid))) {
      continue;
    }
    final name = e['name'] as String?;
    if (name == null) continue;
    final ph = e['ph'] as String?;
    final ts = (e['ts'] as num?)?.toInt() ?? 0;

    if (ph == 'X') {
      final dur = (e['dur'] as num?)?.toInt() ?? 0;
      durations[name] = (durations[name] ?? 0) + dur;
    } else if (ph == 'B') {
      final key = '$tid:$name';
      (stacks[key] ??= []).add(ts);
    } else if (ph == 'E') {
      final key = '$tid:$name';
      final stack = stacks[key];
      if (stack != null && stack.isNotEmpty) {
        final startTs = stack.removeLast();
        final dur = ts - startTs;
        if (dur > 0) {
          durations[name] = (durations[name] ?? 0) + dur;
        }
      }
    }
  }

  final sorted = durations.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));
  final top5 = sorted.take(5);

  stdout.writeln('\n--- Top 5 eventos de raster por tiempo total ---');
  for (final entry in top5) {
    final ms = (entry.value / 1000).toStringAsFixed(2);
    stdout.writeln('  ${entry.key}: $ms ms');
  }
  stdout.writeln('------------------------------------------------\n');
}
