import 'package:flutter_test/flutter_test.dart';
import 'package:skillsense_ai/services/resume_manager.dart';

void main() {
  test('ResumeManager returns empty list for new user without hardcoded seed resumes', () {
    ResumeManager.clearCache();
    final resumes = ResumeManager.getResumes();
    expect(resumes, isEmpty);
    expect(resumes.any((r) => r['filename'].toString().contains('Abdul_Rehman')), isFalse);
  });

  test('getActiveResume returns empty map when no resume uploaded', () {
    ResumeManager.clearCache();
    final active = ResumeManager.getActiveResume();
    expect(active, isEmpty);
  });

  test('addResume stores resume for current session and sets it active', () {
    ResumeManager.clearCache();
    ResumeManager.addResume('my_custom_resume.pdf', '2.4 MB');

    final resumes = ResumeManager.getResumes();
    expect(resumes.length, equals(1));
    expect(resumes.first['filename'], equals('my_custom_resume.pdf'));
    expect(resumes.first['active'], isTrue);

    final active = ResumeManager.getActiveResume();
    expect(active['filename'], equals('my_custom_resume.pdf'));
  });

  test('clearCache resets in-memory resume state on logout', () {
    ResumeManager.addResume('temporary_resume.pdf', '1.0 MB');
    expect(ResumeManager.getResumes(), isNotEmpty);

    ResumeManager.clearCache();
    // After clearing cache, loading guest session should yield empty list
    final resumes = ResumeManager.getResumes();
    expect(resumes, isEmpty);
  });
}
