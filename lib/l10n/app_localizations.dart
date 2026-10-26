import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[Locale('en')];

  /// App name. Not translated.
  ///
  /// In en, this message translates to:
  /// **'Deutschhelfer'**
  String get appTitle;

  /// No description provided for @brandMarkLabel.
  ///
  /// In en, this message translates to:
  /// **'Deutschhelfer logo'**
  String get brandMarkLabel;

  /// No description provided for @welcomeHeadline.
  ///
  /// In en, this message translates to:
  /// **'Your path to studying in Germany'**
  String get welcomeHeadline;

  /// No description provided for @welcomeBody.
  ///
  /// In en, this message translates to:
  /// **'Step-by-step guidance on admissions, applications and visas, with a community of students on the same journey.'**
  String get welcomeBody;

  /// No description provided for @welcomeFeatureGuidanceTitle.
  ///
  /// In en, this message translates to:
  /// **'Admissions and visa guidance'**
  String get welcomeFeatureGuidanceTitle;

  /// No description provided for @welcomeFeatureGuidanceBody.
  ///
  /// In en, this message translates to:
  /// **'Clear steps from choosing a university to your visa appointment.'**
  String get welcomeFeatureGuidanceBody;

  /// No description provided for @welcomeFeatureCommunityTitle.
  ///
  /// In en, this message translates to:
  /// **'Student community'**
  String get welcomeFeatureCommunityTitle;

  /// No description provided for @welcomeFeatureCommunityBody.
  ///
  /// In en, this message translates to:
  /// **'Topic groups where students help each other, with moderators keeping them safe.'**
  String get welcomeFeatureCommunityBody;

  /// No description provided for @welcomeFeatureIeltsTitle.
  ///
  /// In en, this message translates to:
  /// **'IELTS preparation'**
  String get welcomeFeatureIeltsTitle;

  /// No description provided for @welcomeFeatureIeltsBody.
  ///
  /// In en, this message translates to:
  /// **'Tips and practice material to help you reach your target band.'**
  String get welcomeFeatureIeltsBody;

  /// No description provided for @actionCreateAccount.
  ///
  /// In en, this message translates to:
  /// **'Create account'**
  String get actionCreateAccount;

  /// No description provided for @actionSignIn.
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get actionSignIn;

  /// No description provided for @actionSendResetLink.
  ///
  /// In en, this message translates to:
  /// **'Send reset link'**
  String get actionSendResetLink;

  /// No description provided for @actionTryAgain.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get actionTryAgain;

  /// No description provided for @actionBackToSignIn.
  ///
  /// In en, this message translates to:
  /// **'Back to sign in'**
  String get actionBackToSignIn;

  /// No description provided for @actionGoToStart.
  ///
  /// In en, this message translates to:
  /// **'Go to start'**
  String get actionGoToStart;

  /// No description provided for @signInTitle.
  ///
  /// In en, this message translates to:
  /// **'Welcome back'**
  String get signInTitle;

  /// No description provided for @signInSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Sign in to continue your preparation.'**
  String get signInSubtitle;

  /// No description provided for @forgotPasswordLink.
  ///
  /// In en, this message translates to:
  /// **'Forgot password?'**
  String get forgotPasswordLink;

  /// No description provided for @noAccountPrompt.
  ///
  /// In en, this message translates to:
  /// **'New to Deutschhelfer?'**
  String get noAccountPrompt;

  /// No description provided for @createAccountTitle.
  ///
  /// In en, this message translates to:
  /// **'Create your account'**
  String get createAccountTitle;

  /// No description provided for @createAccountSubtitle.
  ///
  /// In en, this message translates to:
  /// **'You will confirm your email before you can post in groups or send messages.'**
  String get createAccountSubtitle;

  /// No description provided for @haveAccountPrompt.
  ///
  /// In en, this message translates to:
  /// **'Already have an account?'**
  String get haveAccountPrompt;

  /// No description provided for @forgotPasswordTitle.
  ///
  /// In en, this message translates to:
  /// **'Reset your password'**
  String get forgotPasswordTitle;

  /// No description provided for @forgotPasswordBody.
  ///
  /// In en, this message translates to:
  /// **'Enter the email you signed up with. If it matches an account, we will send a link to reset your password.'**
  String get forgotPasswordBody;

  /// No description provided for @resetEmailSentTitle.
  ///
  /// In en, this message translates to:
  /// **'Check your email'**
  String get resetEmailSentTitle;

  /// No description provided for @resetEmailSentBody.
  ///
  /// In en, this message translates to:
  /// **'If an account exists for {email}, a reset link is on its way. It can take a few minutes to arrive.'**
  String resetEmailSentBody(String email);

  /// No description provided for @fieldDisplayName.
  ///
  /// In en, this message translates to:
  /// **'Display name'**
  String get fieldDisplayName;

  /// No description provided for @fieldDisplayNameHelper.
  ///
  /// In en, this message translates to:
  /// **'Other students see this name in groups and messages.'**
  String get fieldDisplayNameHelper;

  /// No description provided for @fieldEmail.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get fieldEmail;

  /// No description provided for @fieldPassword.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get fieldPassword;

  /// No description provided for @fieldNewPasswordHelper.
  ///
  /// In en, this message translates to:
  /// **'At least {min} characters, including a letter and a number.'**
  String fieldNewPasswordHelper(int min);

  /// No description provided for @fieldConfirmPassword.
  ///
  /// In en, this message translates to:
  /// **'Confirm password'**
  String get fieldConfirmPassword;

  /// No description provided for @showPassword.
  ///
  /// In en, this message translates to:
  /// **'Show password'**
  String get showPassword;

  /// No description provided for @hidePassword.
  ///
  /// In en, this message translates to:
  /// **'Hide password'**
  String get hidePassword;

  /// No description provided for @errorRequired.
  ///
  /// In en, this message translates to:
  /// **'This field is required.'**
  String get errorRequired;

  /// No description provided for @errorEmailInvalid.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid email address, like name@example.com.'**
  String get errorEmailInvalid;

  /// No description provided for @errorEmailTooLong.
  ///
  /// In en, this message translates to:
  /// **'This email address is too long.'**
  String get errorEmailTooLong;

  /// No description provided for @errorPasswordTooShort.
  ///
  /// In en, this message translates to:
  /// **'Use at least {min} characters.'**
  String errorPasswordTooShort(int min);

  /// No description provided for @errorPasswordTooLong.
  ///
  /// In en, this message translates to:
  /// **'Use at most {max} characters.'**
  String errorPasswordTooLong(int max);

  /// No description provided for @errorPasswordNeedsLetterAndDigit.
  ///
  /// In en, this message translates to:
  /// **'Include at least one letter and one number.'**
  String get errorPasswordNeedsLetterAndDigit;

  /// No description provided for @errorPasswordsDoNotMatch.
  ///
  /// In en, this message translates to:
  /// **'The passwords do not match.'**
  String get errorPasswordsDoNotMatch;

  /// No description provided for @errorDisplayNameTooShort.
  ///
  /// In en, this message translates to:
  /// **'Use at least {min} characters.'**
  String errorDisplayNameTooShort(int min);

  /// No description provided for @errorDisplayNameTooLong.
  ///
  /// In en, this message translates to:
  /// **'Use at most {max} characters.'**
  String errorDisplayNameTooLong(int max);

  /// No description provided for @errorDisplayNameInvalidCharacters.
  ///
  /// In en, this message translates to:
  /// **'Remove special characters such as < and >.'**
  String get errorDisplayNameInvalidCharacters;

  /// No description provided for @errorDisplayNameContainsLink.
  ///
  /// In en, this message translates to:
  /// **'Display names cannot contain links or web addresses.'**
  String get errorDisplayNameContainsLink;

  /// No description provided for @errorGroupNameTooShort.
  ///
  /// In en, this message translates to:
  /// **'Use at least {min} characters.'**
  String errorGroupNameTooShort(int min);

  /// No description provided for @errorGroupNameTooLong.
  ///
  /// In en, this message translates to:
  /// **'Use at most {max} characters.'**
  String errorGroupNameTooLong(int max);

  /// No description provided for @errorGroupDescriptionTooLong.
  ///
  /// In en, this message translates to:
  /// **'Use at most {max} characters.'**
  String errorGroupDescriptionTooLong(int max);

  /// No description provided for @errorTextInvalidCharacters.
  ///
  /// In en, this message translates to:
  /// **'Remove special characters such as < and >.'**
  String get errorTextInvalidCharacters;

  /// No description provided for @errorGroupNameContainsLink.
  ///
  /// In en, this message translates to:
  /// **'Group names cannot contain links or web addresses.'**
  String get errorGroupNameContainsLink;

  /// No description provided for @authNotConfigured.
  ///
  /// In en, this message translates to:
  /// **'Account services are not connected in this build yet, so you cannot sign in.'**
  String get authNotConfigured;

  /// No description provided for @authInvalidCredentials.
  ///
  /// In en, this message translates to:
  /// **'That email and password do not match an account.'**
  String get authInvalidCredentials;

  /// No description provided for @authEmailAlreadyInUse.
  ///
  /// In en, this message translates to:
  /// **'This email cannot be used to create an account. Try signing in or resetting your password.'**
  String get authEmailAlreadyInUse;

  /// No description provided for @authWeakPassword.
  ///
  /// In en, this message translates to:
  /// **'Choose a stronger password.'**
  String get authWeakPassword;

  /// No description provided for @authUserDisabled.
  ///
  /// In en, this message translates to:
  /// **'This account is disabled. Contact support if you think this is a mistake.'**
  String get authUserDisabled;

  /// No description provided for @authTooManyRequests.
  ///
  /// In en, this message translates to:
  /// **'Too many attempts. Wait a few minutes, then try again.'**
  String get authTooManyRequests;

  /// No description provided for @authNetwork.
  ///
  /// In en, this message translates to:
  /// **'You appear to be offline. Check your connection and try again.'**
  String get authNetwork;

  /// No description provided for @authUnknown.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong. Please try again.'**
  String get authUnknown;

  /// No description provided for @authRequiresRecentLogin.
  ///
  /// In en, this message translates to:
  /// **'For your security, sign in again before doing this.'**
  String get authRequiresRecentLogin;

  /// No description provided for @verifyEmailTitle.
  ///
  /// In en, this message translates to:
  /// **'Confirm your email'**
  String get verifyEmailTitle;

  /// No description provided for @verifyEmailBody.
  ///
  /// In en, this message translates to:
  /// **'We sent a confirmation link to {email}. Open it on this phone or any device, then come back here.'**
  String verifyEmailBody(String email);

  /// No description provided for @verifyEmailWhy.
  ///
  /// In en, this message translates to:
  /// **'Confirming your email helps keep groups free of spam. Until then you cannot post or send messages.'**
  String get verifyEmailWhy;

  /// No description provided for @verifyEmailCheck.
  ///
  /// In en, this message translates to:
  /// **'I have confirmed my email'**
  String get verifyEmailCheck;

  /// No description provided for @verifyEmailResend.
  ///
  /// In en, this message translates to:
  /// **'Send the link again'**
  String get verifyEmailResend;

  /// No description provided for @verifyEmailResendIn.
  ///
  /// In en, this message translates to:
  /// **'Send again in {seconds} s'**
  String verifyEmailResendIn(int seconds);

  /// No description provided for @verifyEmailSent.
  ///
  /// In en, this message translates to:
  /// **'A new link is on its way. Check your spam folder too.'**
  String get verifyEmailSent;

  /// No description provided for @verifyEmailStillPending.
  ///
  /// In en, this message translates to:
  /// **'Your email is not confirmed yet. Open the link in the email, then try again.'**
  String get verifyEmailStillPending;

  /// No description provided for @actionSignOut.
  ///
  /// In en, this message translates to:
  /// **'Sign out'**
  String get actionSignOut;

  /// No description provided for @actionCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get actionCancel;

  /// No description provided for @actionSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get actionSave;

  /// No description provided for @restrictedSuspendedTitle.
  ///
  /// In en, this message translates to:
  /// **'Your account is suspended'**
  String get restrictedSuspendedTitle;

  /// No description provided for @restrictedSuspendedBody.
  ///
  /// In en, this message translates to:
  /// **'A moderator suspended this account after reports of a rule violation. You cannot post or send messages while it is suspended.'**
  String get restrictedSuspendedBody;

  /// No description provided for @restrictedDeletedTitle.
  ///
  /// In en, this message translates to:
  /// **'This account was deleted'**
  String get restrictedDeletedTitle;

  /// No description provided for @restrictedDeletedBody.
  ///
  /// In en, this message translates to:
  /// **'The account is scheduled for removal and can no longer be used.'**
  String get restrictedDeletedBody;

  /// No description provided for @restrictedContact.
  ///
  /// In en, this message translates to:
  /// **'If you think this is a mistake, contact the Deutschhelfer team from the email address on your account.'**
  String get restrictedContact;

  /// No description provided for @navGuide.
  ///
  /// In en, this message translates to:
  /// **'Guide'**
  String get navGuide;

  /// No description provided for @navGroups.
  ///
  /// In en, this message translates to:
  /// **'Groups'**
  String get navGroups;

  /// No description provided for @navMessages.
  ///
  /// In en, this message translates to:
  /// **'Messages'**
  String get navMessages;

  /// No description provided for @navProfile.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get navProfile;

  /// No description provided for @profileTitle.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get profileTitle;

  /// No description provided for @profileEditName.
  ///
  /// In en, this message translates to:
  /// **'Edit display name'**
  String get profileEditName;

  /// No description provided for @profileEmailLabel.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get profileEmailLabel;

  /// No description provided for @profileEmailPrivate.
  ///
  /// In en, this message translates to:
  /// **'Only you can see your email.'**
  String get profileEmailPrivate;

  /// No description provided for @profileRoleOwner.
  ///
  /// In en, this message translates to:
  /// **'Owner'**
  String get profileRoleOwner;

  /// No description provided for @profileRoleStudentAdmin.
  ///
  /// In en, this message translates to:
  /// **'Student admin'**
  String get profileRoleStudentAdmin;

  /// No description provided for @profilePremium.
  ///
  /// In en, this message translates to:
  /// **'Premium'**
  String get profilePremium;

  /// No description provided for @profileNameSaved.
  ///
  /// In en, this message translates to:
  /// **'Display name updated.'**
  String get profileNameSaved;

  /// No description provided for @profileSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not save. Check your connection and try again.'**
  String get profileSaveFailed;

  /// No description provided for @profileSignOutConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Sign out?'**
  String get profileSignOutConfirmTitle;

  /// No description provided for @profileSignOutConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'You will need your email and password to sign in again.'**
  String get profileSignOutConfirmBody;

  /// No description provided for @profileSectionAccount.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get profileSectionAccount;

  /// No description provided for @profileSectionCommunity.
  ///
  /// In en, this message translates to:
  /// **'Community'**
  String get profileSectionCommunity;

  /// No description provided for @profileModeration.
  ///
  /// In en, this message translates to:
  /// **'Moderation'**
  String get profileModeration;

  /// No description provided for @profileModerationHint.
  ///
  /// In en, this message translates to:
  /// **'Review pending links and reports'**
  String get profileModerationHint;

  /// No description provided for @profileNotifications.
  ///
  /// In en, this message translates to:
  /// **'Message notifications'**
  String get profileNotifications;

  /// No description provided for @profileNotificationsHint.
  ///
  /// In en, this message translates to:
  /// **'Alerts show who wrote to you, never the message itself.'**
  String get profileNotificationsHint;

  /// No description provided for @profileNotificationsDenied.
  ///
  /// In en, this message translates to:
  /// **'Notifications are blocked. Allow them for Deutschhelfer in Android settings.'**
  String get profileNotificationsDenied;

  /// No description provided for @profileNotificationsFailed.
  ///
  /// In en, this message translates to:
  /// **'Notification settings could not be changed. Try again.'**
  String get profileNotificationsFailed;

  /// No description provided for @profileDeleteAccount.
  ///
  /// In en, this message translates to:
  /// **'Delete account'**
  String get profileDeleteAccount;

  /// No description provided for @profileDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete your account?'**
  String get profileDeleteTitle;

  /// No description provided for @profileDeleteBody.
  ///
  /// In en, this message translates to:
  /// **'You leave all groups right away, and your name is replaced with \"Deleted user\" everywhere. Remaining data is removed after 90 days. This cannot be undone.'**
  String get profileDeleteBody;

  /// No description provided for @profileDeleteConfirmLabel.
  ///
  /// In en, this message translates to:
  /// **'Type DELETE to confirm'**
  String get profileDeleteConfirmLabel;

  /// No description provided for @profileDeleteFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not delete your account. Check your connection and try again.'**
  String get profileDeleteFailed;

  /// No description provided for @profileDeletePasswordLabel.
  ///
  /// In en, this message translates to:
  /// **'Your password'**
  String get profileDeletePasswordLabel;

  /// No description provided for @profileDeleteWrongPassword.
  ///
  /// In en, this message translates to:
  /// **'That password is not correct, so your account was not deleted.'**
  String get profileDeleteWrongPassword;

  /// No description provided for @groupMakeModerator.
  ///
  /// In en, this message translates to:
  /// **'Make moderator'**
  String get groupMakeModerator;

  /// No description provided for @groupRemoveModerator.
  ///
  /// In en, this message translates to:
  /// **'Remove moderator role'**
  String get groupRemoveModerator;

  /// No description provided for @groupRoleUpdated.
  ///
  /// In en, this message translates to:
  /// **'Role updated. The change applies after they next sign in.'**
  String get groupRoleUpdated;

  /// No description provided for @profileAbout.
  ///
  /// In en, this message translates to:
  /// **'About Deutschhelfer'**
  String get profileAbout;

  /// No description provided for @profileAboutBody.
  ///
  /// In en, this message translates to:
  /// **'Deutschhelfer is a student-run guide. It is not affiliated with the German government, DAAD, any embassy or any university. Always confirm requirements on official websites.'**
  String get profileAboutBody;

  /// No description provided for @guideTitle.
  ///
  /// In en, this message translates to:
  /// **'Guide'**
  String get guideTitle;

  /// No description provided for @guideSearchLabel.
  ///
  /// In en, this message translates to:
  /// **'Search the guide'**
  String get guideSearchLabel;

  /// No description provided for @guideSearchClear.
  ///
  /// In en, this message translates to:
  /// **'Clear search'**
  String get guideSearchClear;

  /// No description provided for @guideAllCategories.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get guideAllCategories;

  /// No description provided for @guideNoResultsTitle.
  ///
  /// In en, this message translates to:
  /// **'No matching articles'**
  String get guideNoResultsTitle;

  /// No description provided for @guideNoResultsBody.
  ///
  /// In en, this message translates to:
  /// **'Try fewer or different words, or choose another category.'**
  String get guideNoResultsBody;

  /// No description provided for @guidePremiumBadge.
  ///
  /// In en, this message translates to:
  /// **'Premium'**
  String get guidePremiumBadge;

  /// No description provided for @guideUpdated.
  ///
  /// In en, this message translates to:
  /// **'Updated {date}'**
  String guideUpdated(DateTime date);

  /// No description provided for @guideSources.
  ///
  /// In en, this message translates to:
  /// **'Official sources'**
  String get guideSources;

  /// No description provided for @guideOpenSource.
  ///
  /// In en, this message translates to:
  /// **'Open {label} in your browser'**
  String guideOpenSource(String label);

  /// No description provided for @guideOpenFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not open the link.'**
  String get guideOpenFailed;

  /// No description provided for @guideDisclaimer.
  ///
  /// In en, this message translates to:
  /// **'This guide is general information, not legal or immigration advice. Requirements change, so always confirm them on the official websites above.'**
  String get guideDisclaimer;

  /// No description provided for @guideLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'The guide could not be loaded.'**
  String get guideLoadFailed;

  /// No description provided for @guideArticleMissing.
  ///
  /// In en, this message translates to:
  /// **'This article is no longer available.'**
  String get guideArticleMissing;

  /// No description provided for @premiumLockedTitle.
  ///
  /// In en, this message translates to:
  /// **'Premium article'**
  String get premiumLockedTitle;

  /// No description provided for @premiumLockedBody.
  ///
  /// In en, this message translates to:
  /// **'This article is part of Premium. Premium plans are not available yet. They will appear here when they launch.'**
  String get premiumLockedBody;

  /// No description provided for @premiumUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Premium content could not be loaded. Check your connection and try again.'**
  String get premiumUnavailable;

  /// No description provided for @premiumNotFound.
  ///
  /// In en, this message translates to:
  /// **'This premium article has not been published yet.'**
  String get premiumNotFound;

  /// No description provided for @groupsTitle.
  ///
  /// In en, this message translates to:
  /// **'Groups'**
  String get groupsTitle;

  /// No description provided for @groupsYours.
  ///
  /// In en, this message translates to:
  /// **'Your groups'**
  String get groupsYours;

  /// No description provided for @groupsDiscover.
  ///
  /// In en, this message translates to:
  /// **'Discover groups'**
  String get groupsDiscover;

  /// No description provided for @groupsEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No groups yet'**
  String get groupsEmptyTitle;

  /// No description provided for @groupsEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'Groups appear here when the Deutschhelfer team opens them.'**
  String get groupsEmptyBody;

  /// No description provided for @groupsCreate.
  ///
  /// In en, this message translates to:
  /// **'New group'**
  String get groupsCreate;

  /// No description provided for @groupCreateTitle.
  ///
  /// In en, this message translates to:
  /// **'New group'**
  String get groupCreateTitle;

  /// No description provided for @groupCreateIntro.
  ///
  /// In en, this message translates to:
  /// **'Groups are open to every verified student. Members can join, chat and report problems. Moderators you appoint review links.'**
  String get groupCreateIntro;

  /// No description provided for @groupCreateName.
  ///
  /// In en, this message translates to:
  /// **'Group name'**
  String get groupCreateName;

  /// No description provided for @groupCreateDescription.
  ///
  /// In en, this message translates to:
  /// **'Description (optional)'**
  String get groupCreateDescription;

  /// No description provided for @groupCreateCategory.
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get groupCreateCategory;

  /// No description provided for @groupCreateSubmit.
  ///
  /// In en, this message translates to:
  /// **'Create group'**
  String get groupCreateSubmit;

  /// No description provided for @groupCreateFailed.
  ///
  /// In en, this message translates to:
  /// **'The group could not be created. Check your connection and try again.'**
  String get groupCreateFailed;

  /// No description provided for @groupCreated.
  ///
  /// In en, this message translates to:
  /// **'Group created.'**
  String get groupCreated;

  /// No description provided for @groupsMemberCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 member} other{{count} members}}'**
  String groupsMemberCount(int count);

  /// No description provided for @groupsLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Groups could not be loaded.'**
  String get groupsLoadFailed;

  /// No description provided for @groupJoin.
  ///
  /// In en, this message translates to:
  /// **'Join group'**
  String get groupJoin;

  /// No description provided for @groupJoined.
  ///
  /// In en, this message translates to:
  /// **'You joined the group.'**
  String get groupJoined;

  /// No description provided for @groupLeave.
  ///
  /// In en, this message translates to:
  /// **'Leave group'**
  String get groupLeave;

  /// No description provided for @groupLeaveConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Leave this group?'**
  String get groupLeaveConfirmTitle;

  /// No description provided for @groupLeaveConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'You will stop seeing its messages. You can join again later.'**
  String get groupLeaveConfirmBody;

  /// No description provided for @groupFull.
  ///
  /// In en, this message translates to:
  /// **'This group is full.'**
  String get groupFull;

  /// No description provided for @groupOpenChat.
  ///
  /// In en, this message translates to:
  /// **'Open chat'**
  String get groupOpenChat;

  /// No description provided for @groupMembers.
  ///
  /// In en, this message translates to:
  /// **'Members'**
  String get groupMembers;

  /// No description provided for @groupMembersPrivate.
  ///
  /// In en, this message translates to:
  /// **'Join the group to see who else is in it.'**
  String get groupMembersPrivate;

  /// No description provided for @groupModeratorBadge.
  ///
  /// In en, this message translates to:
  /// **'Moderator'**
  String get groupModeratorBadge;

  /// No description provided for @groupYouBadge.
  ///
  /// In en, this message translates to:
  /// **'You'**
  String get groupYouBadge;

  /// No description provided for @groupInfo.
  ///
  /// In en, this message translates to:
  /// **'Group info'**
  String get groupInfo;

  /// No description provided for @groupMissing.
  ///
  /// In en, this message translates to:
  /// **'This group is no longer available.'**
  String get groupMissing;

  /// No description provided for @categoryAdmissions.
  ///
  /// In en, this message translates to:
  /// **'Admissions'**
  String get categoryAdmissions;

  /// No description provided for @categoryVisa.
  ///
  /// In en, this message translates to:
  /// **'Visa'**
  String get categoryVisa;

  /// No description provided for @categoryIelts.
  ///
  /// In en, this message translates to:
  /// **'IELTS'**
  String get categoryIelts;

  /// No description provided for @categoryLiving.
  ///
  /// In en, this message translates to:
  /// **'Living in Germany'**
  String get categoryLiving;

  /// No description provided for @categoryGeneral.
  ///
  /// In en, this message translates to:
  /// **'General'**
  String get categoryGeneral;

  /// No description provided for @chatComposerHint.
  ///
  /// In en, this message translates to:
  /// **'Write a message'**
  String get chatComposerHint;

  /// No description provided for @chatSend.
  ///
  /// In en, this message translates to:
  /// **'Send message'**
  String get chatSend;

  /// No description provided for @chatLinkNotice.
  ///
  /// In en, this message translates to:
  /// **'Messages with links are checked by a moderator before others see them.'**
  String get chatLinkNotice;

  /// No description provided for @chatPendingBadge.
  ///
  /// In en, this message translates to:
  /// **'Waiting for moderator approval'**
  String get chatPendingBadge;

  /// No description provided for @chatSending.
  ///
  /// In en, this message translates to:
  /// **'Sending…'**
  String get chatSending;

  /// No description provided for @chatEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No messages yet'**
  String get chatEmptyTitle;

  /// No description provided for @chatEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'Say hello and introduce yourself.'**
  String get chatEmptyBody;

  /// No description provided for @chatStart.
  ///
  /// In en, this message translates to:
  /// **'This is the start of the conversation.'**
  String get chatStart;

  /// No description provided for @chatLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Messages could not be loaded.'**
  String get chatLoadFailed;

  /// No description provided for @chatSendFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not send. Wait a moment and try again.'**
  String get chatSendFailed;

  /// No description provided for @chatTooLong.
  ///
  /// In en, this message translates to:
  /// **'Messages can be up to {max} characters.'**
  String chatTooLong(int max);

  /// No description provided for @chatMessageFrom.
  ///
  /// In en, this message translates to:
  /// **'{name}, {time}'**
  String chatMessageFrom(String name, String time);

  /// No description provided for @messageActionCopy.
  ///
  /// In en, this message translates to:
  /// **'Copy text'**
  String get messageActionCopy;

  /// No description provided for @messageActionReport.
  ///
  /// In en, this message translates to:
  /// **'Report message'**
  String get messageActionReport;

  /// No description provided for @messageActionWithdraw.
  ///
  /// In en, this message translates to:
  /// **'Withdraw message'**
  String get messageActionWithdraw;

  /// No description provided for @messageActionRemove.
  ///
  /// In en, this message translates to:
  /// **'Remove message'**
  String get messageActionRemove;

  /// No description provided for @messageActionMessageSender.
  ///
  /// In en, this message translates to:
  /// **'Message {name}'**
  String messageActionMessageSender(String name);

  /// No description provided for @messageCopied.
  ///
  /// In en, this message translates to:
  /// **'Copied.'**
  String get messageCopied;

  /// No description provided for @messageWithdrawn.
  ///
  /// In en, this message translates to:
  /// **'Message withdrawn.'**
  String get messageWithdrawn;

  /// No description provided for @linkOpenButton.
  ///
  /// In en, this message translates to:
  /// **'Open link to {host}'**
  String linkOpenButton(String host);

  /// No description provided for @linkOpenTitle.
  ///
  /// In en, this message translates to:
  /// **'Open this link?'**
  String get linkOpenTitle;

  /// No description provided for @linkOpenBody.
  ///
  /// In en, this message translates to:
  /// **'This link goes to {host}. Links are shared by students and may not be safe. Continue only if you trust the site.'**
  String linkOpenBody(String host);

  /// No description provided for @linkOpenAction.
  ///
  /// In en, this message translates to:
  /// **'Open link'**
  String get linkOpenAction;

  /// No description provided for @messagesTitle.
  ///
  /// In en, this message translates to:
  /// **'Messages'**
  String get messagesTitle;

  /// No description provided for @inboxEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No conversations yet'**
  String get inboxEmptyTitle;

  /// No description provided for @inboxEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'To message someone, open a group you share and tap their name in the member list.'**
  String get inboxEmptyBody;

  /// No description provided for @inboxYou.
  ///
  /// In en, this message translates to:
  /// **'You: {text}'**
  String inboxYou(String text);

  /// No description provided for @dmLinksPlain.
  ///
  /// In en, this message translates to:
  /// **'Links in private messages cannot be opened from the app. Be careful with links from people you do not know.'**
  String get dmLinksPlain;

  /// No description provided for @dmBlock.
  ///
  /// In en, this message translates to:
  /// **'Block'**
  String get dmBlock;

  /// No description provided for @dmUnblock.
  ///
  /// In en, this message translates to:
  /// **'Unblock'**
  String get dmUnblock;

  /// No description provided for @dmBlockedNotice.
  ///
  /// In en, this message translates to:
  /// **'You blocked this person. Unblock them to send messages.'**
  String get dmBlockedNotice;

  /// No description provided for @dmBlockConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Block {name}?'**
  String dmBlockConfirmTitle(String name);

  /// No description provided for @dmBlockConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'They will not be able to message you, and you will no longer see their messages in groups. You can unblock them in Profile.'**
  String get dmBlockConfirmBody;

  /// No description provided for @dmStartFailed.
  ///
  /// In en, this message translates to:
  /// **'You cannot message this person. One of you may have left the group or blocked messages.'**
  String get dmStartFailed;

  /// No description provided for @dmReportUser.
  ///
  /// In en, this message translates to:
  /// **'Report user'**
  String get dmReportUser;

  /// No description provided for @unknownUser.
  ///
  /// In en, this message translates to:
  /// **'Former member'**
  String get unknownUser;

  /// No description provided for @reportTitle.
  ///
  /// In en, this message translates to:
  /// **'Report'**
  String get reportTitle;

  /// No description provided for @reportWhy.
  ///
  /// In en, this message translates to:
  /// **'Why are you reporting this?'**
  String get reportWhy;

  /// No description provided for @reportReasonSpam.
  ///
  /// In en, this message translates to:
  /// **'Spam or advertising'**
  String get reportReasonSpam;

  /// No description provided for @reportReasonHarassment.
  ///
  /// In en, this message translates to:
  /// **'Harassment or bullying'**
  String get reportReasonHarassment;

  /// No description provided for @reportReasonScam.
  ///
  /// In en, this message translates to:
  /// **'Scam or fraud'**
  String get reportReasonScam;

  /// No description provided for @reportReasonInappropriate.
  ///
  /// In en, this message translates to:
  /// **'Inappropriate content'**
  String get reportReasonInappropriate;

  /// No description provided for @reportReasonOther.
  ///
  /// In en, this message translates to:
  /// **'Something else'**
  String get reportReasonOther;

  /// No description provided for @reportDetails.
  ///
  /// In en, this message translates to:
  /// **'More details (optional)'**
  String get reportDetails;

  /// No description provided for @reportSubmit.
  ///
  /// In en, this message translates to:
  /// **'Send report'**
  String get reportSubmit;

  /// No description provided for @reportSent.
  ///
  /// In en, this message translates to:
  /// **'Thanks. A moderator will review your report.'**
  String get reportSent;

  /// No description provided for @reportAlready.
  ///
  /// In en, this message translates to:
  /// **'You already reported this.'**
  String get reportAlready;

  /// No description provided for @reportFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not send the report. Try again.'**
  String get reportFailed;

  /// No description provided for @moderationTitle.
  ///
  /// In en, this message translates to:
  /// **'Moderation'**
  String get moderationTitle;

  /// No description provided for @moderationPendingTab.
  ///
  /// In en, this message translates to:
  /// **'Pending links'**
  String get moderationPendingTab;

  /// No description provided for @moderationReportsTab.
  ///
  /// In en, this message translates to:
  /// **'Reports'**
  String get moderationReportsTab;

  /// No description provided for @moderationSuspendedTab.
  ///
  /// In en, this message translates to:
  /// **'Suspended'**
  String get moderationSuspendedTab;

  /// No description provided for @moderationSuspendedEmpty.
  ///
  /// In en, this message translates to:
  /// **'No accounts are suspended.'**
  String get moderationSuspendedEmpty;

  /// No description provided for @moderationSuspendedUnknownName.
  ///
  /// In en, this message translates to:
  /// **'Unknown user'**
  String get moderationSuspendedUnknownName;

  /// No description provided for @moderationLift.
  ///
  /// In en, this message translates to:
  /// **'Lift suspension'**
  String get moderationLift;

  /// No description provided for @moderationLiftTitle.
  ///
  /// In en, this message translates to:
  /// **'Lift this suspension?'**
  String get moderationLiftTitle;

  /// No description provided for @moderationLiftBody.
  ///
  /// In en, this message translates to:
  /// **'{name} will be able to post and message again. This is recorded in the audit log.'**
  String moderationLiftBody(String name);

  /// No description provided for @moderationLiftNotAllowed.
  ///
  /// In en, this message translates to:
  /// **'Only the owner can lift a suspension of a staff member.'**
  String get moderationLiftNotAllowed;

  /// No description provided for @moderationSuspendedReason.
  ///
  /// In en, this message translates to:
  /// **'Reason: {reason}'**
  String moderationSuspendedReason(String reason);

  /// No description provided for @moderationPendingEmpty.
  ///
  /// In en, this message translates to:
  /// **'No links are waiting for review.'**
  String get moderationPendingEmpty;

  /// No description provided for @moderationReportsEmpty.
  ///
  /// In en, this message translates to:
  /// **'No open reports.'**
  String get moderationReportsEmpty;

  /// No description provided for @moderationApprove.
  ///
  /// In en, this message translates to:
  /// **'Approve'**
  String get moderationApprove;

  /// No description provided for @moderationRemove.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get moderationRemove;

  /// No description provided for @moderationDismiss.
  ///
  /// In en, this message translates to:
  /// **'Dismiss'**
  String get moderationDismiss;

  /// No description provided for @moderationSuspend.
  ///
  /// In en, this message translates to:
  /// **'Suspend user'**
  String get moderationSuspend;

  /// No description provided for @moderationSuspendTitle.
  ///
  /// In en, this message translates to:
  /// **'Suspend this user?'**
  String get moderationSuspendTitle;

  /// No description provided for @moderationSuspendBody.
  ///
  /// In en, this message translates to:
  /// **'They will be signed out of posting and messaging until a staff member lifts the suspension.'**
  String get moderationSuspendBody;

  /// No description provided for @moderationReason.
  ///
  /// In en, this message translates to:
  /// **'Reason (kept in the audit log)'**
  String get moderationReason;

  /// No description provided for @moderationDone.
  ///
  /// In en, this message translates to:
  /// **'Done.'**
  String get moderationDone;

  /// No description provided for @moderationFailed.
  ///
  /// In en, this message translates to:
  /// **'The action failed. You may not have permission for this group.'**
  String get moderationFailed;

  /// No description provided for @moderationFrom.
  ///
  /// In en, this message translates to:
  /// **'From {name}'**
  String moderationFrom(String name);

  /// No description provided for @moderationReportLine.
  ///
  /// In en, this message translates to:
  /// **'{reason} · {type}'**
  String moderationReportLine(String reason, String type);

  /// No description provided for @reportTypeGroupMessage.
  ///
  /// In en, this message translates to:
  /// **'Group message'**
  String get reportTypeGroupMessage;

  /// No description provided for @reportTypeDirectMessage.
  ///
  /// In en, this message translates to:
  /// **'Private message'**
  String get reportTypeDirectMessage;

  /// No description provided for @reportTypeUser.
  ///
  /// In en, this message translates to:
  /// **'User'**
  String get reportTypeUser;

  /// No description provided for @communityNotAllowed.
  ///
  /// In en, this message translates to:
  /// **'You cannot do this right now.'**
  String get communityNotAllowed;

  /// No description provided for @communityOffline.
  ///
  /// In en, this message translates to:
  /// **'You appear to be offline. Try again when you are connected.'**
  String get communityOffline;

  /// No description provided for @stateLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading'**
  String get stateLoading;

  /// No description provided for @stateErrorTitle.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong'**
  String get stateErrorTitle;

  /// No description provided for @stateOffline.
  ///
  /// In en, this message translates to:
  /// **'You are offline. Some content may be out of date.'**
  String get stateOffline;

  /// No description provided for @notFoundTitle.
  ///
  /// In en, this message translates to:
  /// **'Page not found'**
  String get notFoundTitle;

  /// No description provided for @notFoundBody.
  ///
  /// In en, this message translates to:
  /// **'This page does not exist or has moved.'**
  String get notFoundBody;

  /// No description provided for @linkCommunityRules.
  ///
  /// In en, this message translates to:
  /// **'Community rules'**
  String get linkCommunityRules;

  /// No description provided for @linkPrivacy.
  ///
  /// In en, this message translates to:
  /// **'Privacy notice'**
  String get linkPrivacy;

  /// No description provided for @legalLastUpdated.
  ///
  /// In en, this message translates to:
  /// **'Last updated {date}'**
  String legalLastUpdated(String date);

  /// No description provided for @legalContactTitle.
  ///
  /// In en, this message translates to:
  /// **'Contact'**
  String get legalContactTitle;

  /// No description provided for @legalContactEmail.
  ///
  /// In en, this message translates to:
  /// **'Email: {email}'**
  String legalContactEmail(String email);

  /// No description provided for @legalDeletionPage.
  ///
  /// In en, this message translates to:
  /// **'Account deletion page: {url}'**
  String legalDeletionPage(String url);

  /// No description provided for @legalPolicyPage.
  ///
  /// In en, this message translates to:
  /// **'Privacy policy online: {url}'**
  String legalPolicyPage(String url);

  /// No description provided for @createAccountAcceptRules.
  ///
  /// In en, this message translates to:
  /// **'I have read and accept the community rules and the privacy notice.'**
  String get createAccountAcceptRules;

  /// No description provided for @errorAcceptRules.
  ///
  /// In en, this message translates to:
  /// **'Accept the community rules to create an account.'**
  String get errorAcceptRules;

  /// No description provided for @acceptRulesTitle.
  ///
  /// In en, this message translates to:
  /// **'Community rules'**
  String get acceptRulesTitle;

  /// No description provided for @acceptRulesBody.
  ///
  /// In en, this message translates to:
  /// **'Before you join groups or send messages, read and accept the community rules. They keep the community safe and useful for everyone.'**
  String get acceptRulesBody;

  /// No description provided for @acceptRulesRead.
  ///
  /// In en, this message translates to:
  /// **'Read the community rules'**
  String get acceptRulesRead;

  /// No description provided for @acceptRulesAccept.
  ///
  /// In en, this message translates to:
  /// **'I accept the rules'**
  String get acceptRulesAccept;

  /// No description provided for @acceptRulesNotNow.
  ///
  /// In en, this message translates to:
  /// **'Not now'**
  String get acceptRulesNotNow;

  /// No description provided for @acceptRulesFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not save your answer. Check your connection and try again.'**
  String get acceptRulesFailed;

  /// No description provided for @profileSectionLegal.
  ///
  /// In en, this message translates to:
  /// **'Rules and privacy'**
  String get profileSectionLegal;

  /// No description provided for @profileBlockedAccounts.
  ///
  /// In en, this message translates to:
  /// **'Blocked accounts'**
  String get profileBlockedAccounts;

  /// No description provided for @blockedTitle.
  ///
  /// In en, this message translates to:
  /// **'Blocked accounts'**
  String get blockedTitle;

  /// No description provided for @blockedHint.
  ///
  /// In en, this message translates to:
  /// **'Blocked people cannot message you, and their group messages are hidden from you.'**
  String get blockedHint;

  /// No description provided for @blockedEmpty.
  ///
  /// In en, this message translates to:
  /// **'You have not blocked anyone.'**
  String get blockedEmpty;

  /// No description provided for @blockedLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not load blocked accounts.'**
  String get blockedLoadFailed;

  /// No description provided for @blockedUnblockDone.
  ///
  /// In en, this message translates to:
  /// **'Unblocked.'**
  String get blockedUnblockDone;

  /// No description provided for @blockActionBlock.
  ///
  /// In en, this message translates to:
  /// **'Block {name}'**
  String blockActionBlock(String name);

  /// No description provided for @blockActionUnblock.
  ///
  /// In en, this message translates to:
  /// **'Unblock {name}'**
  String blockActionUnblock(String name);

  /// No description provided for @groupBlockConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'They will not be able to message you, and you will no longer see their messages in groups. You can unblock them in Profile.'**
  String get groupBlockConfirmBody;

  /// No description provided for @blockDone.
  ///
  /// In en, this message translates to:
  /// **'Blocked. You will no longer see their messages.'**
  String get blockDone;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
