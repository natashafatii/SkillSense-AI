/// Invalidates work started by an earlier login or logout transaction.
class SessionScope {
  static int generation = 0;
  static void invalidate() => generation++;
}
