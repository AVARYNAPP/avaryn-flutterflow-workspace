enum Phase5AccountRoute {
  welcome,
  verifyEmail,
  onboarding,
  invitation,
  stableHandoff,
  today,
}

Phase5AccountRoute phase5ResolveAccountRoute({
  required bool hasSession,
  required bool emailProvider,
  required bool emailConfirmed,
  required bool onboardingCompleted,
  required bool hasPendingInvitation,
  required bool hasSelectedStable,
}) {
  if (!hasSession) return Phase5AccountRoute.welcome;
  if (emailProvider && !emailConfirmed) {
    return Phase5AccountRoute.verifyEmail;
  }
  if (!onboardingCompleted) return Phase5AccountRoute.onboarding;
  if (hasPendingInvitation) return Phase5AccountRoute.invitation;
  if (!hasSelectedStable) return Phase5AccountRoute.stableHandoff;
  return Phase5AccountRoute.today;
}

String phase5AccountRouteName(Phase5AccountRoute route) {
  return switch (route) {
    Phase5AccountRoute.welcome => 'AuthWelcomePage',
    Phase5AccountRoute.verifyEmail => 'AuthVerifyEmailPage',
    Phase5AccountRoute.onboarding => 'OnboardingPage',
    Phase5AccountRoute.invitation => 'StableInvitationPage',
    Phase5AccountRoute.stableHandoff => 'StableOnboardingHandoffPage',
    Phase5AccountRoute.today => 'TodayDashboardPage',
  };
}

bool phase5ImageSignatureMatches(List<int> bytes, String contentType) {
  bool startsWith(List<int> signature) {
    if (bytes.length < signature.length) return false;
    for (var index = 0; index < signature.length; index += 1) {
      if (bytes[index] != signature[index]) return false;
    }
    return true;
  }

  return switch (contentType) {
    'image/jpeg' => startsWith(const [0xFF, 0xD8, 0xFF]),
    'image/png' => startsWith(const [
      0x89,
      0x50,
      0x4E,
      0x47,
      0x0D,
      0x0A,
      0x1A,
      0x0A,
    ]),
    'image/webp' =>
      bytes.length >= 12 &&
          startsWith(const [0x52, 0x49, 0x46, 0x46]) &&
          bytes[8] == 0x57 &&
          bytes[9] == 0x45 &&
          bytes[10] == 0x42 &&
          bytes[11] == 0x50,
    _ => false,
  };
}
