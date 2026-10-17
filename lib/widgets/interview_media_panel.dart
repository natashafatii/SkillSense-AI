import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../services/media/interview_media_controller.dart';
import '../services/media/interview_media_route_observer.dart';

/// Device ownership follows the route and app lifecycle, including routes that
/// cover this widget without disposing it. Resuming never silently reopens devices.
class InterviewMediaPanel extends StatefulWidget {
  const InterviewMediaPanel({super.key, required this.controller});
  final InterviewMediaController controller;
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
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Camera and microphone',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'Preview and microphone checks stay local. The microphone test stream is released immediately. Connecting frame transport separately sends sampled JPEGs to the private interview backend.',
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 180,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // Keep the DOM preview mounted during acquisition and state changes.
                    media.adapter.buildPreview(),
                    if (!media.cameraReady)
                      ColoredBox(
                        color: const Color(0xFFE2E8F0),
                        child: Center(
                          child: Text(
                            media.camera == DeviceCheckState.checking
                                ? 'Waiting for camera permission and live video…'
                                : 'Camera preview is off',
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Semantics(
                liveRegion: true,
                child: Text(
                  media.cameraReady
                      ? 'Camera ready: live video available. Preview is mirrored.'
                      : 'Camera: ${media.camera.name}',
                ),
              ),
              if (media.cameraError != null)
                Semantics(
                  liveRegion: true,
                  child: Text(media.cameraError!.message),
                ),
              if (media.adapter.cameras.isNotEmpty)
                DropdownButtonFormField<String>(
                  key: ValueKey(media.adapter.selectedCameraId),
                  initialValue:
                      media.adapter.cameras.any(
                        (d) => d.id == media.adapter.selectedCameraId,
                      )
                      ? media.adapter.selectedCameraId
                      : null,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Camera device'),
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
              const SizedBox(height: 8),
              Semantics(
                liveRegion: true,
                child: Text(
                  media.voiceOwnsMicrophone
                      ? 'The voice client owns the microphone; local testing is disabled.'
                      : media.microphoneChecked
                      ? 'Microphone permission and live track checked; test stream released. Voice audio is not yet verified.'
                      : 'Microphone: ${media.microphone.name}',
                ),
              ),
              if (media.microphoneError != null)
                Semantics(
                  liveRegion: true,
                  child: Text(media.microphoneError!.message),
                ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton(
                    onPressed: enabled ? () => media.requestCamera() : null,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.dashboardTeal,
                    ),
                    child: const Text('Start / retry camera'),
                  ),
                  OutlinedButton(
                    onPressed: enabled && !media.voiceOwnsMicrophone
                        ? media.checkMicrophone
                        : null,
                    child: const Text('Check microphone permission'),
                  ),
                  OutlinedButton(
                    onPressed: media.isCurrent ? media.stop : null,
                    child: const Text('Stop / cancel checks'),
                  ),
                  OutlinedButton(
                    onPressed: media.cameraReady
                        ? media.checkLocalSample
                        : null,
                    child: const Text('Check local camera sample'),
                  ),
                ],
              ),
              if (media.sampleNotice != null)
                Semantics(liveRegion: true, child: Text(media.sampleNotice!)),
              if (!media.adapter.supported)
                const Text(
                  'Media requires a supported web browser with HTTPS or localhost. Native camera capture is not implemented.',
                ),
            ],
          ),
        ),
      );
    },
  );
}
