/// Centralized string constants for SkillSense AI.
class AppConstants {
  AppConstants._(); // Private constructor to prevent instantiation

  // Role Selection Screen
  static const String roleTitle = "I'm a...";
  static const String roleSubtitle =
      'Choose your role to get\nthe right experience';
  static const String recruiterTitle = 'Recruiter / HR';
  static const String recruiterDescription =
      'Post jobs, screen candidates, run AI interviews';
  static const String jobSeekerTitle = 'Job Seeker';
  static const String jobSeekerDescription =
      'Apply, take AI interviews, get feedback';
  static const String roleHelperText =
      'Your role determines which features you see. You can update this anytime in settings.';
  static const String continueButton = 'Continue';

  // Login Screen
  static const String loginTitle = 'Sign in to your\nAccount';
  static const String loginSubtitle = 'Enter your email and password to log in';
  static const String emailHint = 'Email';
  static const String passwordHint = 'Password';
  static const String rememberMe = 'Remember me';
  static const String forgotPassword = 'Forgot Password ?';
  static const String logIn = 'Log In';
  static const String orDivider = 'Or';
  static const String continueWithGoogle = 'Continue with Google';
  static const String continueWithFacebook = 'Continue with Facebook';
  static const String noAccount = "Don't have an account?";
  static const String signUp = 'Sign Up';

  // Registration Screen (new)
  static const String registerTitle = 'Register';
  static const String registerSubtitle = 'Create an account to continue!';
  static const String firstNameHint = 'Enter First Name';
  static const String lastNameHint = 'Enter Last Name';
  static const String dobHint = 'Date of Birth';
  static const String phoneHint = 'Phone Number';
  static const String passwordHintReg = 'Enter your password';
  static const String registerButtonText = 'Register';
  static const String alreadyAccountPrompt = 'Already have an account? ';
  static const String loginLinkText = 'Log in';

  // Candidate Onboarding Text
  static const String candidateBadge = 'For job seekers';
  static const String candidateTitle1 = 'AI-matched jobs,\njust for you';
  static const String candidateSub1 = 'Our AI reads your resume and ranks every\njob by how well you actually match';
  static const String candidateTitle2 = 'Interview on\nyour own time';
  static const String candidateSub2 = 'Drop your Resume. AI extracts your skills,\nexperience and education in seconds';
  static const String candidateTitle3 = 'AI-matched jobs,\njust for you';
  static const String candidateSub3 = 'A real-time AI voice agent conducts your\ninterview';
  static const String candidateTitle4 = 'Fair, transparent,\nexplainable';
  static const String candidateSub4 = 'Every score is explained in plain English.\nWhat helped you and what to improve.';
  static const String candidateTitle5 = 'Your data\nstays yours';
  static const String candidateSub5 = 'Your data is processed on our own servers.\nNever sent to third-party AI services.';
  static const String candidateCreateAccount = 'Create my account';
  static const String candidateNextButton = 'Next';

  // HR Onboarding Text
  static const String hrBadge = 'For HR teams';
  static const String hrTitle1 = 'AI screens 100%\nof applicants for you';
  static const String hrSub1 = 'Resumes are auto-scored & ranked.\nNo more reading 200 CVs.';
  static const String hrTitle2 = 'Run AI interviews\nNo scheduling hassle';
  static const String hrSub2 = 'T5 AI generates tailored questions. Retell\nconducts the interview. You just review.';
  static const String hrTitle3 = 'Real-time body\nlanguage analysis';
  static const String hrSub3 = 'MediaPipe tracks gaze, YOLOv8 flags\ndistractions (auto during live interviews)';
  static const String hrTitle4 = 'Trusted ranked\nrecommendations';
  static const String hrSub4 = 'XGBoost ranks candidates with clear,\nexplainable insights.';
  static const String hrCreateAccount = 'Create my account';
  static const String hrNextButton = 'Next';
}
