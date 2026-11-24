import 'package:flutter/material.dart';

import '../models/interview_analysis_contract.dart';

class BehavioralSignalSummary extends StatelessWidget {
  const BehavioralSignalSummary({
    super.key,
    required this.report,
    this.processing = false,
  });

  final BehavioralReport? report;
  final bool processing;

  @override
  Widget build(BuildContext context) {
    final current = report;
    final usable = current?.counts.usable;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          current == null
              ? (processing
                    ? 'Behavioral report processing'
                    : 'Behavioral report unavailable')
              : (current.isFinal ? 'Final report' : 'Interim report'),
        ),
        if (current?.snapshot.status == AnalysisState.partial)
          const Text('Partial evidence'),
        if (current?.snapshot.status == AnalysisState.finalizing)
          const Text('Finalization in progress'),
        if (current?.snapshot.status == AnalysisState.failed)
          const Text('Analysis failed'),
        Text(
          usable == null
              ? 'Usable frame coverage unknown'
              : 'Usable frames $usable of ${current!.counts.processed} processed',
        ),
        for (final (kind, key, label) in const [
          ('phone_visible', 'objects', 'Phone visible'),
          ('multiple_people_observed', 'objects', 'Multiple people'),
          ('no_face_observed', 'face', 'No face observed'),
          ('gaze_away', 'gaze', 'Gaze away'),
        ])
          _signal(
            label,
            current?.signal(kind, key),
            disabled:
                current?.signalReview[kind] == false ||
                (key == 'gaze' &&
                    current?.gazeMeasurement?.calibrationStatus == 'disabled'),
            uncalibrated:
                key == 'gaze' &&
                (current?.gazeUncalibrated == true ||
                    current?.gazeMeasurement?.calibrationStatus ==
                        'uncalibrated'),
            diagnostics: current?.signalDiagnostics[kind],
          ),
        if (current?.gazeMeasurement case final gaze?)
          if (gaze.centeredSeconds != null && gaze.awaySeconds != null)
            Text(
              'Centered ${_seconds(gaze.centeredSeconds)} · '
              'Away ${_seconds(gaze.awaySeconds)}',
            ),
        if (current?.centeredPercentage case final percentage?)
          Text(
            '${percentage.toStringAsFixed(1)}% centered during measured gaze',
          ),
        if (current != null &&
            (current.signalReview['no_face_observed'] != false ||
                current.signalReview['multiple_people_observed'] != false))
          const Text(
            'Face observations describe visible faces. Identity is unverified.',
          ),
      ],
    );
  }

  Widget _signal(
    String label,
    BehavioralSignal? signal, {
    required bool disabled,
    required bool uncalibrated,
    required Object? diagnostics,
  }) {
    final state =
        signal?.state ??
        (processing
            ? BehavioralSignalState.processing
            : BehavioralSignalState.unavailable);
    final status = switch (state) {
      _ when disabled => 'Review disabled',
      BehavioralSignalState.processing => 'Processing',
      BehavioralSignalState.unavailable =>
        uncalibrated ? 'Unavailable (uncalibrated)' : 'Unavailable',
      BehavioralSignalState.insufficientCoverage => 'Insufficient coverage',
      BehavioralSignalState.measuredZero => 'Measured, no event observed',
      BehavioralSignalState.eventsObserved =>
        'Episodes observed (${signal!.events})',
    };
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$label · $status'),
          if (!disabled && signal?.knownSeconds != null)
            Text(
              'Supported ${_seconds(signal!.knownSeconds)}'
              '${signal.unknownSeconds == null ? '' : ' · Unmeasured ${_seconds(signal.unknownSeconds)}'}',
            ),
          if (diagnostics case final Map<String, dynamic> counts)
            Text(
              '${counts['frame_detections']} frame detections · '
              '${counts['entry_qualified_frames']} at entry threshold · '
              'Below-duration runs ${counts['below_onset_runs']}',
            ),
        ],
      ),
    );
  }

  static String _seconds(double? value) =>
      value == null ? 'unknown' : '${value.toStringAsFixed(1)} s';
}
