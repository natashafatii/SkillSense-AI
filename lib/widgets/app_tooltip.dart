import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

enum TooltipPosition { bottom, right, top }

class AppTooltip extends StatefulWidget {
  final String message;
  final Widget child;
  final TooltipPosition position;
  final double offset;

  const AppTooltip({
    super.key,
    required this.message,
    required this.child,
    this.position = TooltipPosition.bottom,
    this.offset = 8.0,
  });

  @override
  State<AppTooltip> createState() => _AppTooltipState();
}

class _AppTooltipState extends State<AppTooltip> {
  OverlayEntry? _overlayEntry;
  Timer? _hoverTimer;
  bool _isHovered = false;
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_handleFocusChange);
  }

  @override
  void dispose() {
    _focusNode.removeListener(_handleFocusChange);
    _focusNode.dispose();
    _removeTooltip();
    _hoverTimer?.cancel();
    super.dispose();
  }

  void _handleFocusChange() {
    if (_focusNode.hasFocus) {
      _showTooltip();
    } else {
      _removeTooltip();
    }
  }

  void _onEnter() {
    _isHovered = true;
    _hoverTimer?.cancel();
    _hoverTimer = Timer(const Duration(milliseconds: 350), () {
      if (_isHovered && mounted) {
        _showTooltip();
      }
    });
  }

  void _onExit() {
    _isHovered = false;
    _hoverTimer?.cancel();
    _removeTooltip();
  }

  void _onLongPress() {
    _showTooltip();
    Future.delayed(const Duration(milliseconds: 2000), () {
      if (mounted) _removeTooltip();
    });
  }

  void _showTooltip() {
    if (_overlayEntry != null || widget.message.isEmpty) return;
    
    final renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox == null || !renderBox.attached) return;

    final size = renderBox.size;
    final offset = renderBox.localToGlobal(Offset.zero);
    
    _overlayEntry = OverlayEntry(
      builder: (context) {
        final isNight = Theme.of(context).brightness == Brightness.dark;
        
        return CustomSingleChildLayout(
          delegate: _TooltipLayoutDelegate(
            targetOffset: offset,
            targetSize: size,
            position: widget.position,
            spacing: widget.offset,
          ),
          child: FadeTransition(
            opacity: const AlwaysStoppedAnimation(1.0), // Simplified animation
            child: Material(
              color: Colors.transparent,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                decoration: BoxDecoration(
                  color: isNight ? const Color(0xFF1E293B) : const Color(0xFF0F172A),
                  borderRadius: BorderRadius.circular(9),
                  boxShadow: const [
                    BoxShadow(
                      color: Color.fromRGBO(0, 0, 0, 0.4),
                      blurRadius: 24,
                      spreadRadius: -8,
                      offset: Offset(0, 8),
                    ),
                  ],
                ),
                child: Text(
                  widget.message.toUpperCase(),
                  style: GoogleFonts.spaceGrotesk(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.06 * 11,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );

    Overlay.of(context).insert(_overlayEntry!);
  }

  void _removeTooltip() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.message.isEmpty) return widget.child;

    return GestureDetector(
      onLongPress: _onLongPress,
      onTap: _removeTooltip,
      child: MouseRegion(
        onEnter: (_) => _onEnter(),
        onExit: (_) => _onExit(),
        child: Focus(
          focusNode: _focusNode,
          child: widget.child,
        ),
      ),
    );
  }
}

class _TooltipLayoutDelegate extends SingleChildLayoutDelegate {
  final Offset targetOffset;
  final Size targetSize;
  final TooltipPosition position;
  final double spacing;

  _TooltipLayoutDelegate({
    required this.targetOffset,
    required this.targetSize,
    required this.position,
    required this.spacing,
  });

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) => constraints.loosen();

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    double x = 0;
    double y = 0;

    switch (position) {
      case TooltipPosition.bottom:
        x = targetOffset.dx + (targetSize.width - childSize.width) / 2;
        y = targetOffset.dy + targetSize.height + spacing;
        break;
      case TooltipPosition.top:
        x = targetOffset.dx + (targetSize.width - childSize.width) / 2;
        y = targetOffset.dy - childSize.height - spacing;
        break;
      case TooltipPosition.right:
        x = targetOffset.dx + targetSize.width + spacing;
        y = targetOffset.dy + (targetSize.height - childSize.height) / 2;
        break;
    }

    // Basic bounds checking
    if (x < 10) x = 10;
    if (y < 10) y = 10;
    if (x + childSize.width > size.width - 10) x = size.width - childSize.width - 10;
    if (y + childSize.height > size.height - 10) y = size.height - childSize.height - 10;

    return Offset(x, y);
  }

  @override
  bool shouldRelayout(covariant SingleChildLayoutDelegate oldDelegate) => true;
}
