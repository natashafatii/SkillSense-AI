/// Centralized string constants for SkillSense AI.
class AppConstants {
  AppConstants._(); // Private constructor to prevent instantiation

  // Role Selection Screen
  static const String roleTitle = 'Who are you signing in as?';
  static const String roleSubtitle =
      'Your role decides which workspace you get. Change it later in settings.';
  static const String recruiterTitle = "I'm hiring";
  static const String recruiterDescription =
      'Post roles, screen with AI, run voice interviews and get explained scores.';
  static const String jobSeekerTitle = "I'm looking for a job";
  static const String jobSeekerDescription =
      'Apply with one resume, take AI i nterviews, see your own feedback.';
  static const String roleHelperText =
      'One account, both roles — switch anytime in settings.';
  static const String continueAsRecruiter = 'Continue as recruiter';
  static const String continueAsCandidate = 'Continue as candidate';
  static const String roleEyebrow = 'ONE PLATFORM · TWO SIDES';
  static const String selectRoleLabel = 'SELECT YOUR ROLE';

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
  static const String candidateSub1 =
      'Our AI reads your resume and ranks every\njob by how well you actually match';
  static const String candidateTitle2 = 'Interview on\nyour own time';
  static const String candidateSub2 =
      'Drop your Resume. AI extracts your skills,\nexperience and education in seconds';
  static const String candidateTitle3 = 'AI-matched jobs,\njust for you';
  static const String candidateSub3 =
      'A real-time AI voice agent conducts your\ninterview';
  static const String candidateTitle4 = 'Fair, transparent,\nexplainable';
  static const String candidateSub4 =
      'Every score is explained in plain English.\nWhat helped you and what to improve.';
  static const String candidateTitle5 = 'Your data\nstays yours';
  static const String candidateSub5 =
      'Your data is processed on our own servers.\nNever sent to third-party AI services.';
  static const String candidateCreateAccount = 'Create my account';
  static const String candidateNextButton = 'Next';

  // HR Onboarding Text
  static const String hrBadge = 'For HR teams';
  static const String hrTitle1 = 'AI screens 100%\nof applicants for you';
  static const String hrSub1 =
      'Resumes are auto-scored & ranked.\nNo more reading 200 CVs.';
  static const String hrTitle2 = 'Run AI interviews\nNo scheduling hassle';
  static const String hrSub2 =
      'T5 AI generates tailored questions. Retell\nconducts the interview. You just review.';
  static const String hrTitle3 = 'Real-time body\nlanguage analysis';
  static const String hrSub3 =
      'MediaPipe tracks gaze, YOLOv8 flags\ndistractions (auto during live interviews)';
  static const String hrTitle4 = 'Trusted ranked\nrecommendations';
  static const String hrSub4 =
      'XGBoost ranks candidates with clear,\nexplainable insights.';
  static const String hrCreateAccount = 'Create my account';
  static const String hrNextButton = 'Next';

  // Web Role Selection Specific
  static const String webLeftPanelTitle =
      'The same interview,\nseen fairly from both\nsides.';
  static const String webLeftPanelBody =
      'Recruiters see an explained score. Candidates can see the\nsame numbers as coaching. Nothing is hidden from either\nside of the table.';
  static const String webLeftPanelPoint1 =
      'AI voice interviews scored across four dimensions';
  static const String webLeftPanelPoint2 =
      'Plain-language explanations, not black-box numbers';
  static const String webLeftPanelPoint3 =
      'Candidates can receive their own feedback';

  // Signup Role Selection Screen
  static const String signupWebTitle = "I'm a...";
  static const String signupWebSubtitle =
      'Choose your role to get the right experience. You can update this anytime in settings.';
  static const String signupWebHelperText =
      'Your role determines which features you see. You can update this anytime in settings.';
  static const String signupWebLeftBody =
      'Your role decides which workspace you get — recruiters see hiring tools, candidates see applications and feedback. You can switch anytime from settings.';
  static const String signupRecruiterTitle = 'Recruiter / HR';
  static const String signupRecruiterDescription =
      'Post roles, screen candidates, run AI interviews.';
  static const String signupJobSeekerTitle = 'Job Seeker';
  static const String signupJobSeekerDescription =
      'Apply, take AI interviews, get feedback.';

  // HR Register / Workspace Setup Screen
  static const String hrRegisterEyebrow = 'ALMOST THERE';
  static const String hrRegisterLeftTitle = 'Your workspace, in one minute.';
  static const String hrRegisterLeftBody =
      'Create the account, name the company, and post the first role from an empty pipeline that shows you exactly what to do next.';
  static const String hrRegisterPoint1 = 'Work email or Google SSO';
  static const String hrRegisterPoint2 = 'Company profile finished later';
  static const String hrRegisterPoint3 = 'First role guided by an empty-state checklist';

  static const String hrRegisterRightTitle = 'Set up your workspace';
  static const String hrRegisterRightSubtitle =
      'Recruiter workspace · invite your team after setup.';
  static const String hrRegisterFullNameLabel = 'Full name';
  static const String hrRegisterWorkEmailLabel = 'Work email';
  static const String hrRegisterCompanyLabel = 'Company';
  static const String hrRegisterPasswordLabel = 'Password';
  static const String hrRegisterPasswordHint = '8+ characters';
  static const String hrRegisterCtaText = 'Set up my workspace';
  static const String hrRegisterAgreement =
      'By continuing you agree to the Terms and Privacy Policy.';

  // Candidate Register Web
  static const String candidateRegisterEyebrow = 'FOR JOB SEEKERS';
  static const String candidateRegisterLeftBody =
      'Create your account, upload your resume once, and start applying to roles with our AI-scored interviews.';
  static const String candidateRegisterPoint1 = 'Upload once, apply anywhere';
  static const String candidateRegisterPoint2 = 'Semantic match scores on every job';
  static const String candidateRegisterPoint3 = 'Voice interviews with live transcripts';
  
  static const String candidateRegisterRightTitle = 'Create an account';
  static const String candidateRegisterRightSubtitle =
      'Job Seeker workspace · fill in the details below to get started.';
  static const String candidateRegisterCtaText = 'Create Account';
  static const String candidateRegisterAgreement =
      'By continuing you agree to the Terms and Privacy Policy.';

  // Welcome Screen Web (Left Panel)
  static const String welcomeWebEyebrow = 'HIRING, UNDERSTOOD';
  static const String welcomeWebHeadline = 'Interviews that reveal skill, not script.';
  static const String welcomeWebBody =
      'SkillSense scores candidates on how they actually reason and communicate — not on keyword matching against a résumé.';
  static const String welcomeWebPoint1 = 'AI-scored voice interviews across communication, reasoning and role-fit';
  static const String welcomeWebPoint2 = 'Shortlists ranked in minutes, not days of screening';
  static const String welcomeWebPoint3 = 'One dashboard for every open role and applicant';

  // Welcome Screen Web (Right Panel)
  static const String welcomeWebRightTitle = 'Discover the platform';
  static const String welcomeWebRightSubtitle =
      'Create a free account to start screening candidates with AI-scored interviews.';
  static const String welcomeWebCreateAccount = 'Create an account';
  static const String welcomeWebHaveAccount = 'Already have an account?';
  static const String welcomeWebLoginLink = ' Log in';

  // Candidate Onboarding Web (Left Panel)
  static const String candidateWebEyebrow = 'FOR JOB SEEKERS';

  static const String candidateWebTitle1 = 'Jobs ranked against your\nactual resume.';
  static const String candidateWebBody1 =
      'Every open role is scored against what your resume really says — not keyword bingo. You see the number before you spend time applying.';
  static const String candidateWebPoint1a = 'Semantic match scores on every job';
  static const String candidateWebPoint1b = 'Skill-overlap shown as "9 of 10"';
  static const String candidateWebPoint1c = 'Low matches shown honestly, never hidden';

  static const String candidateWebTitle2 = 'We read your resume like a\nperson would.';
  static const String candidateWebBody2 =
      'Upload once. DistilBERT splits it into sections, pulls the skills, and shows you exactly what employers will match against.';
  static const String candidateWebPoint2a = 'Semantic match scores on every job';
  static const String candidateWebPoint2b = 'Parsed skills you can verify and correct';
  static const String candidateWebPoint2c = 'One default resume, swappable per application';

  static const String candidateWebTitle3 = 'A conversation, not a form.';
  static const String candidateWebBody3 =
      'The interview is spoken. An AI interviewer asks, you answer out loud, a transcript builds live. Nothing to type, no trick questions.';
  static const String candidateWebPoint3a = 'Voice interview with a live transcript';
  static const String candidateWebPoint3b = 'Eight questions, about 30 minutes';
  static const String candidateWebPoint3c = 'Rejoin from where you left off if you drop';

  static const String candidateWebTitle4 = 'See how you did — in words\nyou can use.';
  static const String candidateWebBody4 =
      'If the employer shares it, you get the same numbers they saw, rewritten as coaching: what worked, what to fix, how to fix it.';
  static const String candidateWebPoint4a = 'The same scores the employer saw';
  static const String candidateWebPoint4b = 'Plain-language strengths and fixes';
  static const String candidateWebPoint4c = 'A transcript of your own answers';

  static const String candidateWebTitle5 = 'Your data, on a leash.';
  static const String candidateWebBody5 =
      'Interview video is analysed live and never stored. Scores move only with your permission. Deleting your account deletes your data.';
  static const String candidateWebPoint5a = 'Video analysed in the moment, never stored';
  static const String candidateWebPoint5b = 'Scores shared only with your say-so';
  static const String candidateWebPoint5c = 'Full export and delete, self-serve';

  // Web Login Screen
  static const String loginWebEyebrow = 'WELCOME BACK';
  static const String loginWebHeadline = 'Everything is where\nyou left it.';
  static const String loginWebBody =
      'Your pipeline, shortlists, drafted questions and scores are held exactly as you left them — signing in reassembles the workspace, it does not rebuild it.';
  static const String loginWebPoint1 = 'Candidates keep their stage in every pipeline they are in';
  static const String loginWebPoint2 = 'Interviews you scheduled keep running on their own clock';
  static const String loginWebPoint3 = 'A session ends itself after 30 days of silence';
  static const String loginWebRightTitle = 'Sign in';
  static const String loginWebRightSubtitle =
      'One door for recruiters and candidates — your account decides where you land.';
  static const String loginWebKeepMeSignedIn = 'Keep me signed in';
  static const String loginWebForgotPassword = 'Forgot password?';
  static const String loginWebButton = 'Sign In';
  static const String loginWebNewUserPrompt = 'New to SkillSense? ';
  static const String loginWebCreateAccountLink = 'Create an account';

  // Web Login — Error state
  static const String loginWebErrorTitle = 'Email or password is incorrect.';
  static const String loginWebErrorBody =
      'Check both, then try again. Two attempts left before sign-in pauses.';

  // Web Forgot Password screen
  static const String forgotWebEyebrow = 'ACCOUNT RECOVERY';
  static const String forgotWebHeadline = 'A reset link, good\nfor one hour.';
  static const String forgotWebBody =
      'We send one link to the address on the account. It works once, then expires — requesting a new one cancels the last.';
  static const String forgotWebPoint1 = 'Link expires 60 minutes after it is sent';
  static const String forgotWebPoint2 = 'Using it signs out every other device on the account';
  static const String forgotWebPoint3 = 'Interviews already scheduled are untouched';
  static const String forgotWebRightTitle = 'Reset your password';
  static const String forgotWebRightSubtitle =
      'Enter the email on your account and we will send a link to set a new password.';
  static const String forgotWebEmailLabel = 'Email';
  static const String forgotWebEmailHint = 'm.rehman@gmail.com';
  static const String forgotWebButton = 'Send reset link';
  static const String forgotWebBackLink = 'Back to sign in';
  static const String forgotWebRemembered = 'Remembered it? ';

  // Web Check Email screen
  static const String checkEmailWebEyebrow = 'ACCOUNT RECOVERY';
  static const String checkEmailWebHeadline = 'Sent. Now check\nthe inbox.';
  static const String checkEmailWebBody =
      'If the address belongs to an account, the link is already on its way. Nothing else happens on this screen.';
  static const String checkEmailWebPoint1 = 'Sender: no-reply@skillsense.ai';
  static const String checkEmailWebPoint2 = 'Delivery is usually under a minute';
  static const String checkEmailWebPoint3 = 'Check spam before requesting another';
  static const String checkEmailWebBannerLine1 = 'Reset link sent.';
  static const String checkEmailWebRightTitle = 'Check your email';
  static const String checkEmailWebRightSubtitle =
      'Nothing in the inbox after a minute? Look in spam, then send another link.';
  static const String checkEmailWebResendPrefix = 'Resend link in ';
  static const String checkEmailWebBackButton = 'Back to sign in';
  static const String checkEmailWebWrongAddress = 'Wrong address? ';
  static const String checkEmailWebUseDifferent = 'Use a different email';

  // Web Set New Password screen
  static const String setPasswordWebEyebrow = 'ACCOUNT RECOVERY';
  static const String setPasswordWebHeadline = 'Last step. Then\nstraight in.';
  static const String setPasswordWebBody =
      'Setting a password signs out every other device and takes you to your workspace — no second sign-in.';
  static const String setPasswordWebPoint2 = 'This link expires in 60 minutes';
  static const String setPasswordWebPoint3 = 'Other devices are signed out immediately';
  static const String setPasswordWebRightTitle = 'Set a new password';
  static const String setPasswordWebRightSubtitle =
      'Pick something you have not used on this account before.';
  static const String setPasswordWebNewLabel = 'New password';
  static const String setPasswordWebConfirmLabel = 'Confirm password';
  static const String setPasswordWebButton = 'Set password and sign in';
  static const String setPasswordWebIgnore =
      'Did not request this? Ignore the email — nothing changed';
  static const String setPasswordWebRule8Chars = '8 characters or more';
  static const String setPasswordWebRuleNumber = 'One number';
  static const String setPasswordWebRuleSymbol = 'One symbol (recommended)';
  static const String setPasswordWebMatch = 'Both entries match.';

  // Command Deck Dashboard Constants
  static const String deckTitle = 'Morning, Abdul.';
  static const String deckSubtitle = "One interview live now, two more today. Ayesha Khalid's score is ready.";
  static const String deckHeroEyebrow = 'WED 13 MAY · 09:12 PKT · COMMAND DECK';
  static const String deckLiveCandidate = 'Bilal Mahmood — live now';
  static const String deckLiveDetails = 'Q4 OF 8 · 11:30 START · SENIOR DJANGO DEV';
  static const String deckOpenMonitor = 'Open monitor';
  static const String deckAvgMatch = 'AVG MATCH';
  static const String deckOpenRoles = 'OPEN ROLES';
  static const String deckApplicants = 'APPLICANTS';
  static const String deckToday = 'TODAY';
  static const String deckThisWeek = 'THIS WEEK';
  static const String deckTopApplicants = 'Top applicants';
  static const String deckSbertRanked = 'SBERT RANKED';
  static const String deckAllLink = 'All 127 >';
  static const String deckPipelineFlow = 'Pipeline flow';
  static const String deckInterviewsToday = 'Interviews today';
  static const String deckOpenRolesSection = 'Open roles';
  static const String deckManage = 'Manage >';
}
