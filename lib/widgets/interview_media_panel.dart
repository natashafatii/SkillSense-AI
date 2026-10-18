import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../services/media/interview_media_controller.dart';
import '../services/media/interview_media_route_observer.dart';

/// Device ownership follows the route and app lifecycle, including routes that
/// cover this widget without disposing it. Resuming never silently reopens devices.
class InterviewMediaPanel extends StatefulWidget {
  const InterviewMediaPanel({
    super.key,
    required this.controller,
    this.brightness,
  });
  final InterviewMediaController controller;
  final Brightness? brightness;
  @override
  State<InterviewMediaPanel> createState() => _InterviewMediaPanelState();
}

class _InterviewMediaPanelState extends State<InterviewMediaPanel>
    with WidgetsBindingObserver, RouteAware {
  ModalRoute<dynamic>? _route;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (_route != route) {
      interviewMediaRouteObserver.unsubscribe(this);
      _route = route;
      if (route != null) interviewMediaRouteObserver.subscribe(this, route);
    }
  }

  @override
  void didPushNext() => widget.controller.stop();
  @override
  void didPop() => widget.controller.stop();
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.hidden ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      widget.controller.stop();
    }
  }

  @override
  void deactivate() {
    widget.controller.stop(notify: false);
    super.deactivate();
  }

  @override
  void dispose() {
    interviewMediaRouteObserver.unsubscribe(this);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.controller,
    builder: (context, _) {
      final media = widget.controller;
      final enabled = media.isCurrent && !media.busy;
      final brightness = widget.brightness ?? Theme.of(context).brightness;
      final dark = brightness == Brightness.dark;
      final surface = dark ? const Color(0xFF172132) : Colors.white;
      final ink = dark ? const Color(0xFFF1F5F9) : const Color(0xFF0F172A);
      final muted = dark ? const Color(0xFFABB9CC) : const Color(0xFF64748B);
      final border = dark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
      final tint = dark ? const Color(0xFF223448) : const Color(0xFFF1F8F7);
      const teal = Color(0xFF0A8A76);
      final accent = dark ? const Color(0xFF5EEAD4) : teal;
      final errorColor = dark
          ? const Color(0xFFFDA4AF)
          : const Color(0xFFC2413A);
      final theme = Theme.of(context).copyWith(
        brightness: brightness,
        colorScheme: ColorScheme.fromSeed(
          seedColor: teal,
          brightness: brightness,
        ),
        textTheme: Theme.of(context).textTheme.apply(
          fontFamily: 'Inter',
          bodyColor: ink,
          displayColor: ink,
        ),
      );
      return Theme(
        data: theme,
        child: Material(
          key: const Key('interview-device-card'),
          color: surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: border),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: tint,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.videocam_outlined,
                        color: accent,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Camera and microphone',
                            style: TextStyle(
                              color: ink,
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            'Get ready for your interview',
                            style: TextStyle(
                              color: muted,
                              fontSize: 12,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: LayoutBuilder(
                    builder: (context, constraints) => SizedBox(
                      key: const Key('interview-camera-preview'),
                      height: (constraints.maxWidth * .625)
                          .clamp(180.0, 340.0)
                          .toDouble(),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          const ColoredBox(color: Color(0xFF0F172A)),
                          // Never replace the platform view when device state changes.
                          media.adapter.buildPreview(),
                          if (!media.cameraReady)
                            ColoredBox(
                              color: const Color(0xFF0F172A),
                              child: Center(
                                child: SingleChildScrollView(
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      if (media.camera ==
                                          DeviceCheckState.checking)
                                        const SizedBox(
                                          width: 28,
                                          height: 28,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: AppColors.dashboardTeal,
                                          ),
                                        )
                                      else
                                        const Icon(
                                          Icons.videocam_off_outlined,
                                          size: 32,
                                          color: Color(0xFF94A3B8),
                                        ),
                                      const SizedBox(height: 12),
                                      Text(
                                        media.camera ==
                                                DeviceCheckState.checking
                                            ? 'Allow camera access in your browser'
                                            : 'Your camera preview',
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      const Text(
                                        'Keep your face in the frame.',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          color: Color(0xFFABB9CC),
                                          fontSize: 12,
                                          height: 1.5,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Semantics(
                  liveRegion: true,
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _status(
                        media.cameraReady
                            ? 'Camera on'
                            : media.camera == DeviceCheckState.checking
                            ? 'Camera access pending'
                            : 'Camera off',
                        media.cameraReady,
                        tint,
                        muted,
                        accent,
                      ),
                      _status(
                        media.voiceOwnsMicrophone
                            ? 'Interview microphone'
                            : media.microphoneChecked
                            ? 'Microphone checked'
                            : 'Microphone not checked',
                        media.microphoneChecked,
                        tint,
                        muted,
                        accent,
                      ),
                    ],
                  ),
                ),
                if (media.cameraReady) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Mirrored preview',
                    style: TextStyle(color: muted, fontSize: 11),
                  ),
                ],
                if (media.cameraError != null)
                  _error(media.cameraError!.message, errorColor),
                if (media.adapter.cameras.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  DropdownButtonFormField<String>(
                    key: ValueKey(media.adapter.selectedCameraId),
                    initialValue:
                        media.adapter.cameras.any(
                          (d) => d.id == media.adapter.selectedCameraId,
                        )
                        ? media.adapter.selectedCameraId
                        : null,
                    isExpanded: true,
                    style: TextStyle(
                      color: ink,
                      fontSize: 13,
                      fontFamily: 'Inter',
                    ),
                    dropdownColor: surface,
                    decoration: InputDecoration(
                      labelText: 'Camera',
                      floatingLabelBehavior: FloatingLabelBehavior.always,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 14,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: border),
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    items: [
                      for (var i = 0; i < media.adapter.cameras.length; i++)
                        DropdownMenuItem(
                          value: media.adapter.cameras[i].id,
                          child: Text(
                            media.adapter.cameras[i].label.isEmpty
                                ? 'Camera ${i + 1}'
                                : media.adapter.cameras[i].label,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                    onChanged: enabled
                        ? (id) => media.requestCamera(deviceId: id)
                        : null,
                  ),
                ],
                const SizedBox(height: 12),
                Semantics(
                  liveRegion: true,
                  child: Text(
                    media.voiceOwnsMicrophone
                        ? 'Your microphone is reserved for interview audio.'
                        : media.microphoneChecked
                        ? 'Microphone access checked. Interview audio connects separately.'
                        : 'Check microphone access before joining.',
                    style: TextStyle(color: muted, fontSize: 12, height: 1.5),
                  ),
                ),
                if (media.microphoneError != null)
                  _error(media.microphoneError!.message, errorColor),
                const SizedBox(height: 16),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final cameraButton = FilledButton.icon(
                      onPressed: enabled ? () => media.requestCamera() : null,
                      icon: const Icon(Icons.videocam_outlined, size: 18),
                      label: Text(
                        media.cameraReady
                            ? 'Restart camera'
                            : media.camera == DeviceCheckState.failed
                            ? 'Retry camera'
                            : 'Enable camera',
                      ),
                      style: FilledButton.styleFrom(
                        backgroundColor: teal,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(0, 44),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    );
                    final microphoneButton = OutlinedButton.icon(
                      onPressed: enabled && !media.voiceOwnsMicrophone
                          ? media.checkMicrophone
                          : null,
                      icon: const Icon(Icons.mic_none_rounded, size: 18),
                      label: Text(
                        media.microphoneChecked
                            ? 'Recheck microphone'
                            : 'Check microphone',
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: ink,
                        minimumSize: const Size(0, 44),
                        side: BorderSide(color: border),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    );
                    if (constraints.maxWidth < 460) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          cameraButton,
                          const SizedBox(height: 8),
                          microphoneButton,
                        ],
                      );
                    }
                    return Row(
                      children: [
                        Expanded(child: cameraButton),
                        const SizedBox(width: 10),
                        Expanded(child: microphoneButton),
                      ],
                    );
                  },
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: media.isCurrent ? media.stop : null,
                    icon: const Icon(Icons.stop_circle_outlined, size: 16),
                    label: const Text('Stop checks'),
                    style: TextButton.styleFrom(foregroundColor: muted),
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.shield_outlined, size: 15, color: muted),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Device checks stay on this device. Joining an interview may send camera snapshots to the interview service.',
                        style: TextStyle(
                          color: muted,
                          fontSize: 11,
                          height: 1.5,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                  childrenPadding: const EdgeInsets.only(bottom: 8),
                  shape: const Border(),
                  collapsedShape: const Border(),
                  title: Text(
                    'Camera troubleshooting',
                    style: TextStyle(color: muted, fontSize: 12),
                  ),
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: OutlinedButton.icon(
                        onPressed: media.cameraReady
                            ? media.checkLocalSample
                            : null,
                        icon: const Icon(Icons.camera_alt_outlined, size: 16),
                        label: const Text('Test a camera frame'),
                      ),
                    ),
                    if (media.sampleNotice != null)
                      Semantics(
                        liveRegion: true,
                        child: Text(
                          media.sampleNotice!,
                          style: TextStyle(color: muted, fontSize: 12),
                        ),
                      ),
                  ],
                ),
                if (!media.adapter.supported)
                  _error(
                    'Camera checks require a supported browser using HTTPS or localhost.',
                    errorColor,
                  ),
              ],
            ),
          ),
        ),
      );
    },
  );

  Widget _status(
    String label,
    bool ready,
    Color tint,
    Color muted,
    Color accent,
  ) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
    decoration: BoxDecoration(
      color: ready ? tint : muted.withValues(alpha: .08),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          ready
              ? Icons.check_circle_rounded
              : Icons.radio_button_unchecked_rounded,
          size: 14,
          color: ready ? accent : muted,
        ),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            label,
            style: TextStyle(
              color: ready ? accent : muted,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    ),
  );

  Widget _error(String message, Color color) => Padding(
    padding: const EdgeInsets.only(top: 10),
    child: Semantics(
      liveRegion: true,
      child: Text(
        message,
        style: TextStyle(color: color, fontSize: 12, height: 1.5),
      ),
    ),
  );
}
