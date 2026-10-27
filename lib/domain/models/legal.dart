/// Community rules and the privacy notice, bundled in the app.
///
/// The text is a draft for owner review (see docs/release/11-known-issues.md).
/// The hosted privacy policy must say the same thing as [privacyNotice].
library;

/// Version of the community rules a user must accept before joining groups
/// or posting. Bump it when the rules change materially, together with
/// `minRulesVersion()` in `firebase/firestore.rules`: the server accepts only
/// that exact version, so deploy the rules and the app update together.
const currentRulesVersion = 1;

/// Minimum age to create an account. Sign-up asks the user to confirm it, and
/// the privacy notice and `firebase/hosting/privacy.html` state it.
const minimumAge = 18;

class LegalSection {
  const LegalSection(this.heading, this.body);

  final String heading;
  final String body;
}

class LegalDocument {
  const LegalDocument({
    required this.title,
    required this.lastUpdated,
    required this.sections,
  });

  final String title;

  /// Shown under the title, as an ISO date.
  final String lastUpdated;
  final List<LegalSection> sections;
}

const communityRules = LegalDocument(
  title: 'Community rules',
  lastUpdated: '2026-10-26',
  sections: [
    LegalSection(
      'Why these rules exist',
      'Deutschhelfer groups and messages are for students helping each other '
          'prepare for study in Germany. You must accept these rules before '
          'you join a group or send a message. Breaking them can lead to '
          'removed messages or a suspended account.',
    ),
    LegalSection(
      'Be respectful',
      'No harassment, bullying, threats, hate speech or discrimination '
          'against anyone, including because of religion, ethnicity, gender, '
          'sexuality, disability or nationality.',
    ),
    LegalSection(
      'No scams, spam or advertising',
      'Do not advertise paid services, agents or consultants. Do not promise '
          'guaranteed admissions or visas. Do not ask for money, and never '
          'send money to someone you met in the app.',
    ),
    LegalSection(
      'No fraud or fake documents',
      'Do not share, sell or ask for forged certificates, transcripts, bank '
          'statements or other documents, or help anyone deceive a '
          'university, embassy or authority.',
    ),
    LegalSection(
      'Protect privacy',
      'Do not post anyone\'s phone number, address, passport or CNIC number, '
          'or private photos. Do not post your own identity documents.',
    ),
    LegalSection(
      'No harmful or illegal content',
      'No sexual content, graphic violence, content that encourages self-harm '
          'or illegal activity, or impersonation of other people or '
          'organisations.',
    ),
    LegalSection(
      'Links',
      'Links in groups are hidden until a moderator approves them. Links in '
          'private messages cannot be opened from the app. Be careful with '
          'links from people you do not know.',
    ),
    LegalSection(
      'Not official advice',
      'Members share their own experience. Always confirm requirements on '
          'official websites, such as those of your university, DAAD and the '
          'German missions in Pakistan.',
    ),
    LegalSection(
      'Reporting and blocking',
      'Long-press a message, or tap a member\'s name, to report or block '
          'them. Blocked people cannot message you, and their group messages '
          'are hidden from you. Moderators review reports and may remove '
          'messages or suspend accounts. Every moderation action is logged.',
    ),
  ],
);

const privacyNotice = LegalDocument(
  title: 'Privacy notice',
  lastUpdated: '2026-10-27',
  sections: [
    LegalSection(
      'What we collect',
      'Your email address and password, to create and secure your account. '
          'Google stores the password as a hash; we never see it.\n'
          'Your display name, which other members can see.\n'
          'What you post: group messages, private messages, and reports you '
          'file.\n'
          'Group memberships, people you block, and when you accepted these '
          'rules.\n'
          'If you turn on notifications: a push token for this device.\n'
          'If you subscribe: the purchase record from Google Play.',
    ),
    LegalSection(
      'What we do not collect',
      'No location, contacts, photos or files. No advertising, analytics or '
          'crash-reporting tools. We do not sell your data.',
    ),
    LegalSection(
      'Why we use it',
      'To run your account, show your messages to the people you send them '
          'to, keep the community safe through reports and moderation, send '
          'the notifications you turned on, and unlock purchased content.',
    ),
    LegalSection(
      'Who processes it',
      'The app runs on Google Firebase (authentication, database, server '
          'functions and push notifications). Google processes the data on '
          'our behalf, together with technical data such as IP addresses and '
          'device integrity checks that protect the service from abuse.',
    ),
    LegalSection(
      'Who can see what',
      'Your email address is visible only to you. Group members see your '
          'display name and group messages. Private messages are visible only '
          'to you and the other person; moderators cannot read them. '
          'Moderators see reported content.',
    ),
    LegalSection(
      'Security',
      'Data is encrypted in transit. Access is limited by server-side '
          'security rules, and moderator actions are logged.',
    ),
    LegalSection(
      'How long we keep it',
      'While your account exists. When you delete it, your name is replaced '
          'with "Deleted user" at once, you leave every group, your sign-in '
          'is switched off, and your blocks and notification tokens are '
          'removed. Your sign-in, profile, reports you filed and subscription '
          'records are erased after 90 days. Messages you sent stay visible in the group or conversation '
          'under "Deleted user", so the conversation still makes sense. '
          'Reports other people filed about your messages are kept for '
          'community safety. Moderation logs keep a pseudonymous account ID; '
          'their free-text notes are removed after 90 days.',
    ),
    LegalSection(
      'Your choices',
      'You can change your display name, turn notifications off, block '
          'people, withdraw your group messages, and delete your account in '
          'Profile. You can also email us to ask for a copy of your data. If '
          'you no longer have the app, use the account deletion page or '
          'contact us.',
    ),
    LegalSection(
      'Age',
      'You must be $minimumAge or older to create an account, and sign-up '
          'asks you to confirm this. Deutschhelfer is not directed at anyone '
          'younger, and we do not knowingly keep data about them. If you '
          'believe a person under $minimumAge has an account, contact us and '
          'we will delete it.',
    ),
  ],
);
