import 'package:flutter/material.dart';
import '../models/phase8_contract.dart';
import '../services/recruiter_observation_controller.dart';

class RecruiterObservationPanel extends StatelessWidget {
  const RecruiterObservationPanel({super.key, required this.controller});
  final RecruiterObservationController controller;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (context, _) {
      if (!controller.authorized) {
        return const Text('Recruiter access is required.');
      }
      final snapshot = controller.snapshot;
      final report = controller.report;
      final counts = snapshot?.frameCounts;
      return Card(
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFFE1E6F0)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Behavioral observations',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Semantics(liveRegion: true, child: Text(controller.notice)),
              Text('Observer transport: ${controller.state.name}'),
              const Text(
                'Sampled JPEG analysis does not provide live video or playback. Observations do not establish intent.',
              ),
              Wrap(
                spacing: 12,
                runSpacing: 8,
                children: [
                  OutlinedButton(
                    onPressed: controller.start,
                    child: const Text('Connect / reconnect observations'),
                  ),
                  OutlinedButton(
                    onPressed: () {
                      controller.start();
                      controller.refresh();
                    },
                    child: const Text('Refresh authorized snapshot'),
                  ),
                  TextButton(
                    onPressed: controller.pause,
                    child: const Text('Pause observation'),
                  ),
                ],
              ),
              if (snapshot == null)
                const Text(
                  'Evidence unavailable. No counts or percentages are assumed.',
                )
              else ...[
                Semantics(
                  liveRegion: true,
                  child: Text('Analysis: ${snapshot.status.name}'),
                ),
                Text(_statusMeaning(snapshot.status)),
                Text(
                  'Revision ${snapshot.revision}; server update ${snapshot.serverTs.toIso8601String()}',
                ),
                const SizedBox(height: 12),
                Text(
                  'Evidence coverage',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                Text('Processed frames: ${snapshot.coverage.processed}'),
                Text('Valid gaze observations: ${snapshot.coverage.validGaze}'),
                Text(
                  'Unknown gaze observations: ${snapshot.coverage.unknown?.toString() ?? 'not provided'}',
                ),
                const Text(
                  'Unknown or unusable observations are not evidence of absence. Frame counts are not elapsed time.',
                ),
                Text(
                  'Centered among valid gaze observations: ${report?.centeredPercentage == null ? 'unavailable' : '${report!.centeredPercentage!.toStringAsFixed(1)}%'}',
                ),
                if (counts == null)
                  const Text('Frame accounting: unavailable for this revision.')
                else
                  Text(
                    'Frames — received: ${counts.received}; admitted: ${counts.admitted}; processed: ${counts.processed}; dropped: ${counts.dropped}; failed: ${counts.failed}; expired: ${counts.expired}.',
                  ),
                const SizedBox(height: 12),
                Text(
                  'Event totals and observed durations',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                if (snapshot.eventSummaries == null)
                  const Text(
                    'Cumulative event counts and durations were not provided. Recent timeline rows are not totals.',
                  )
                else if (snapshot.eventSummaries!.isEmpty)
                  const Text(
                    'The server supplied no event summary entries; no absence is inferred.',
                  )
                else
                  for (final event in snapshot.eventSummaries!)
                    Text(
                      '${event.type}: ${event.eventCount} events; observed duration ${event.observedDurationSeconds == null ? 'unknown' : '${event.observedDurationSeconds!.toStringAsFixed(2)} seconds'}',
                    ),
                Text(
                  'Expression analysis: ${_expression(snapshot.expressionStatus)}',
                ),
                const SizedBox(height: 12),
                Text(
                  'Recent observation timeline',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const Text(
                  'A bounded recent snapshot window. Full history and pagination are unavailable in the current contract.',
                ),
                if (controller.timelineTruncated)
                  Text(
                    'Only the latest ${controller.maxTimelineEntries} supplied entries are retained locally.',
                  ),
                if (snapshot.observations.isEmpty)
                  const Text(
                    'No recent observations supplied. This is not a claim that no events occurred.',
                  )
                else
                  for (final observation in snapshot.observations)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Text(
                        '${observation.startedAt.toIso8601String()} — ${observation.type}; observed duration ${observation.durationSeconds == null ? 'unknown' : '${observation.durationSeconds!.toStringAsFixed(2)} seconds'}',
                      ),
                    ),
                if (report != null) ...[
                  Text(
                    'Finalization reason: ${report.finalizationReason ?? 'not provided'}',
                  ),
                  Text(
                    'Finalized at: ${report.finalizedAt?.toIso8601String() ?? 'not finalized / unknown'}',
                  ),
                  Text(
                    'Versions: ${report.versions.entries.map((e) => '${e.key}: ${e.value}').join('; ')}',
                  ),
                ],
                for (final limitation in snapshot.limitations)
                  Text('Limitation: $limitation'),
                const Text(
                  'Observed durations cover measured intervals only. Do not interpolate across sampling gaps or use these observations as an integrity score.',
                ),
              ],
            ],
          ),
        ),
      );
    },
  );
  static String _expression(String status) => switch (status) {
    'disabled' => 'disabled; no expression measurement',
    'unavailable' => 'unavailable; no expression measurement',
    'processing' => 'processing; no result available',
    'complete' =>
      'measured by server; no expression summary is specified in this contract',
    _ => 'unknown; no neutral expression is assumed',
  };
  static String _statusMeaning(AnalysisState status) => switch (status) {
    AnalysisState.pending => 'Analysis has not started; evidence is not ready.',
    AnalysisState.processing =>
      'Analysis is processing; these are interim observations.',
    AnalysisState.finalizing => 'Finalization is processing admitted work.',
    AnalysisState.complete =>
      'Analysis is complete for the available evidence; inspect coverage and limitations.',
    AnalysisState.partial =>
      'Partial evidence only. Coverage gaps and failures limit interpretation.',
    AnalysisState.failed =>
      'Analysis failed. Available evidence is not a complete report.',
    AnalysisState.disabled =>
      'Analysis is disabled; no measurement is assumed.',
    AnalysisState.unknown =>
      'Analysis state is unknown; availability is not assumed.',
  };
}
