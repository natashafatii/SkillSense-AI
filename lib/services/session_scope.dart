import 'package:flutter/foundation.dart';

/// Invalidates work started by an earlier login or logout transaction.
class SessionScope {
  static int generation = 0;
  static final _SessionInvalidations _invalidations = _SessionInvalidations();
  static Listenable get invalidations => _invalidations;
  static void invalidate() {
    generation++;
    _invalidations.invalidate();
  }
}

class _SessionInvalidations extends ChangeNotifier {
  void invalidate() => notifyListeners();
}
