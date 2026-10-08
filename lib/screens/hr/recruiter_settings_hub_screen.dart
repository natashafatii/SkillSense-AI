import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class RecruiterSettingsHubScreen extends StatelessWidget {
  const RecruiterSettingsHubScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFFF8FAFC),
    appBar: AppBar(title: const Text('Theme & settings')),
    body: ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text(
          'Workspace settings',
          style: GoogleFonts.spaceGrotesk(
            fontSize: 21,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF0F172A),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Manage your recruiter workspace.',
          style: GoogleFonts.inter(
            fontSize: 12,
            color: const Color(0xFF64748B),
          ),
        ),
        const SizedBox(height: 24),
        Card(
          child: ListTile(
            leading: const Icon(Icons.tune_rounded, color: Color(0xFF2563EB)),
            title: const Text('Scoring model'),
            subtitle: const Text('Review score weights and decision bands'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () =>
                Navigator.of(context).pushNamed('/recruiter/scoring-model'),
          ),
        ),
        Card(
          child: ListTile(
            leading: const Icon(
              Icons.business_outlined,
              color: Color(0xFF2563EB),
            ),
            title: const Text('Company & team'),
            subtitle: const Text('Manage organisation and team details'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () =>
                Navigator.of(context).pushNamed('/recruiter/company-team'),
          ),
        ),
      ],
    ),
  );
}
