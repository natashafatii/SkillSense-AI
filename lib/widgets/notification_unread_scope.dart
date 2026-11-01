import 'dart:async';
import 'package:flutter/widgets.dart';
import '../services/auth_service.dart';
import '../services/notification_service.dart';
import '../services/session_scope.dart';

/// Refresh an authenticated visible header without introducing a socket stream.
class NotificationUnreadScope extends StatefulWidget {
  const NotificationUnreadScope({super.key, required this.builder});
  final Widget Function(BuildContext, int) builder;
  @override
  State<NotificationUnreadScope> createState() =>
      _NotificationUnreadScopeState();
}

class _NotificationUnreadScopeState extends State<NotificationUnreadScope>
    with WidgetsBindingObserver {
  Timer? _timer;
  bool _busy = false, _active = true;
  @override
  void initState() {
    super.initState();
    NotificationService.observeSession();
    WidgetsBinding.instance.addObserver(this);
    AuthService.currentUserNotifier.addListener(_refresh);
    WidgetsBinding.instance.addPostFrameCallback((_) => _refresh());
    _timer = Timer.periodic(const Duration(seconds: 30), (_) => _refresh());
  }

  Future<void> _refresh() async {
    if (!mounted ||
        !_active ||
        _busy ||
        !AuthService.isAuthenticated ||
        ModalRoute.of(context)?.isCurrent != true) {
      return;
    }
    final generation = SessionScope.generation;
    _busy = true;
    try {
      final value = await NotificationService.unreadCount();
      if (mounted &&
          generation == SessionScope.generation &&
          AuthService.isAuthenticated) {
        NotificationService.publishUnread(value);
      }
    } catch (_) {
      // Retain the last server count; an outage must not fabricate a count.
    } finally {
      _busy = false;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _active = state == AppLifecycleState.resumed;
    if (_active) _refresh();
  }

  @override
  void dispose() {
    _timer?.cancel();
    AuthService.currentUserNotifier.removeListener(_refresh);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<int>(
    valueListenable: NotificationService.unread,
    builder: (context, count, _) => widget.builder(context, count),
  );
}
