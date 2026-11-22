import 'package:flutter_test/flutter_test.dart';
import 'package:skillsense_ai/services/monitor_attempt.dart';

void main() {
  testWidgets('late callbacks and queued retries lose ownership on leave', (
    tester,
  ) async {
    final attempt = MonitorAttempt();
    final socketGeneration = attempt.epoch;
    int joins = 0, releases = 0;
    attempt.cleanup = () => releases++;
    expect(attempt.retry(() => joins++), isTrue);
    expect(attempt.epoch, isNot(socketGeneration));
    expect(attempt.retryPending, isTrue);
    attempt.cancel();
    await tester.pump(const Duration(seconds: 3));
    expect(joins, 0);
    expect(releases, 1);
  });
  testWidgets('bounded failures and lease renewal have independent budgets', (
    tester,
  ) async {
    final attempt = MonitorAttempt();
    int joins = 0;
    for (int i = 1; i <= 5; i++) {
      expect(attempt.retry(() => joins++), isTrue);
      await tester.pump(Duration(seconds: i * 2));
    }
    expect(joins, 5);
    expect(attempt.retry(() => joins++), isFalse);
    attempt.failures = 0;
    expect(attempt.retry(() => joins++, renewal: true), isTrue);
    await tester.pump(const Duration(milliseconds: 1));
    expect(joins, 6);
    expect(attempt.failures, 0);
  });
}
