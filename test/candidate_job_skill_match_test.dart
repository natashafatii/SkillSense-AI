import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skillsense_ai/models/job.dart';
import 'package:skillsense_ai/models/job_skill_match.dart';
import 'package:skillsense_ai/models/resume_detail.dart';
import 'package:skillsense_ai/screens/candidate/candidate_job_detail_screen.dart';

void main() {
  test('matches skill variants and preserves job skill labels', () {
    final match = JobSkillMatch.cached(
      jobId: 'job-1',
      resumeId: 'resume-1',
      jobSkills: [' SQL ', 'PowerBI', 'sql', ' Excel ', 'Docker'],
      resumeSkills: ['sql', ' power BI ', 'EXCEL'],
    );
    expect(match.matched, ['SQL', 'PowerBI', 'Excel']);
    expect(match.missing, ['Docker']);
    expect(
      identical(
        match,
        JobSkillMatch.cached(
          jobId: 'job-1',
          resumeId: 'resume-1',
          jobSkills: [' SQL ', 'PowerBI', 'sql', ' Excel ', 'Docker'],
          resumeSkills: ['sql', ' power BI ', 'EXCEL'],
        ),
      ),
      isTrue,
    );
    final hyphenated = JobSkillMatch.cached(
      jobId: 'job-1',
      resumeId: 'resume-2',
      jobSkills: ['PowerBI'],
      resumeSkills: ['Power-BI'],
    );
    expect(hyphenated.matched, ['PowerBI']);
    final underscored = JobSkillMatch.cached(
      jobId: 'job-1',
      resumeId: 'resume-3',
      jobSkills: ['PowerBI'],
      resumeSkills: ['Power_BI'],
    );
    expect(underscored.matched, ['PowerBI']);
  });

  testWidgets('shows chips before applying from the parsed resume', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final now = DateTime.utc(2026);
    final job = Job(
      id: 'job-1',
      recruiter: 'recruiter',
      recruiterCompany: 'Company',
      title: 'Analyst',
      description: 'Role',
      requirements: '',
      skillsRequired: const [],
      location: 'Remote',
      jobType: JobType.remote,
      experienceLevel: ExperienceLevel.mid,
      status: JobStatus.active,
      createdAt: now,
      updatedAt: now,
      jobSkills: const [],
    );
    const resume = ResumeDetail(
      id: 'resume-1',
      status: ResumeStatus.parsed,
      skills: [' sql ', 'Power BI', 'excel'],
    );
    var skillLoads = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: CandidateJobDetailScreen(
          jobId: job.id,
          loadJob: (_) async => job,
          loadActiveResume: () async => resume,
          loadJobSkills: (_) async {
            skillLoads++;
            return const [
              JobSkill(id: 1, job: 'job-1', skillName: 'SQL', isRequired: true),
              JobSkill(
                id: 2,
                job: 'job-1',
                skillName: 'PowerBI',
                isRequired: true,
              ),
              JobSkill(
                id: 3,
                job: 'job-1',
                skillName: 'Excel',
                isRequired: true,
              ),
              JobSkill(
                id: 4,
                job: 'job-1',
                skillName: 'Docker',
                isRequired: true,
              ),
            ];
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('MATCHED · 3'), findsOneWidget);
    expect(find.text('MISSING · 1'), findsOneWidget);
    expect(find.text('SQL ✓'), findsOneWidget);
    expect(find.text('PowerBI ✓'), findsOneWidget);
    expect(find.text('Excel ✓'), findsOneWidget);
    expect(find.text('Docker'), findsOneWidget);
    expect(skillLoads, 1);
    expect(
      find.text('Apply first to see which skills match this role.'),
      findsNothing,
    );
  });

  testWidgets('pending parsing retries and then shows the failure link', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final now = DateTime.utc(2026);
    final job = Job(
      id: 'job-2',
      recruiter: 'recruiter',
      recruiterCompany: 'Company',
      title: 'Analyst',
      description: 'Role',
      requirements: '',
      skillsRequired: const [],
      location: 'Remote',
      jobType: JobType.remote,
      experienceLevel: ExperienceLevel.mid,
      status: JobStatus.active,
      createdAt: now,
      updatedAt: now,
      jobSkills: const [],
    );
    var polls = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: CandidateJobDetailScreen(
          jobId: job.id,
          loadJob: (_) async => job,
          loadActiveResume: () async =>
              const ResumeDetail(id: 'resume-2', status: ResumeStatus.pending),
          loadJobSkills: (_) async => const [],
          pollResume: (_) async {
            polls++;
            return const ResumeDetail(
              id: 'resume-2',
              status: ResumeStatus.failed,
            );
          },
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    expect(find.text('Parsing your resume…'), findsOneWidget);
    expect(polls, 0);
    await tester.pump(const Duration(seconds: 2));
    await tester.pump();
    expect(polls, 1);
    expect(find.text('Manage resumes'), findsOneWidget);
  });

  testWidgets('apply modal shows extracted resume data without job matching', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final now = DateTime.utc(2026);
    final job = Job(
      id: 'job-modal',
      recruiter: 'recruiter',
      recruiterCompany: 'Company',
      title: 'Analyst',
      description: 'Role',
      requirements: '',
      skillsRequired: const [],
      location: 'Remote',
      jobType: JobType.remote,
      experienceLevel: ExperienceLevel.mid,
      status: JobStatus.active,
      createdAt: now,
      updatedAt: now,
      jobSkills: const [],
    );
    const resume = ResumeDetail(
      id: 'resume-modal',
      status: ResumeStatus.parsed,
      skills: ['SQL', 'Power BI'],
      experience: [
        {'title': 'Analyst', 'company': 'Acme', 'duration': '2025'},
      ],
      education: [
        {'degree': 'BSc', 'institution': 'University', 'year': '2024'},
      ],
      certifications: ['Data Certificate'],
      matchedSkills: ['SQL'],
      missingSkills: ['Docker'],
      matchScore: 41,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: CandidateJobDetailScreen(
          jobId: job.id,
          loadJob: (_) async => job,
          loadActiveResume: () async => resume,
          loadJobSkills: (_) async => const [
            JobSkill(
              id: 1,
              job: 'job-modal',
              skillName: 'SQL',
              isRequired: true,
            ),
            JobSkill(
              id: 2,
              job: 'job-modal',
              skillName: 'Docker',
              isRequired: true,
            ),
          ],
          loadApplyResumes: () async => [
            {'id': 'resume-modal', 'filename': 'resume.pdf', 'active': true},
          ],
          loadApplyResumeDetail: (_) async => resume,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('MATCHED · 1'), findsOneWidget);
    expect(find.text('MISSING · 1'), findsOneWidget);
    await tester.tap(find.text('Apply with default resume'));
    await tester.pumpAndSettle();
    final dialog = find.byType(Dialog);
    expect(dialog, findsOneWidget);
    Finder inDialog(Finder child) =>
        find.descendant(of: dialog, matching: child);
    expect(inDialog(find.text('SKILLS · 2')), findsOneWidget);
    expect(inDialog(find.text('EXPERIENCE · 1')), findsOneWidget);
    expect(inDialog(find.text('EDUCATION · 1')), findsOneWidget);
    expect(inDialog(find.text('CERTIFICATIONS · 1')), findsOneWidget);
    expect(inDialog(find.text('Power BI')), findsOneWidget);
    expect(inDialog(find.text('Data Certificate')), findsOneWidget);
    expect(inDialog(find.textContaining('MATCHED SKILLS')), findsNothing);
    expect(inDialog(find.textContaining('MISSING SKILLS')), findsNothing);
    expect(inDialog(find.textContaining('41% match')), findsNothing);
    expect(inDialog(find.text('COVER NOTE · OPTIONAL')), findsOneWidget);
    expect(inDialog(find.text('Submit application')), findsOneWidget);
    expect(inDialog(find.text('Cancel')), findsOneWidget);
    expect(
      inDialog(
        find.text(
          'Applying starts automated screening immediately — no surprise steps after this.',
        ),
      ),
      findsOneWidget,
    );
  });
}
