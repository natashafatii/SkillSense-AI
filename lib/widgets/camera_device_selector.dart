import 'package:flutter/material.dart';

import '../services/media/interview_media_controller.dart';

/// Opens an in-page device menu; only selecting a new device acquires a stream.
class CameraDeviceSelector extends StatefulWidget {
  const CameraDeviceSelector({super.key, required this.media});
  final InterviewMediaController media;

  @override
  State<CameraDeviceSelector> createState() => _CameraDeviceSelectorState();
}

class _CameraDeviceSelectorState extends State<CameraDeviceSelector> {
  final MenuController _menu = MenuController();
  bool _refreshing = false;

  Future<void> _openMenu() async {
    if (_menu.isOpen) {
      _menu.close();
      return;
    }
    final media = widget.media;
    if (_refreshing || !media.isCurrent || media.busy) return;
    _refreshing = true;
    try {
      await media.adapter.refreshCameras();
      if (!mounted || !media.isCurrent || media.busy) return;
      if (ModalRoute.of(context)?.isCurrent == false) return;
      setState(() {});
      // MenuAnchor uses an Overlay, without pushing a route over the lobby.
      _menu.open();
    } catch (_) {
      if (mounted && media.isCurrent) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Unable to list cameras. Please try again.'),
          ),
        );
      }
    } finally {
      _refreshing = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final media = widget.media;
    final devices = List.of(media.adapter.cameras);
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final ink = dark ? const Color(0xFFF1F5F9) : const Color(0xFF0F172A);
    final border = dark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    final selected = devices
        .where((d) => d.id == media.adapter.selectedCameraId)
        .firstOrNull;
    final enabled = media.isCurrent && !media.busy;
    String label(int i) =>
        devices[i].label.isEmpty ? 'Camera ${i + 1}' : devices[i].label;
    return LayoutBuilder(
      builder: (context, constraints) => MenuAnchor(
        controller: _menu,
        consumeOutsideTap: true,
        style: MenuStyle(
          backgroundColor: WidgetStatePropertyAll(
            dark ? const Color(0xFF172132) : Colors.white,
          ),
          minimumSize: WidgetStatePropertyAll(Size(constraints.maxWidth, 0)),
          maximumSize: WidgetStatePropertyAll(Size(constraints.maxWidth, 240)),
        ),
        menuChildren: [
          for (var i = 0; i < devices.length; i++)
            MenuItemButton(
              onPressed: enabled
                  ? () {
                      final id = devices[i].id;
                      if (id != media.adapter.selectedCameraId) {
                        media.requestCamera(deviceId: id);
                      }
                    }
                  : null,
              child: Text(
                label(i),
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: ink, fontSize: 13, fontFamily: 'Inter'),
              ),
            ),
          if (devices.isEmpty)
            const MenuItemButton(child: Text('No cameras available')),
        ],
        builder: (context, controller, child) => Semantics(
          button: true,
          label: 'Choose camera',
          child: InkWell(
            key: const Key('interview-camera-selector'),
            onTap: enabled ? _openMenu : null,
            borderRadius: BorderRadius.circular(10),
            child: InputDecorator(
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
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      selected == null
                          ? 'Select camera'
                          : selected.label.isEmpty
                          ? 'Camera'
                          : selected.label,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: ink,
                        fontSize: 13,
                        fontFamily: 'Inter',
                      ),
                    ),
                  ),
                  const Icon(Icons.arrow_drop_down, color: Color(0xFF64748B)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
