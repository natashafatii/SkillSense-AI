import 'package:flutter/material.dart';

class InterviewMediaRouteObserver extends RouteObserver<ModalRoute<dynamic>> {
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (route is! PopupRoute) super.didPush(route, previousRoute);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (route is! PopupRoute) super.didPop(route, previousRoute);
  }
}

final interviewMediaRouteObserver = InterviewMediaRouteObserver();
