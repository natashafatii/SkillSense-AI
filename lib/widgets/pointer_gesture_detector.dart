import 'package:flutter/widgets.dart';

/// Preserves Flutter gestures while giving enabled custom controls a hand cursor.
/// Material controls and text inputs retain their own more specific cursors.
class PointerGestureDetector extends GestureDetector {
  PointerGestureDetector({
    super.key,
    super.child,
    super.onTapDown,
    super.onTapUp,
    super.onTap,
    super.onTapMove,
    super.onTapCancel,
    super.onSecondaryTap,
    super.onSecondaryTapDown,
    super.onSecondaryTapUp,
    super.onSecondaryTapCancel,
    super.onTertiaryTapDown,
    super.onTertiaryTapUp,
    super.onTertiaryTapCancel,
    super.onDoubleTapDown,
    super.onDoubleTap,
    super.onDoubleTapCancel,
    super.onLongPressDown,
    super.onLongPressCancel,
    super.onLongPress,
    super.onLongPressStart,
    super.onLongPressMoveUpdate,
    super.onLongPressUp,
    super.onLongPressEnd,
    super.onSecondaryLongPressDown,
    super.onSecondaryLongPressCancel,
    super.onSecondaryLongPress,
    super.onSecondaryLongPressStart,
    super.onSecondaryLongPressMoveUpdate,
    super.onSecondaryLongPressUp,
    super.onSecondaryLongPressEnd,
    super.onTertiaryLongPressDown,
    super.onTertiaryLongPressCancel,
    super.onTertiaryLongPress,
    super.onTertiaryLongPressStart,
    super.onTertiaryLongPressMoveUpdate,
    super.onTertiaryLongPressUp,
    super.onTertiaryLongPressEnd,
    super.onVerticalDragDown,
    super.onVerticalDragStart,
    super.onVerticalDragUpdate,
    super.onVerticalDragEnd,
    super.onVerticalDragCancel,
    super.onHorizontalDragDown,
    super.onHorizontalDragStart,
    super.onHorizontalDragUpdate,
    super.onHorizontalDragEnd,
    super.onHorizontalDragCancel,
    super.onForcePressStart,
    super.onForcePressPeak,
    super.onForcePressUpdate,
    super.onForcePressEnd,
    super.onPanDown,
    super.onPanStart,
    super.onPanUpdate,
    super.onPanEnd,
    super.onPanCancel,
    super.onScaleStart,
    super.onScaleUpdate,
    super.onScaleEnd,
    super.behavior,
    super.excludeFromSemantics,
    super.dragStartBehavior,
    super.trackpadScrollCausesScale,
    super.trackpadScrollToScaleFactor,
    super.supportedDevices,
  });

  @override
  Widget build(BuildContext context) {
    final interactive =
        onTapDown != null ||
        onTapUp != null ||
        onTap != null ||
        onTapMove != null ||
        onTapCancel != null ||
        onSecondaryTap != null ||
        onSecondaryTapDown != null ||
        onSecondaryTapUp != null ||
        onSecondaryTapCancel != null ||
        onTertiaryTapDown != null ||
        onTertiaryTapUp != null ||
        onTertiaryTapCancel != null ||
        onDoubleTapDown != null ||
        onDoubleTap != null ||
        onDoubleTapCancel != null ||
        onLongPressDown != null ||
        onLongPressCancel != null ||
        onLongPress != null ||
        onLongPressStart != null ||
        onLongPressMoveUpdate != null ||
        onLongPressUp != null ||
        onLongPressEnd != null ||
        onSecondaryLongPressDown != null ||
        onSecondaryLongPressCancel != null ||
        onSecondaryLongPress != null ||
        onSecondaryLongPressStart != null ||
        onSecondaryLongPressMoveUpdate != null ||
        onSecondaryLongPressUp != null ||
        onSecondaryLongPressEnd != null ||
        onTertiaryLongPressDown != null ||
        onTertiaryLongPressCancel != null ||
        onTertiaryLongPress != null ||
        onTertiaryLongPressStart != null ||
        onTertiaryLongPressMoveUpdate != null ||
        onTertiaryLongPressUp != null ||
        onTertiaryLongPressEnd != null ||
        onVerticalDragDown != null ||
        onVerticalDragStart != null ||
        onVerticalDragUpdate != null ||
        onVerticalDragEnd != null ||
        onVerticalDragCancel != null ||
        onHorizontalDragDown != null ||
        onHorizontalDragStart != null ||
        onHorizontalDragUpdate != null ||
        onHorizontalDragEnd != null ||
        onHorizontalDragCancel != null ||
        onForcePressStart != null ||
        onForcePressPeak != null ||
        onForcePressUpdate != null ||
        onForcePressEnd != null ||
        onPanDown != null ||
        onPanStart != null ||
        onPanUpdate != null ||
        onPanEnd != null ||
        onPanCancel != null ||
        onScaleStart != null ||
        onScaleUpdate != null ||
        onScaleEnd != null;
    return MouseRegion(
      cursor: interactive ? SystemMouseCursors.click : MouseCursor.defer,
      opaque: false,
      child: super.build(context),
    );
  }
}
