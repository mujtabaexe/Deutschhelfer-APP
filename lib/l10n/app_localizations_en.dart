// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Deutschhelfer';

  @override
  String get brandMarkLabel => 'Deutschhelfer logo';

  @override
  String get welcomeHeadline => 'Your path to studying in Germany';

  @override
  String get welcomeBody =>
      'Step-by-step guidance on admissions, applications and visas, with a community of students on the same journey.';

  @override
  String get welcomeFeatureGuidanceTitle => 'Admissions and visa guidance';

  @override
  String get welcomeFeatureGuidanceBody =>
      'Clear steps from choosing a university to your visa appointment.';

  @override
  String get welcomeFeatureCommunityTitle => 'Student community';

  @override
  String get welcomeFeatureCommunityBody =>
      'Topic groups where students help each other, with moderators keeping them safe.';

  @override
  String get welcomeFeatureIeltsTitle => 'IELTS preparation';

  @override
  String get welcomeFeatureIeltsBody =>
      'Tips and practice material to help you reach your target band.';

  @override
  String get actionCreateAccount => 'Create account';

  @override
  String get actionSignIn => 'Sign in';

  @override
  String get actionSendResetLink => 'Send reset link';

  @override
  String get actionTryAgain => 'Try again';

  @override
  String get actionBackToSignIn => 'Back to sign in';

  @override
  String get actionGoToStart => 'Go to start';

  @override
  String get signInTitle => 'Welcome back';

  @override
  String get signInSubtitle => 'Sign in to continue your preparation.';

  @override
  String get forgotPasswordLink => 'Forgot password?';

  @override
  String get noAccountPrompt => 'New to Deutschhelfer?';

  @override
  String get createAccountTitle => 'Create your account';

  @override
  String get createAccountSubtitle =>
      'You will confirm your email before you can post in groups or send messages.';

  @override
  String get haveAccountPrompt => 'Already have an account?';

  @override
  String get forgotPasswordTitle => 'Reset your password';

  @override
  String get forgotPasswordBody =>
      'Enter the email you signed up with. If it matches an account, we will send a link to reset your password.';

  @override
  String get resetEmailSentTitle => 'Check your email';

  @override
  String resetEmailSentBody(String email) {
    return 'If an account exists for $email, a reset link is on its way. It can take a few minutes to arrive.';
  }

  @override
  String get fieldDisplayName => 'Display name';

  @override
  String get fieldDisplayNameHelper =>
      'Other students see this name in groups and messages.';

  @override
  String get fieldEmail => 'Email';

  @override
  String get fieldPassword => 'Password';

  @override
  String fieldNewPasswordHelper(int min) {
    return 'At least $min characters, including a letter and a number.';
  }

  @override
  String get fieldConfirmPassword => 'Confirm password';

  @override
  String get showPassword => 'Show password';

  @override
  String get hidePassword => 'Hide password';

  @override
  String get errorRequired => 'This field is required.';

  @override
  String get errorEmailInvalid =>
      'Enter a valid email address, like name@example.com.';

  @override
  String get errorEmailTooLong => 'This email address is too long.';

  @override
  String errorPasswordTooShort(int min) {
    return 'Use at least $min characters.';
  }

  @override
  String errorPasswordTooLong(int max) {
    return 'Use at most $max characters.';
  }

  @override
  String get errorPasswordNeedsLetterAndDigit =>
      'Include at least one letter and one number.';

  @override
  String get errorPasswordsDoNotMatch => 'The passwords do not match.';

  @override
  String errorDisplayNameTooShort(int min) {
    return 'Use at least $min characters.';
  }

  @override
  String errorDisplayNameTooLong(int max) {
    return 'Use at most $max characters.';
  }

  @override
  String get errorDisplayNameInvalidCharacters =>
      'Remove special characters such as < and >.';

  @override
  String get errorDisplayNameContainsLink =>
      'Display names cannot contain links or web addresses.';

  @override
  String errorGroupNameTooShort(int min) {
    return 'Use at least $min characters.';
  }

  @override
  String errorGroupNameTooLong(int max) {
    return 'Use at most $max characters.';
  }

  @override
  String errorGroupDescriptionTooLong(int max) {
    return 'Use at most $max characters.';
  }

  @override
  String get errorTextInvalidCharacters =>
      'Remove special characters such as < and >.';

  @override
  String get errorGroupNameContainsLink =>
      'Group names cannot contain links or web addresses.';

  @override
  String get authNotConfigured =>
      'Account services are not connected in this build yet, so you cannot sign in.';

  @override
  String get authInvalidCredentials =>
      'That email and password do not match an account.';

  @override
  String get authEmailAlreadyInUse =>
      'This email cannot be used to create an account. Try signing in or resetting your password.';

  @override
  String get authWeakPassword => 'Choose a stronger password.';

  @override
  String get authUserDisabled =>
      'This account is disabled. Contact support if you think this is a mistake.';

  @override
  String get authTooManyRequests =>
      'Too many attempts. Wait a few minutes, then try again.';

  @override
  String get authNetwork =>
      'You appear to be offline. Check your connection and try again.';

  @override
  String get authUnknown => 'Something went wrong. Please try again.';

  @override
  String get authRequiresRecentLogin =>
      'For your security, sign in again before doing this.';

  @override
  String get verifyEmailTitle => 'Confirm your email';

  @override
  String verifyEmailBody(String email) {
    return 'We sent a confirmation link to $email. Open it on this phone or any device, then come back here.';
  }

  @override
  String get verifyEmailWhy =>
      'Confirming your email helps keep groups free of spam. Until then you cannot post or send messages.';

  @override
  String get verifyEmailCheck => 'I have confirmed my email';

  @override
  String get verifyEmailResend => 'Send the link again';

  @override
  String verifyEmailResendIn(int seconds) {
    return 'Send again in $seconds s';
  }

  @override
  String get verifyEmailSent =>
      'A new link is on its way. Check your spam folder too.';

  @override
  String get verifyEmailStillPending =>
      'Your email is not confirmed yet. Open the link in the email, then try again.';

  @override
  String get actionSignOut => 'Sign out';

  @override
  String get actionCancel => 'Cancel';

  @override
  String get actionSave => 'Save';

  @override
  String get restrictedSuspendedTitle => 'Your account is suspended';

  @override
  String get restrictedSuspendedBody =>
      'A moderator suspended this account after reports of a rule violation. You cannot post or send messages while it is suspended.';

  @override
  String get restrictedDeletedTitle => 'This account was deleted';

  @override
  String get restrictedDeletedBody =>
      'The account is scheduled for removal and can no longer be used.';

  @override
  String get restrictedContact =>
      'If you think this is a mistake, contact the Deutschhelfer team from the email address on your account.';

  @override
  String get navGuide => 'Guide';

  @override
  String get navGroups => 'Groups';

  @override
  String get navMessages => 'Messages';

  @override
  String get navProfile => 'Profile';

  @override
  String get profileTitle => 'Profile';

  @override
  String get profileEditName => 'Edit display name';

  @override
  String get profileEmailLabel => 'Email';

  @override
  String get profileEmailPrivate => 'Only you can see your email.';

  @override
  String get profileRoleOwner => 'Owner';

  @override
  String get profileRoleStudentAdmin => 'Student admin';

  @override
  String get profilePremium => 'Premium';

  @override
  String get profileNameSaved => 'Display name updated.';

  @override
  String get profileSaveFailed =>
      'Could not save. Check your connection and try again.';

  @override
  String get profileSignOutConfirmTitle => 'Sign out?';

  @override
  String get profileSignOutConfirmBody =>
      'You will need your email and password to sign in again.';

  @override
  String get profileSectionAccount => 'Account';

  @override
  String get profileSectionCommunity => 'Community';

  @override
  String get profileModeration => 'Moderation';

  @override
  String get profileModerationHint => 'Review pending links and reports';

  @override
  String get profileNotifications => 'Message notifications';

  @override
  String get profileNotificationsHint =>
      'Alerts show who wrote to you, never the message itself.';

  @override
  String get profileNotificationsDenied =>
      'Notifications are blocked. Allow them for Deutschhelfer in Android settings.';

  @override
  String get profileNotificationsFailed =>
      'Notification settings could not be changed. Try again.';

  @override
  String get profileDeleteAccount => 'Delete account';

  @override
  String get profileDeleteTitle => 'Delete your account?';

  @override
  String get profileDeleteBody =>
      'You leave all groups right away, and your name is replaced with \"Deleted user\" everywhere. Remaining data is removed after 90 days. This cannot be undone.';

  @override
  String get profileDeleteConfirmLabel => 'Type DELETE to confirm';

  @override
  String get profileDeleteFailed =>
      'Could not delete your account. Check your connection and try again.';

  @override
  String get profileDeletePasswordLabel => 'Your password';

  @override
  String get profileDeleteWrongPassword =>
      'That password is not correct, so your account was not deleted.';

  @override
  String get groupMakeModerator => 'Make moderator';

  @override
  String get groupRemoveModerator => 'Remove moderator role';

  @override
  String get groupRoleUpdated =>
      'Role updated. The change applies after they next sign in.';

  @override
  String get profileAbout => 'About Deutschhelfer';

  @override
  String get profileAboutBody =>
      'Deutschhelfer is a student-run guide. It is not affiliated with the German government, DAAD, any embassy or any university. Always confirm requirements on official websites.';

  @override
  String get guideTitle => 'Guide';

  @override
  String get guideSearchLabel => 'Search the guide';

  @override
  String get guideSearchClear => 'Clear search';

  @override
  String get guideAllCategories => 'All';

  @override
  String get guideNoResultsTitle => 'No matching articles';

  @override
  String get guideNoResultsBody =>
      'Try fewer or different words, or choose another category.';

  @override
  String get guidePremiumBadge => 'Premium';

  @override
  String guideUpdated(DateTime date) {
    final intl.DateFormat dateDateFormat = intl.DateFormat.yMMMd(localeName);
    final String dateString = dateDateFormat.format(date);

    return 'Updated $dateString';
  }

  @override
  String get guideSources => 'Official sources';

  @override
  String guideOpenSource(String label) {
    return 'Open $label in your browser';
  }

  @override
  String get guideOpenFailed => 'Could not open the link.';

  @override
  String get guideDisclaimer =>
      'This guide is general information, not legal or immigration advice. Requirements change, so always confirm them on the official websites above.';

  @override
  String get guideLoadFailed => 'The guide could not be loaded.';

  @override
  String get guideArticleMissing => 'This article is no longer available.';

  @override
  String get premiumLockedTitle => 'Premium article';

  @override
  String get premiumLockedBody =>
      'This article is part of Premium. Premium plans are not available yet. They will appear here when they launch.';

  @override
  String get premiumUnavailable =>
      'Premium content could not be loaded. Check your connection and try again.';

  @override
  String get premiumNotFound =>
      'This premium article has not been published yet.';

  @override
  String get groupsTitle => 'Groups';

  @override
  String get groupsYours => 'Your groups';

  @override
  String get groupsDiscover => 'Discover groups';

  @override
  String get groupsEmptyTitle => 'No groups yet';

  @override
  String get groupsEmptyBody =>
      'Groups appear here when the Deutschhelfer team opens them.';

  @override
  String get groupsCreate => 'New group';

  @override
  String get groupCreateTitle => 'New group';

  @override
  String get groupCreateIntro =>
      'Groups are open to every verified student. Members can join, chat and report problems. Moderators you appoint review links.';

  @override
  String get groupCreateName => 'Group name';

  @override
  String get groupCreateDescription => 'Description (optional)';

  @override
  String get groupCreateCategory => 'Category';

  @override
  String get groupCreateSubmit => 'Create group';

  @override
  String get groupCreateFailed =>
      'The group could not be created. Check your connection and try again.';

  @override
  String get groupCreated => 'Group created.';

  @override
  String groupsMemberCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count members',
      one: '1 member',
    );
    return '$_temp0';
  }

  @override
  String get groupsLoadFailed => 'Groups could not be loaded.';

  @override
  String get groupJoin => 'Join group';

  @override
  String get groupJoined => 'You joined the group.';

  @override
  String get groupLeave => 'Leave group';

  @override
  String get groupLeaveConfirmTitle => 'Leave this group?';

  @override
  String get groupLeaveConfirmBody =>
      'You will stop seeing its messages. You can join again later.';

  @override
  String get groupFull => 'This group is full.';

  @override
  String get groupOpenChat => 'Open chat';

  @override
  String get groupMembers => 'Members';

  @override
  String get groupMembersPrivate => 'Join the group to see who else is in it.';

  @override
  String get groupModeratorBadge => 'Moderator';

  @override
  String get groupYouBadge => 'You';

  @override
  String get groupInfo => 'Group info';

  @override
  String get groupMissing => 'This group is no longer available.';

  @override
  String get categoryAdmissions => 'Admissions';

  @override
  String get categoryVisa => 'Visa';

  @override
  String get categoryIelts => 'IELTS';

  @override
  String get categoryLiving => 'Living in Germany';

  @override
  String get categoryGeneral => 'General';

  @override
  String get chatComposerHint => 'Write a message';

  @override
  String get chatSend => 'Send message';

  @override
  String get chatLinkNotice =>
      'Messages with links are checked by a moderator before others see them.';

  @override
  String get chatPendingBadge => 'Waiting for moderator approval';

  @override
  String get chatSending => 'Sending…';

  @override
  String get chatEmptyTitle => 'No messages yet';

  @override
  String get chatEmptyBody => 'Say hello and introduce yourself.';

  @override
  String get chatStart => 'This is the start of the conversation.';

  @override
  String get chatLoadFailed => 'Messages could not be loaded.';

  @override
  String get chatSendFailed => 'Could not send. Wait a moment and try again.';

  @override
  String chatTooLong(int max) {
    return 'Messages can be up to $max characters.';
  }

  @override
  String chatMessageFrom(String name, String time) {
    return '$name, $time';
  }

  @override
  String get messageActionCopy => 'Copy text';

  @override
  String get messageActionReport => 'Report message';

  @override
  String get messageActionWithdraw => 'Withdraw message';

  @override
  String get messageActionRemove => 'Remove message';

  @override
  String messageActionMessageSender(String name) {
    return 'Message $name';
  }

  @override
  String get messageCopied => 'Copied.';

  @override
  String get messageWithdrawn => 'Message withdrawn.';

  @override
  String linkOpenButton(String host) {
    return 'Open link to $host';
  }

  @override
  String get linkOpenTitle => 'Open this link?';

  @override
  String linkOpenBody(String host) {
    return 'This link goes to $host. Links are shared by students and may not be safe. Continue only if you trust the site.';
  }

  @override
  String get linkOpenAction => 'Open link';

  @override
  String get messagesTitle => 'Messages';

  @override
  String get inboxEmptyTitle => 'No conversations yet';

  @override
  String get inboxEmptyBody =>
      'To message someone, open a group you share and tap their name in the member list.';

  @override
  String inboxYou(String text) {
    return 'You: $text';
  }

  @override
  String get dmLinksPlain =>
      'Links in private messages cannot be opened from the app. Be careful with links from people you do not know.';

  @override
  String get dmBlock => 'Block';

  @override
  String get dmUnblock => 'Unblock';

  @override
  String get dmBlockedNotice =>
      'You blocked this person. Unblock them to send messages.';

  @override
  String dmBlockConfirmTitle(String name) {
    return 'Block $name?';
  }

  @override
  String get dmBlockConfirmBody =>
      'They will not be able to message you, and you will no longer see their messages in groups. You can unblock them in Profile.';

  @override
  String get dmStartFailed =>
      'You cannot message this person. One of you may have left the group or blocked messages.';

  @override
  String get dmReportUser => 'Report user';

  @override
  String get unknownUser => 'Former member';

  @override
  String get reportTitle => 'Report';

  @override
  String get reportWhy => 'Why are you reporting this?';

  @override
  String get reportReasonSpam => 'Spam or advertising';

  @override
  String get reportReasonHarassment => 'Harassment or bullying';

  @override
  String get reportReasonScam => 'Scam or fraud';

  @override
  String get reportReasonInappropriate => 'Inappropriate content';

  @override
  String get reportReasonOther => 'Something else';

  @override
  String get reportDetails => 'More details (optional)';

  @override
  String get reportSubmit => 'Send report';

  @override
  String get reportSent => 'Thanks. A moderator will review your report.';

  @override
  String get reportAlready => 'You already reported this.';

  @override
  String get reportFailed => 'Could not send the report. Try again.';

  @override
  String get moderationTitle => 'Moderation';

  @override
  String get moderationPendingTab => 'Pending links';

  @override
  String get moderationReportsTab => 'Reports';

  @override
  String get moderationSuspendedTab => 'Suspended';

  @override
  String get moderationSuspendedEmpty => 'No accounts are suspended.';

  @override
  String get moderationSuspendedUnknownName => 'Unknown user';

  @override
  String get moderationLift => 'Lift suspension';

  @override
  String get moderationLiftTitle => 'Lift this suspension?';

  @override
  String moderationLiftBody(String name) {
    return '$name will be able to post and message again. This is recorded in the audit log.';
  }

  @override
  String get moderationLiftNotAllowed =>
      'Only the owner can lift a suspension of a staff member.';

  @override
  String moderationSuspendedReason(String reason) {
    return 'Reason: $reason';
  }

  @override
  String get moderationPendingEmpty => 'No links are waiting for review.';

  @override
  String get moderationReportsEmpty => 'No open reports.';

  @override
  String get moderationApprove => 'Approve';

  @override
  String get moderationRemove => 'Remove';

  @override
  String get moderationDismiss => 'Dismiss';

  @override
  String get moderationSuspend => 'Suspend user';

  @override
  String get moderationSuspendTitle => 'Suspend this user?';

  @override
  String get moderationSuspendBody =>
      'They will be signed out of posting and messaging until a staff member lifts the suspension.';

  @override
  String get moderationReason => 'Reason (kept in the audit log)';

  @override
  String get moderationDone => 'Done.';

  @override
  String get moderationFailed =>
      'The action failed. You may not have permission for this group.';

  @override
  String moderationFrom(String name) {
    return 'From $name';
  }

  @override
  String moderationReportLine(String reason, String type) {
    return '$reason · $type';
  }

  @override
  String get reportTypeGroupMessage => 'Group message';

  @override
  String get reportTypeDirectMessage => 'Private message';

  @override
  String get reportTypeUser => 'User';

  @override
  String get communityNotAllowed => 'You cannot do this right now.';

  @override
  String get communityOffline =>
      'You appear to be offline. Try again when you are connected.';

  @override
  String get stateLoading => 'Loading';

  @override
  String get stateErrorTitle => 'Something went wrong';

  @override
  String get stateOffline =>
      'You are offline. Some content may be out of date.';

  @override
  String get notFoundTitle => 'Page not found';

  @override
  String get notFoundBody => 'This page does not exist or has moved.';

  @override
  String get linkCommunityRules => 'Community rules';

  @override
  String get linkPrivacy => 'Privacy notice';

  @override
  String legalLastUpdated(String date) {
    return 'Last updated $date';
  }

  @override
  String get legalContactTitle => 'Contact';

  @override
  String legalContactEmail(String email) {
    return 'Email: $email';
  }

  @override
  String legalDeletionPage(String url) {
    return 'Account deletion page: $url';
  }

  @override
  String legalPolicyPage(String url) {
    return 'Privacy policy online: $url';
  }

  @override
  String get createAccountAcceptRules =>
      'I have read and accept the community rules and the privacy notice.';

  @override
  String get errorAcceptRules =>
      'Accept the community rules to create an account.';

  @override
  String get acceptRulesTitle => 'Community rules';

  @override
  String get acceptRulesBody =>
      'Before you join groups or send messages, read and accept the community rules. They keep the community safe and useful for everyone.';

  @override
  String get acceptRulesRead => 'Read the community rules';

  @override
  String get acceptRulesAccept => 'I accept the rules';

  @override
  String get acceptRulesNotNow => 'Not now';

  @override
  String get acceptRulesFailed =>
      'Could not save your answer. Check your connection and try again.';

  @override
  String get profileSectionLegal => 'Rules and privacy';

  @override
  String get profileBlockedAccounts => 'Blocked accounts';

  @override
  String get blockedTitle => 'Blocked accounts';

  @override
  String get blockedHint =>
      'Blocked people cannot message you, and their group messages are hidden from you.';

  @override
  String get blockedEmpty => 'You have not blocked anyone.';

  @override
  String get blockedLoadFailed => 'Could not load blocked accounts.';

  @override
  String get blockedUnblockDone => 'Unblocked.';

  @override
  String blockActionBlock(String name) {
    return 'Block $name';
  }

  @override
  String blockActionUnblock(String name) {
    return 'Unblock $name';
  }

  @override
  String get groupBlockConfirmBody =>
      'They will not be able to message you, and you will no longer see their messages in groups. You can unblock them in Profile.';

  @override
  String get blockDone => 'Blocked. You will no longer see their messages.';
}
