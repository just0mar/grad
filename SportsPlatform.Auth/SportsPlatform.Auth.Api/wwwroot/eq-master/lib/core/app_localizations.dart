import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

/// Lightweight, codegen-free localization for the app.
///
/// Why hand-written instead of gen-l10n / .arb files: this compiles the moment
/// `flutter pub get` runs (it only needs `flutter_localizations` from the SDK),
/// with no `flutter gen-l10n` / build_runner step and no generated files to keep
/// in sync. Strings live in the [_values] map keyed by language code.
///
/// Usage in a widget:
///   final t = AppLocalizations.of(context);
///   Text(t.settings);
///
/// RTL is automatic: Flutter flips the layout to right-to-left whenever the
/// active locale is Arabic, because 'ar' is a known RTL language — no manual
/// [Directionality] needed as long as [MaterialApp.locale] / supportedLocales
/// are wired up (see main.dart).
class AppLocalizations {
  AppLocalizations(this.locale);

  final Locale locale;

  String get localeName => locale.languageCode;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  /// The single delegate to register in `MaterialApp.localizationsDelegates`.
  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// All locales the app ships translations for.
  static const List<Locale> supportedLocales = [
    Locale('en'),
    Locale('ar'),
  ];

  /// Full bundle of delegates to hand to `MaterialApp.localizationsDelegates`
  /// (our strings + Flutter's Material/Widgets/Cupertino localizations, which
  /// provide translated system widgets, date pickers, and correct text
  /// direction for Arabic).
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates = [
    AppLocalizations.delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ];

  /// Maps a saved/selected language code to a supported [Locale], defaulting to
  /// English for anything unrecognised.
  static Locale localeForCode(String code) {
    switch (code) {
      case 'ar':
        return const Locale('ar');
      case 'en':
      default:
        return const Locale('en');
    }
  }

  /// Human-readable name for a language code, shown in the language picker.
  static String displayName(String code) {
    switch (code) {
      case 'ar':
        return 'العربية';
      case 'en':
      default:
        return 'English';
    }
  }

  String get _code => locale.languageCode;

  String _t(String key) {
    return _values[_code]?[key] ?? _values['en']![key] ?? key;
  }

  // ── Settings ──────────────────────────────────────────────────────────────
  String get settings => _t('settings');
  String get language => _t('language');
  String get theme => _t('theme');
  String get lightMode => _t('lightMode');
  String get darkMode => _t('darkMode');
  String get myTeams => _t('myTeams');
  String get myClubs => _t('myClubs');
  String get noTeamsAvailable => _t('noTeamsAvailable');
  String get noClubsAvailable => _t('noClubsAvailable');
  String get teamMember => _t('teamMember');
  String get member => _t('member');
  String get termsOfPrivacy => _t('termsOfPrivacy');
  String get logOut => _t('logOut');
  String get logOutConfirm => _t('logOutConfirm');
  String get yesLogOut => _t('yesLogOut');
  String get leaveTeam => _t('leaveTeam');
  String get leaveClub => _t('leaveClub');

  // ── Common actions ────────────────────────────────────────────────────────
  String get cancel => _t('cancel');
  String get save => _t('save');
  String get delete => _t('delete');
  String get edit => _t('edit');
  String get leave => _t('leave');
  String get next => _t('next');
  String get back => _t('back');
  String get skip => _t('skip');
  String get ok => _t('ok');
  String get retry => _t('retry');
  String get orContinueWith => _t('orContinueWith');

  // ── Navigation tabs ───────────────────────────────────────────────────────
  String get home => _t('home');
  String get events => _t('events');
  String get team => _t('team');
  String get profile => _t('profile');
  String get messages => _t('messages');

  // ── Auth: login ───────────────────────────────────────────────────────────
  String get login => _t('login');
  String get loginTitle => _t('loginTitle');
  String get email => _t('email');
  String get emailOrPhone => _t('emailOrPhone');
  String get password => _t('password');
  String get forgotPassword => _t('forgotPassword');
  String get signIn => _t('signIn');
  String get signInWithGoogle => _t('signInWithGoogle');
  String get noAccount => _t('noAccount');
  String get createAccount => _t('createAccount');

  // ── Auth: reset password ──────────────────────────────────────────────────
  String get resetPassword => _t('resetPassword');
  String get resetPasswordEmailHint => _t('resetPasswordEmailHint');
  String get resetPasswordCodeHint => _t('resetPasswordCodeHint');
  String get sendCode => _t('sendCode');
  String get resendCode => _t('resendCode');
  String get sixDigitCode => _t('sixDigitCode');
  String get newPassword => _t('newPassword');
  String get confirmNewPassword => _t('confirmNewPassword');
  String get verifyCode => _t('verifyCode');
  String get useDifferentCode => _t('useDifferentCode');

  String chooseNewPasswordFor(String email) {
    if (_code == 'ar') return 'اختر كلمة مرور جديدة لـ $email.';
    return 'Choose a new password for $email.';
  }

  // ── Auth: signup & onboarding ─────────────────────────────────────────────
  String get signUpTitle => _t('signUpTitle');
  String get addPhotoOpt => _t('addPhotoOpt');
  String get nameLabel => _t('nameLabel');
  String get fullName => _t('fullName');
  String get usernameOpt => _t('usernameOpt');
  String get emailLabel => _t('emailLabel');
  String get phoneOpt => _t('phoneOpt');
  String get dobLabel => _t('dobLabel');
  String get dobLabelRequired => _t('dobLabelRequired');
  String get confirmPasswordLabel => _t('confirmPasswordLabel');
  String get finishSignUp => _t('finishSignUp');
  String get orSignUpWith => _t('orSignUpWith');
  String get signUpWithGoogle => _t('signUpWithGoogle');
  String get completeProfileTitle1 => _t('completeProfileTitle1');
  String get completeProfileTitle2 => _t('completeProfileTitle2');
  String get completeProfileDesc => _t('completeProfileDesc');
  String get completeProfileBtn => _t('completeProfileBtn');
  String get updateDetailsHint => _t('updateDetailsHint');
  String get congratsReady => _t('congratsReady');
  String get congratsExplore => _t('congratsExplore');
  String get congratsDesc => _t('congratsDesc');

  // ── Titles ──────────────────────────────────────────────────────────────
  String get titleSearch => _t('titleSearch');
  String get titleMessages => _t('titleMessages');

  // ── Home ────────────────────────────────────────────────────────────────
  String get homeAnnouncements => _t('homeAnnouncements');
  String get homeWelcome => _t('homeWelcome');
  String get homeClubSetup => _t('homeClubSetup');
  String get homeStartClub => _t('homeStartClub');
  String get homeCreateFirstTeam => _t('homeCreateFirstTeam');
  String get homeCreateFirstClub => _t('homeCreateFirstClub');
  String get homeAddFirstEvent => _t('homeAddFirstEvent');
  String get homeNoEvents => _t('homeNoEvents');
  String get homeTapToSchedule => _t('homeTapToSchedule');
  String get homeEventsAppearHere => _t('homeEventsAppearHere');
  String get homeNoAnnouncements => _t('homeNoAnnouncements');
  String get homeAddFirstAnnouncement => _t('homeAddFirstAnnouncement');
  String get homeAnnouncementsAppearHere => _t('homeAnnouncementsAppearHere');
  String get homeKeepTeamInLoop => _t('homeKeepTeamInLoop');
  String get deleteAnnouncementTitle => _t('deleteAnnouncementTitle');
  String get deleteAnnouncementDesc => _t('deleteAnnouncementDesc');
  String get homePickImage => _t('homePickImage');
  String get homeCaption => _t('homeCaption');
  String get homeUrgent => _t('homeUrgent');
  String get homeImportant => _t('homeImportant');
  String get homeNormal => _t('homeNormal');
  String get monday => _t('monday');
  String get tuesday => _t('tuesday');
  String get wednesday => _t('wednesday');
  String get thursday => _t('thursday');
  String get friday => _t('friday');
  String get saturday => _t('saturday');
  String get sunday => _t('sunday');
  String get eventsTitle => _t('eventsTitle');
  String get match => _t('match');
  String get training => _t('training');
  String get meeting => _t('meeting');
  String get test => _t('test');
  String get add => _t('add');
  String get noEventsOnThisDay => _t('noEventsOnThisDay');
  String get addEvent => _t('addEvent');

  // ── TeamView ────────────────────────────────────────────────────────────
  String get teamTitle => _t('teamTitle');
  String get teamMembers => _t('teamMembers');
  String get teamStats => _t('teamStats');
  String get teamPlans => _t('teamPlans');
  String get teamAddAnotherMember => _t('teamAddAnotherMember');
  String get teamChat => _t('teamChat');
  String get teamErrorStartConversation => _t('teamErrorStartConversation');
  String get teamLeaveTeam => _t('teamLeaveTeam');
  String get teamLeaveTeamPrompt => _t('teamLeaveTeamPrompt');
  String teamLeaveTeamDesc(String teamName) {
    if (_code == 'ar') return 'هل أنت متأكد أنك تريد مغادرة "$teamName"؟ ستفقد إمكانية الوصول إلى جميع بيانات وأحداث الفريق.';
    return 'Are you sure you want to leave "$teamName"? You\'ll lose access to all team data and events.';
  }
  String get teamNoMembers => _t('teamNoMembers');
  String teamInjuredPlayers(int count) {
    if (_code == 'ar') return '$count لاعب${count == 1 ? '' : 'ين'} مصاب${count == 1 ? '' : 'ين'}';
    return '$count injured player${count == 1 ? '' : 's'}';
  }
  String get teamMessageBtn => _t('teamMessageBtn');
  String get teamOpening => _t('teamOpening');
  String get teamMessageTeamBtn => _t('teamMessageTeamBtn');

  // ── ProfileView ──────────────────────────────────────────────────────────
  String get profileTitle => _t('profileTitle');
  String get profileUpdated => _t('profileUpdated');
  String get profileUpdateFailed => _t('profileUpdateFailed');
  String get profileRole => _t('profileRole');
  String get profileId => _t('profileId');
  String get profileAge => _t('profileAge');
  String get profileYrs => _t('profileYrs');
  String get profileExp => _t('profileExp');
  String get profileNA => _t('profileNA');
  String get profileNoBio => _t('profileNoBio');
  String get profileUser => _t('profileUser');
  String get profileName => _t('profileName');
  String get profileUsername => _t('profileUsername');
  String get profileBioLabel => _t('profileBioLabel');
  String get profileUsernameHint => _t('profileUsernameHint');
  String get profileBioHint => _t('profileBioHint');
  String get profileSaving => _t('profileSaving');
  String get profileSaveChanges => _t('profileSaveChanges');
  String get profileNoTeams => _t('profileNoTeams');
  String get profileNoCommonTeams => _t('profileNoCommonTeams');
  String profileUserTeams(String displayName) {
    if (_code == 'ar') return 'فرق ${displayName.toUpperCase()}';
    return "${displayName.toUpperCase()}'S TEAMS";
  }

  // ── MessagesView ────────────────────────────────────────────────────────
  String get messagesNoConversations => _t('messagesNoConversations');
  String get messagesPhoto => _t('messagesPhoto');
  String get messagesVideo => _t('messagesVideo');
  String get messagesVoiceNote => _t('messagesVoiceNote');
  String get messagesDocument => _t('messagesDocument');
  String get messagesLocation => _t('messagesLocation');
  String get messagesFile => _t('messagesFile');

  // ── AddClubView ────────────────────────────────────────────────────────
  String get addClubTitle => _t('addClubTitle');
  String get addClubLogoReq => _t('addClubLogoReq');
  String get addClubTapToSelect => _t('addClubTapToSelect');
  String get addClubName => _t('addClubName');
  String get addClubEstDate => _t('addClubEstDate');
  String get addClubSelectDate => _t('addClubSelectDate');
  String get addClubLocation => _t('addClubLocation');
  String get addClubCityCountry => _t('addClubCityCountry');
  String get addClubTapMap => _t('addClubTapMap');
  String get addClubCreating => _t('addClubCreating');
  String get addClubCreateClubBtn => _t('addClubCreateClubBtn');

  // ── AddTeamView ────────────────────────────────────────────────────────
  String get addTeamTitle => _t('addTeamTitle');
  String get addTeamName => _t('addTeamName');
  String get addTeamClub => _t('addTeamClub');
  String get addTeamCategory => _t('addTeamCategory');
  String get addTeamAdding => _t('addTeamAdding');
  String get addTeamAddTeamBtn => _t('addTeamAddTeamBtn');
  String get addTeamEnterName => _t('addTeamEnterName');
  String get addTeamChooseClubFirst => _t('addTeamChooseClubFirst');
  String get addTeamErrorCreate => _t('addTeamErrorCreate');

  // ── PlansView ────────────────────────────────────────────────────────────
  String get plansDeletePlanTitle => _t('plansDeletePlanTitle');
  String get plansDeletePlanDesc => _t('plansDeletePlanDesc');
  String get plansDelete => _t('plansDelete');
  String get plansOptions => _t('plansOptions');
  String get plansEdit => _t('plansEdit');
  String get plansNoPlansAdd => _t('plansNoPlansAdd');
  String get plansNoPlans => _t('plansNoPlans');
  String get plansAddPlanBtn => _t('plansAddPlanBtn');
  String get plansPlanTitle => _t('plansPlanTitle');
  String get plansCreatedBy => _t('plansCreatedBy');
  String get plansTeamStaff => _t('plansTeamStaff');
  String get plansNoDesc => _t('plansNoDesc');
  String get plansNoTactics => _t('plansNoTactics');
  String get plansDocuments => _t('plansDocuments');
  String get plansErrorOpenDoc => _t('plansErrorOpenDoc');
  String plansErrorOpenFile(String msg) {
    if (_code == 'ar') return 'تعذر فتح الملف: $msg';
    return 'Could not open file: $msg';
  }

  // ── AddPlansView ─────────────────────────────────────────────────────────
  String get addPlansTitleReq => _t('addPlansTitleReq');
  String get addPlansEditPlan => _t('addPlansEditPlan');
  String get addPlansAddPlan => _t('addPlansAddPlan');
  String get addPlansTitle => _t('addPlansTitle');
  String get addPlansOffensive => _t('addPlansOffensive');
  String get addPlansDefensive => _t('addPlansDefensive');
  String get addPlansDesc => _t('addPlansDesc');
  String get addPlansVisibility => _t('addPlansVisibility');
  String get addPlansOnlyMe => _t('addPlansOnlyMe');
  String get addPlansTeam => _t('addPlansTeam');
  String get addPlansAttachments => _t('addPlansAttachments');
  String get addPlansUploadedDocs => _t('addPlansUploadedDocs');
  String get addPlansUploaded => _t('addPlansUploaded');
  String get addPlansDiscard => _t('addPlansDiscard');
  String get addPlansTapToAttach => _t('addPlansTapToAttach');
  String get addPlansTapToAddAnother => _t('addPlansTapToAddAnother');
  String get addPlansTacticalBoard => _t('addPlansTacticalBoard');
  String get addPlansEdit => _t('addPlansEdit');
  String get addPlansYourTeam => _t('addPlansYourTeam');
  String get addPlansOpponent => _t('addPlansOpponent');
  String get addPlansSavePlay => _t('addPlansSavePlay');
  String get addPlansReset => _t('addPlansReset');
  String get addPlansUndo => _t('addPlansUndo');
  String get addPlansDone => _t('addPlansDone');
  String get addPlansPlayName => _t('addPlansPlayName');
  String get addPlansSave => _t('addPlansSave');
  String get addPlansSavedPlays => _t('addPlansSavedPlays');
  String get addPlansPresetPlays => _t('addPlansPresetPlays');
  String get addPlansSavePlanBtn => _t('addPlansSavePlanBtn');
  String get addPlansAddPlanBtn => _t('addPlansAddPlanBtn');

  // ── AddAnnouncementView ──────────────────────────────────────────────────
  String get addAnnounceTitle => _t('addAnnounceTitle');
  String get addAnnounceCaption => _t('addAnnounceCaption');
  String get addAnnounceUrgent => _t('addAnnounceUrgent');
  String get addAnnounceImportant => _t('addAnnounceImportant');
  String get addAnnounceNormal => _t('addAnnounceNormal');
  String get addAnnounceBtn => _t('addAnnounceBtn');
  String get addAnnouncePickImage => _t('addAnnouncePickImage');
  String get addAnnounceSuccess => _t('addAnnounceSuccess');

  // ── AddMembersView ───────────────────────────────────────────────────────
  String get addMembersInviteMember => _t('addMembersInviteMember');
  String get addMembersRoleTeamMgr => _t('addMembersRoleTeamMgr');
  String get addMembersRole => _t('addMembersRole');
  String get addMembersJersey => _t('addMembersJersey');
  String get addMembersPosition => _t('addMembersPosition');
  String get addMembersEmail => _t('addMembersEmail');
  String get addMembersSending => _t('addMembersSending');
  String get addMembersSendBtn => _t('addMembersSendBtn');
  String get addMembersClub => _t('addMembersClub');
  String get addMembersTeam => _t('addMembersTeam');
  String get addMembersNoTeams => _t('addMembersNoTeams');
  String get addMembersNoTeamsDesc => _t('addMembersNoTeamsDesc');
  String get addMembersCreateFirstTeam => _t('addMembersCreateFirstTeam');
  String get addMembersEmailReq => _t('addMembersEmailReq');
  String get addMembersValidJersey => _t('addMembersValidJersey');
  String get addMembersPosReq => _t('addMembersPosReq');
  String get addMembersErrClub => _t('addMembersErrClub');
  String addMembersSentClub(String email) => _t('addMembersSentClub').replaceAll('%s', email);
  String get addMembersErrSend => _t('addMembersErrSend');
  String get addMembersTeamReq => _t('addMembersTeamReq');
  String get addMembersErrClubTeam => _t('addMembersErrClubTeam');
  String addMembersSentTeam(String email, String role) => _t('addMembersSentTeam').replaceAll('%e', email).replaceAll('%r', role);

  String get rolePlayer => _t('rolePlayer');
  String get roleCoach => _t('roleCoach');
  String get roleFitnessCoach => _t('roleFitnessCoach');
  String get roleTeamAnalyst => _t('roleTeamAnalyst');
  String get roleTeamDoctor => _t('roleTeamDoctor');
  String get roleTeamManager => _t('roleTeamManager');
  String get roleClubManager => _t('roleClubManager');

  String get posPG => _t('posPG');
  String get posSG => _t('posSG');
  String get posSF => _t('posSF');
  String get posPF => _t('posPF');
  String get posC => _t('posC');

  // ── JoinTeamView / IncomingRequestsView ──────────────────────────────────
  String get joinNoPending => _t('joinNoPending');
  String get joinNoPendingDesc => _t('joinNoPendingDesc');
  String joinRole(String role) => _t('joinRole').replaceAll('%s', role);
  String get decline => _t('decline');
  String get accept => _t('accept');
  String get joinDetails => _t('joinDetails');
  String get joinTeamClub => _t('joinTeamClub');
  String get joinPosition => _t('joinPosition');
  String get joinJersey => _t('joinJersey');
  String get joinInvitedBy => _t('joinInvitedBy');
  String get joinManager => _t('joinManager');
  String get joinSentTo => _t('joinSentTo');
  String get joinStatus => _t('joinStatus');
  String get joinPending => _t('joinPending');
  String get joinNA => _t('joinNA');

  String get incNoTeamSelected => _t('incNoTeamSelected');
  String get incErrLoad => _t('incErrLoad');
  String incCancelled(String email) => _t('incCancelled').replaceAll('%s', email);
  String get incErrCancel => _t('incErrCancel');
  String get incNoPendingDesc => _t('incNoPendingDesc');

  // ── SearchView ───────────────────────────────────────────────────────────
  String get searchTitle => _t('searchTitle');
  String get searchHint => _t('searchHint');
  String get searchFilterTitle => _t('searchFilterTitle');
  String get searchMinChars => _t('searchMinChars');
  String get searchErrFailed => _t('searchErrFailed');
  String get searchNoResults => _t('searchNoResults');
  String get searchFilterAll => _t('searchFilterAll');
  String get searchFilterTeams => _t('searchFilterTeams');
  String get searchFilterUsers => _t('searchFilterUsers');
  String get searchFilterEvents => _t('searchFilterEvents');
  String get searchFilterPlans => _t('searchFilterPlans');
  String get searchFilterAnnouncements => _t('searchFilterAnnouncements');
  String get searchFilterStats => _t('searchFilterStats');

  // ── AskEqiupeIoView ──────────────────────────────────────────────────────
  String get askEqWelcome => _t('askEqWelcome');
  String get askEqPrompt => _t('askEqPrompt');
  String get askEqPickTeam => _t('askEqPickTeam');
  String get askEqNoAnswer => _t('askEqNoAnswer');
  String get askEqError => _t('askEqError');
  String get askEqTitle => _t('askEqTitle');
  String get askEqThinking => _t('askEqThinking');
  String get askEqTypeMsg => _t('askEqTypeMsg');
  String get askEqFileSoon => _t('askEqFileSoon');

  // ── NotificationsView ────────────────────────────────────────────────────
  String get notifJustNow => _t('notifJustNow');
  String notifMinsAgo(int m) => _t('notifMinsAgo').replaceAll('%d', m.toString());
  String notifHoursAgo(int h) => _t('notifHoursAgo').replaceAll('%d', h.toString());
  String notifDaysAgo(int d) => _t('notifDaysAgo').replaceAll('%d', d.toString());
  String get titleNotifications => _t('titleNotifications');
  String notifUnreadCount(int c) => _t('notifUnreadCount').replaceAll('%d', c.toString());
  String get notifAllCaughtUp => _t('notifAllCaughtUp');
  String get notifMarkAllRead => _t('notifMarkAllRead');
  String get notifEmpty => _t('notifEmpty');

  // ── SettingsView ────────────────────────────────────────────────────────
  String get leaveTeamTitle => _t('leaveTeamTitle');
  String leaveTeamDesc(String team) => _t('leaveTeamDesc').replaceAll('%s', team);
  String get leaveClubTitle => _t('leaveClubTitle');
  String leaveClubDesc(String club) => _t('leaveClubDesc').replaceAll('%s', club);
  String get errAccount => _t('errAccount');
  String leftClub(String club) => _t('leftClub').replaceAll('%s', club);
  String get errLeaveClub => _t('errLeaveClub');
  String get titleSettings => _t('titleSettings');
  
  String get termsTitle => _t('termsTitle');
  String get termsS1T => _t('termsS1T');
  String get termsS1B => _t('termsS1B');
  String get termsS2T => _t('termsS2T');
  String get termsS2B => _t('termsS2B');
  String get termsS3T => _t('termsS3T');
  String get termsS3B => _t('termsS3B');
  String get termsS4T => _t('termsS4T');
  String get termsS4B => _t('termsS4B');
  String get termsS5T => _t('termsS5T');
  String get termsS5B => _t('termsS5B');
  String get termsS6T => _t('termsS6T');
  String get termsS6B => _t('termsS6B');

  String get clubIdLabel => _t('clubIdLabel');
  String get clubLocationLabel => _t('clubLocationLabel');
  String get clubCoordinatesLabel => _t('clubCoordinatesLabel');
  String get notSetLabel => _t('notSetLabel');

  // ── PlayerProfileView ───────────────────────────────────────────────────
  String get newMedRecord => _t('newMedRecord');
  String get editMedRecord => _t('editMedRecord');
  String get injuryType => _t('injuryType');
  String get diagnosis => _t('diagnosis');
  String get recoveryTips => _t('recoveryTips');
  String get expReturnDate => _t('expReturnDate');
  String get create => _t('create');
  String get addFitnessRecordTitle => _t('addFitnessRecordTitle');
  String get recordName => _t('recordName');
  String get value => _t('value');
  String get requestDocument => _t('requestDocument');
  String get documentName => _t('documentName');
  String get noteToPlayer => _t('noteToPlayer');
  String get request => _t('request');
  String get titlePlayerBiometrics => _t('titlePlayerBiometrics');
  String get titleFitnessRecords => _t('titleFitnessRecords');
  String get titleMedicalRecords => _t('titleMedicalRecords');
  String get titlePlayerStats => _t('titlePlayerStats');
  String get titlePlayerVideos => _t('titlePlayerVideos');
  String get role => _t('role');
  String get jerseyNumber => _t('jerseyNumber');
  String get age => _t('age');
  String get position => _t('position');
  String get addARecord => _t('addARecord');
  String get addMedicalRecord => _t('addMedicalRecord');
  String get message => _t('message');
  String get opening => _t('opening');
  String get height => _t('height');
  String get weight => _t('weight');
  String get bmi => _t('bmi');
  String get bodyFat => _t('bodyFat');
  String updateMetric(String metric) => _t('updateMetric').replaceAll('%s', metric);
  String get update => _t('update');

  // ── TeamStats & GameHistory ────────────────────────────────────────────────
  String get editStats => _t('editStats');
  String get stat => _t('stat');
  String get lastGame => _t('lastGame');
  String get cumulative => _t('cumulative');
  String statistics(String teamName) => _t('statistics').replaceAll('%s', teamName);
  String get matches => _t('matches');
  String get trainingTeamStats => _t('trainingTeamStats');
  String get matchTeamStats => _t('matchTeamStats');
  String get title => _t('title');
  String get lastEntry => _t('lastEntry');
  String get gameHistoryTitle => _t('gameHistoryTitle');
  String vsOpponent(String opponent) => _t('vsOpponent').replaceAll('%s', opponent);
  String get gameStatsTitle => _t('gameStatsTitle');
  String get gameFilesTitle => _t('gameFilesTitle');
  String get gameVideosTitle => _t('gameVideosTitle');
  String get coachNotesTitle => _t('coachNotesTitle');
  String get open => _t('open');
  String get noCoachNotesYet => _t('noCoachNotesYet');
  String get writeNote => _t('writeNote');
  String get saveNote => _t('saveNote');
  String get uploadGameVideo => _t('uploadGameVideo');
  String get uploadingVideo => _t('uploadingVideo');
  String get videoUploaded => _t('videoUploaded');
  String get removeVideoTitle => _t('removeVideoTitle');
  String removeVideoDesc(String title) => _t('removeVideoDesc').replaceAll('%s', title);
  String get remove => _t('remove');
  String get noVideosYet => _t('noVideosYet');
  String get upload => _t('upload');
  String get postNote => _t('postNote');
  String get updateNoteTitle => _t('updateNoteTitle');
  String get originalStatsSheet => _t('originalStatsSheet');
  String get videoUnavailable => _t('videoUnavailable');
  String filePickerError(String e) => _t('filePickerError').replaceAll('%s', e);
  String get fileReadError => _t('fileReadError');
  String get videoTooLarge => _t('videoTooLarge');
  String get uploadGameVideoTitle => _t('uploadGameVideoTitle');
  String get titleOptional => _t('titleOptional');
  String statsPdfError(String e) => _t('statsPdfError').replaceAll('%s', e);
  String saveNoteError(String e) => _t('saveNoteError').replaceAll('%s', e);
  String get deleteNoteTitle => _t('deleteNoteTitle');
  String get deleteNoteDesc => _t('deleteNoteDesc');
  String deleteNoteError(String e) => _t('deleteNoteError').replaceAll('%s', e);
  String openFileError(String e) => _t('openFileError').replaceAll('%s', e);
  String openDocumentError(String e) => _t('openDocumentError').replaceAll('%s', e);
  String get uploadGameFileTitle => _t('uploadGameFileTitle');
  String get descOptional => _t('descOptional');
  String get fileUploaded => _t('fileUploaded');
  String fileUploadError(String e) => _t('fileUploadError').replaceAll('%s', e);
  String get uploading => _t('uploading');
  String get uploadGameFile => _t('uploadGameFile');
  String get noDocsUploaded => _t('noDocsUploaded');
  String get matchStatsPdf => _t('matchStatsPdf');

  // ── MatchDetailView ───────────────────────────────────────────────────────
  String get eventUpdated => _t('eventUpdated');
  String eventUpdateError(String e) => _t('eventUpdateError').replaceAll('%s', e);
  String get deleteEventTitle => _t('deleteEventTitle');
  String get eventDeleted => _t('eventDeleted');
  String eventDeleteError(String e) => _t('eventDeleteError').replaceAll('%s', e);
  String get squadSaved => _t('squadSaved');
  String squadSaveError(String e) => _t('squadSaveError').replaceAll('%s', e);
  String get attendanceSaved => _t('attendanceSaved');
  String attendanceSaveError(String e) => _t('attendanceSaveError').replaceAll('%s', e);
  String get noTeamVisiblePlans => _t('noTeamVisiblePlans');
  String loadPlansError(String e) => _t('loadPlansError').replaceAll('%s', e);
  String addPlanError(String e) => _t('addPlanError').replaceAll('%s', e);
  String get planAddedToMatch => _t('planAddedToMatch');
  String attachPlanError(String e) => _t('attachPlanError').replaceAll('%s', e);
  String get documentUploaded => _t('documentUploaded');
  String uploadFailed(String e) => _t('uploadFailed').replaceAll('%s', e);
  String get downloadingDocument => _t('downloadingDocument');
  String get documentDeleted => _t('documentDeleted');
  String deleteFailed(String e) => _t('deleteFailed').replaceAll('%s', e);
  String get openMapError => _t('openMapError');
  String startersCount(int count) => _t('startersCount').replaceAll('%s', count.toString());
  String reservesCount(int count) => _t('reservesCount').replaceAll('%s', count.toString());
  String statsUploadFailed(String e) => _t('statsUploadFailed').replaceAll('%s', e);
  String get statsSavedForMatch => _t('statsSavedForMatch');
  String saveStatsError(String e) => _t('saveStatsError').replaceAll('%s', e);
  String get deleteMatchStatsTitle => _t('deleteMatchStatsTitle');
  String get matchStatsDeleted => _t('matchStatsDeleted');
  String deleteStatsError(String e) => _t('deleteStatsError').replaceAll('%s', e);
  String openMatchStatsPdfError(String e) => _t('openMatchStatsPdfError').replaceAll('%s', e);
  String get player => _t('player');
  String get thisIsUs => _t('thisIsUs');

  // ── Missing Phase 7 Strings ──────────────────────────────────────────────
  String get selectAttributes => _t('selectAttributes');
  String get noVideoEndpoint => _t('noVideoEndpoint');
  String get removeVideoConfirm => _t('removeVideoConfirm');
  String get videoRemoved => _t('videoRemoved');
  String get videoRemoveError => _t('videoRemoveError');
  String get videoSizeLimit => _t('videoSizeLimit');
  String get uploadingVideoMsg => _t('uploadingVideoMsg');
  String get videoUploadFailed => _t('videoUploadFailed');
  String get uploadPlayerVideo => _t('uploadPlayerVideo');
  String get selectVideoFile => _t('selectVideoFile');
  String get record => _t('record');
  String get addFitnessRecord => _t('addFitnessRecord');
  String get editRecord => _t('editRecord');
  String get addRecord => _t('addRecord');
  String get documentUploadedSuccess => _t('documentUploadedSuccess');
  String get documentUploadFailed => _t('documentUploadFailed');
  String get documentDownloadFailed => _t('documentDownloadFailed');
  String get documentPreviewFailed => _t('documentPreviewFailed');
  String get medicalRecordSaved => _t('medicalRecordSaved');
  String saveRecordError(String e) => _t('saveRecordError').replaceAll('%s', e);
  String get addAnotherDocument => _t('addAnotherDocument');
  String get share => _t('share');
  String get usePin => _t('usePin');
  String get cannotOpen => _t('cannotOpen');
  String get couldNotOpen => _t('couldNotOpen');
  String get tryAgain => _t('tryAgain');
  String get couldNotStartRecording => _t('couldNotStartRecording');
  String get gettingLocation => _t('gettingLocation');
  String get couldNotGetLocation => _t('couldNotGetLocation');
  String get openingDocument => _t('openingDocument');
  String get openFileErrorMsg => _t('openFileErrorMsg');
  String get googleSignUpFailed => _t('googleSignUpFailed');
  String get profileImageUploadFailed => _t('profileImageUploadFailed');
  String get googleSignInFailed => _t('googleSignInFailed');
  String get pleaseEnterName => _t('pleaseEnterName');
  String get pleaseSelectDob => _t('pleaseSelectDob');
  String get addMapPin => _t('addMapPin');

  // ── Misc ────────────────────────────────────────────────────────────────
  String get titleJoinRequests => _t('titleJoinRequests');
  String get titleMyInvitations => _t('titleMyInvitations');
  String get titleAttendance => _t('titleAttendance');
  String get titleEquipo => _t('titleEquipo');
  String get titleAddTeam => _t('titleAddTeam');
  String get titleAnnouncement => _t('titleAnnouncement');
  String get titleInviteMember => _t('titleInviteMember');
  String get titleAddEvent => _t('titleAddEvent');
  String get titleEditEvent => _t('titleEditEvent');
  String get titleCreateClub => _t('titleCreateClub');

  // ── FAB & Menu ──────────────────────────────────────────────────────────
  String get fabAddAnnouncements => _t('fabAddAnnouncements');
  String get fabMyInvitations => _t('fabMyInvitations');
  String get fabAddMember => _t('fabAddMember');
  String get fabCreateTeam => _t('fabCreateTeam');
  String get fabSettings => _t('fabSettings');
  String get fabJoinTeam => _t('fabJoinTeam');
  String get fabAskEquipo => _t('fabAskEquipo');
  String get fabInjuredPlayers => _t('fabInjuredPlayers');

  // ── Home View ───────────────────────────────────────────────────────────

  // ── Onboarding ──────────────────────────────────────────────────────────
  String get obUniteTitle => _t('obUniteTitle');
  String get obUniteDesc => _t('obUniteDesc');
  String get obTacticalTitle => _t('obTacticalTitle');
  String get obTacticalDesc => _t('obTacticalDesc');
  String get obPeakTitle => _t('obPeakTitle');
  String get obPeakDesc => _t('obPeakDesc');
  String get obLetsStart => _t('obLetsStart');

  static const Map<String, Map<String, String>> _values = {
    'en': {
      // Settings
      'settings': 'Settings',
      'language': 'Language',
      'theme': 'Theme',
      'lightMode': 'Light',
      'darkMode': 'Dark',
      'myTeams': 'My Teams',
      'myClubs': 'My Clubs',
      'noTeamsAvailable': 'No teams available',
      'noClubsAvailable': 'No clubs available',
      'teamMember': 'Team member',
      'member': 'Member',
      'termsOfPrivacy': 'Terms of privacy',
      'logOut': 'Log out',
      'logOutConfirm': 'Are you sure you want\nto log out ?',
      'yesLogOut': 'Yes Log out',
      'leaveTeam': 'Leave team',
      'leaveClub': 'Leave Club',
      // Common
      'cancel': 'Cancel',
      'save': 'Save',
      'delete': 'Delete',
      'edit': 'Edit',
      'leave': 'Leave',
      'next': 'Next',
      'back': 'Back',
      'skip': 'Skip',
      'ok': 'OK',
      'retry': 'Retry',
      'orContinueWith': 'or continue with',
      // Nav
      'home': 'Home',
      'events': 'Events',
      'team': 'Team',
      'profile': 'Profile',
      'messages': 'Messages',
      // Login
      'login': 'LOG IN',
      'loginTitle': 'WELCOME BACK',
      'email': 'Email',
      'emailOrPhone': 'Email / Phone number',
      'password': 'Password',
      'forgotPassword': 'Forgot password?',
      'signIn': 'Sign in',
      'signInWithGoogle': 'Sign in with Google',
      'noAccount': "Don't have an account?",
      'createAccount': 'Create Account',
      // Reset
      'resetPassword': 'Reset password',
      'resetPasswordEmailHint': "Enter the email linked to your account and we'll send you a 6-digit code.",
      'resetPasswordCodeHint': 'Enter the code we emailed you and choose a new password.',
      'sendCode': 'Send code',
      'resendCode': 'Resend code',
      'sixDigitCode': '6-digit code',
      'newPassword': 'New password',
      'confirmNewPassword': 'Confirm new password',
      'verifyCode': 'Verify code',
      'useDifferentCode': 'Use a different code',
      // Signup & Complete Profile
      'signUpTitle': 'SIGN UP',
      'addPhotoOpt': 'Add a photo (optional)',
      'nameLabel': 'Name',
      'fullName': 'Full name',
      'usernameOpt': 'Username (optional)',
      'emailLabel': 'Email',
      'phoneOpt': 'Phone number (optional)',
      'dobLabel': 'Date of birth',
      'dobLabelRequired': 'Date of birth *',
      'confirmPasswordLabel': 'Confirm Password',
      'finishSignUp': 'Finish sign up',
      'orSignUpWith': 'or sign up with',
      'signUpWithGoogle': 'Sign up with Google',
      'completeProfileTitle1': 'Complete',
      'completeProfileTitle2': 'profile',
      'completeProfileDesc': 'Just a couple more details to get you started.',
      'completeProfileBtn': 'Complete profile',
      'updateDetailsHint': 'You can update these details later in your profile.',
      'congratsReady': "You're all ready to go",
      'congratsExplore': 'Start Exploring',
      'congratsDesc': "Sign-up complete. You've taken the first step toward smarter, better-connected team management.",
      // Titles
      'titleSearch': 'Search',
      'titleMessages': 'Messages',
      'homeAnnouncements': 'ANNOUNCEMENTS',
      'homeWelcome': 'Welcome to Equipex!',
      'homeClubSetup': 'Your club is set up. Now create your first team to get started.',
      'homeStartClub': 'Start by creating your club to build your sports community.',
      'homeCreateFirstTeam': 'Create Your First Team',
      'homeCreateFirstClub': 'Create Your First Club',
      'homeAddFirstEvent': 'Add your first event',
      'homeNoEvents': 'There are no events yet',
      'homeTapToSchedule': 'Tap to schedule a match, training, or meeting.',
      'homeEventsAppearHere': 'Events will appear here once your manager schedules them.',
      'homeNoAnnouncements': 'No announcements yet',
      'homeAddFirstAnnouncement': 'Add your first announcement',
      'homeAnnouncementsAppearHere': 'Announcements from your team will show up here.',
      'homeKeepTeamInLoop': 'Keep your team in the loop — post an update or alert.',
      'deleteAnnouncementTitle': 'Delete announcement?',
      'deleteAnnouncementDesc': 'This announcement will be removed for the whole team.',
      'homePickImage': 'Pick a new image',
      'homeCaption': 'Caption',
      'homeUrgent': 'Urgent',
      'homeImportant': 'Important',
      'homeNormal': 'Normal',
      'monday': 'Monday',
      'tuesday': 'Tuesday',
      'wednesday': 'Wednesday',
      'thursday': 'Thursday',
      'friday': 'Friday',
      'saturday': 'Saturday',
      'sunday': 'Sunday',
      'eventsTitle': 'EVENTS',
      'match': 'Match',
      'training': 'Training',
      'meeting': 'Meeting',
      'test': 'Test',
      'add': 'Add',
      'noEventsOnThisDay': 'No events on this day',
      'addEvent': 'Add event',
      // TeamView
      'teamTitle': 'Team',
      'teamMembers': 'Members',
      'teamStats': 'Stats',
      'teamPlans': 'Plans',
      'teamAddAnotherMember': 'Add another team member to start chat.',
      'teamChat': 'Team Chat',
      'teamErrorStartConversation': 'Could not start conversation.',
      'teamLeaveTeam': 'Leave Team',
      'teamLeaveTeamPrompt': 'Leave Team?',
      'teamNoMembers': 'No members yet. Add members from the menu.',
      'teamMessageBtn': 'Message',
      'teamOpening': 'Opening...',
      'teamMessageTeamBtn': 'Message Team',
      // ProfileView
      'profileTitle': 'My Profile',
      'profileUpdated': 'Profile updated successfully!',
      'profileUpdateFailed': "We couldn't update your profile. Please try again.",
      'profileRole': 'Role',
      'profileId': 'ID',
      'profileAge': 'Age',
      'profileYrs': 'yrs',
      'profileExp': 'Years of experience',
      'profileNA': 'N/A',
      'profileNoBio': 'No bio yet.',
      'profileUser': 'User',
      'profileName': 'Name',
      'profileUsername': 'Username',
      'profileBioLabel': 'Bio',
      'profileUsernameHint': '@username',
      'profileBioHint': 'Tell us about yourself...',
      'profileSaving': 'Saving...',
      'profileSaveChanges': 'Save changes',
      'profileNoTeams': 'No teams yet.',
      'profileNoCommonTeams': 'No common teams.',
      // MessagesView
      'messagesNoConversations': 'No conversations yet.',
      'messagesPhoto': 'Photo',
      'messagesVideo': 'Video',
      'messagesVoiceNote': 'Voice note',
      'messagesDocument': 'Document',
      'messagesLocation': 'Location',
      'messagesFile': 'File',
      // AddClubView
      'addClubTitle': 'CREATE CLUB',
      'addClubLogoReq': 'Club logo is required',
      'addClubTapToSelect': 'Tap to select a club logo',
      'addClubName': 'Club Name',
      'addClubEstDate': 'Established Date (optional)',
      'addClubSelectDate': 'Select date',
      'addClubLocation': 'Location (optional)',
      'addClubCityCountry': 'City, Country',
      'addClubTapMap': 'Tap the map icon to add a pin',
      'addClubCreating': 'Creating...',
      'addClubCreateClubBtn': 'Create Club',
      // AddTeamView
      'addTeamTitle': 'ADD TEAM',
      'addTeamName': 'Team Name',
      'addTeamClub': 'Club',
      'addTeamCategory': 'Team Category',
      'addTeamAdding': 'Adding...',
      'addTeamAddTeamBtn': 'Add Team',
      'addTeamEnterName': 'Please enter a team name.',
      'addTeamChooseClubFirst': 'Choose a club and category first.',
      'addTeamErrorCreate': 'Could not create team.',
      // PlansView
      'plansDeletePlanTitle': 'Delete plan?',
      'plansDeletePlanDesc': 'This plan will be removed. This action cannot be undone.',
      'plansDelete': 'Delete',
      'plansOptions': 'Plan options',
      'plansEdit': 'Edit',
      'plansNoPlansAdd': 'No plans yet.\nTap + to add one.',
      'plansNoPlans': 'No plans yet.',
      'plansAddPlanBtn': 'Add a plan',
      'plansPlanTitle': 'Plan',
      'plansCreatedBy': 'Created by',
      'plansTeamStaff': 'team staff',
      'plansNoDesc': 'No description',
      'plansNoTactics': 'No tactics saved',
      'plansDocuments': 'Documents',
      'plansErrorOpenDoc': 'Could not open document.',
      // AddPlansView
      'addPlansTitleReq': 'Plan title is required.',
      'addPlansEditPlan': 'Edit Plan',
      'addPlansAddPlan': 'Add Plan',
      'addPlansTitle': 'Title',
      'addPlansOffensive': 'Offensive',
      'addPlansDefensive': 'Defensive',
      'addPlansDesc': 'Description',
      'addPlansVisibility': 'Visibility',
      'addPlansOnlyMe': 'Only me',
      'addPlansTeam': 'Team',
      'addPlansAttachments': 'Attachments',
      'addPlansUploadedDocs': 'Uploaded documents',
      'addPlansUploaded': 'Uploaded',
      'addPlansDiscard': 'Discard',
      'addPlansTapToAttach': 'Tap here to attach documents\n(PDF, JPG, PNG, DOC, DOCX)',
      'addPlansTapToAddAnother': 'Tap to add another attachment',
      'addPlansTacticalBoard': 'Tactical Board',
      'addPlansEdit': 'Edit',
      'addPlansYourTeam': 'Your team',
      'addPlansOpponent': 'Opponent',
      'addPlansSavePlay': 'Save play',
      'addPlansReset': 'Reset',
      'addPlansUndo': 'Undo',
      'addPlansDone': 'Done',
      'addPlansPlayName': 'Play name',
      'addPlansSave': 'Save',
      'addPlansSavedPlays': 'Saved Plays',
      'addPlansPresetPlays': 'Preset Plays',
      'addPlansSavePlanBtn': 'Save plan',
      'addPlansAddPlanBtn': 'Add plan',
      // AddAnnouncementView
      'addAnnounceTitle': 'Announcement',
      'addAnnounceCaption': 'Announcement caption',
      'addAnnounceUrgent': 'Urgent',
      'addAnnounceImportant': 'Important',
      'addAnnounceNormal': 'Normal',
      'addAnnounceBtn': 'Add announcement',
      'addAnnouncePickImage': 'Pick announcement image',
      'addAnnounceSuccess': 'Announcement added successfully',
      // AddMembersView
      'addMembersInviteMember': 'Invite Member',
      'addMembersRoleTeamMgr': 'Role: Team Manager',
      'addMembersRole': 'Role',
      'addMembersJersey': 'Jersey number',
      'addMembersPosition': 'Player position',
      'addMembersEmail': 'Email address',
      'addMembersSending': 'Sending...',
      'addMembersSendBtn': 'Send Invitation',
      'addMembersClub': 'Club',
      'addMembersTeam': 'Team',
      'addMembersNoTeams': 'No Teams Yet',
      'addMembersNoTeamsDesc': 'Your club is set up. Now create your first team to get started.',
      'addMembersCreateFirstTeam': 'Create Your First Team',
      'addMembersEmailReq': 'Please enter an email address.',
      'addMembersValidJersey': 'Enter a valid jersey number (1-999).',
      'addMembersPosReq': 'Please select a player position.',
      'addMembersErrClub': 'Cannot determine club for this invitation.',
      'addMembersSentClub': 'Invitation sent to %s as Team Manager!',
      'addMembersErrSend': 'Could not send invitation.',
      'addMembersTeamReq': 'Please select a team first.',
      'addMembersErrClubTeam': 'Cannot determine club for this team.',
      'addMembersSentTeam': 'Invitation sent to %e as %r!',
      'rolePlayer': 'Player',
      'roleCoach': 'Coach',
      'roleFitnessCoach': 'Fitness Coach',
      'roleTeamAnalyst': 'Team Analyst',
      'roleTeamDoctor': 'Team Doctor',
      'roleTeamManager': 'Team Manager',
      'roleClubManager': 'Club Manager',
      'posPG': 'Point Guard',
      'posSG': 'Shooting Guard',
      'posSF': 'Small Forward',
      'posPF': 'Power Forward',
      'posC': 'Center',
      // JoinTeamView / IncomingRequestsView
      'joinNoPending': 'No pending invitations',
      'joinNoPendingDesc': 'When a manager invites you to join a team,\nit will appear here.',
      'joinRole': 'Role: %s',
      'decline': 'Decline',
      'accept': 'Accept',
      'joinDetails': 'Invitation Details',
      'joinTeamClub': 'Team / Club',
      'joinPosition': 'Position',
      'joinJersey': 'Jersey Number',
      'joinInvitedBy': 'Invited By',
      'joinManager': 'Manager',
      'joinSentTo': 'Sent To',
      'joinStatus': 'Status',
      'joinPending': 'Pending',
      'joinNA': 'N/A',
      'incNoTeamSelected': 'No team selected.',
      'incErrLoad': 'Could not load invitations.',
      'incCancelled': 'Invitation for %s cancelled.',
      'incErrCancel': 'Could not cancel invitation.',
      'incNoPendingDesc': 'Invitations you send will appear here.',
      // SearchView
      'searchTitle': 'Search',
      'searchHint': 'Search teams, users, events...',
      'searchFilterTitle': 'Filter by type',
      'searchMinChars': 'Type at least two characters.',
      'searchErrFailed': 'Search failed. Please try again.',
      'searchNoResults': 'No results found.',
      'searchFilterAll': 'All',
      'searchFilterTeams': 'Teams',
      'searchFilterUsers': 'Users',
      'searchFilterEvents': 'Events',
      'searchFilterPlans': 'Plans',
      'searchFilterAnnouncements': 'Announcements',
      'searchFilterStats': 'Stats',
      // AskEqiupeIoView
      'askEqWelcome': 'Welcome to Ask Equipo! 🚀',
      'askEqPrompt': "Ask me about your team's matches, top scorers, predictions, or who's injured.",
      'askEqPickTeam': 'Pick a team first (use the team switcher above), then ask away.',
      'askEqNoAnswer': "I didn't get an answer for that. Try rephrasing?",
      'askEqError': 'The assistant is unavailable right now. Please try again.',
      'askEqTitle': 'Equipo',
      'askEqThinking': 'Equipo is thinking…',
      'askEqTypeMsg': 'Type your message...',
      'askEqFileSoon': 'File attachment coming soon...',
      // NotificationsView
      'notifJustNow': 'Just now',
      'notifMinsAgo': '%dm ago',
      'notifHoursAgo': '%dh ago',
      'notifDaysAgo': '%dd ago',
      'titleNotifications': 'Notifications',
      'notifUnreadCount': '%d unread',
      'notifAllCaughtUp': 'All caught up',
      'notifMarkAllRead': 'Mark all read',
      'notifEmpty': 'No notifications yet.',
      // SettingsView
      'leaveTeamTitle': 'Leave Team?',
      'leaveTeamDesc': 'Are you sure you want to leave "%s"? You\'ll lose access to all team data and events.',
      'leaveClubTitle': 'Leave Club?',
      'leaveClubDesc': 'Are you sure you want to leave "%s"? You may lose access to club teams, events, and data.',
      'errAccount': 'Could not identify account.',
      'leftClub': 'You have left %s',
      'errLeaveClub': 'Could not leave club.',
      'titleSettings': 'SETTINGS',
      'termsTitle': 'Terms of Privacy',
      'termsS1T': '1. Account information',
      'termsS1B': 'Equipo stores the profile information you provide, such as your name, email, username, role, profile image, and sports profile details, so your club and team experience can work correctly.',
      'termsS2T': '2. Club and team data',
      'termsS2B': 'Your memberships, teams, clubs, events, plans, announcements, attendance, medical, fitness, and performance records are used only to provide features to authorized members of your sports organization.',
      'termsS3T': '3. Private records',
      'termsS3B': 'Medical and fitness information should only be accessed by roles that are allowed to manage or review it. Do not share another member\'s private information outside the app without permission.',
      'termsS4T': '4. Files and media',
      'termsS4B': 'Uploaded images, videos, PDFs, and documents may be stored so they can be displayed, reviewed, or shared with the relevant team or club members inside the platform.',
      'termsS5T': '5. Your responsibility',
      'termsS5B': 'You agree to keep your login details secure, use the platform respectfully, and only upload content that you have the right to share.',
      'termsS6T': '6. Updates',
      'termsS6B': 'These terms may be updated as the platform evolves. Continued use of the app means you accept the current terms shown here.',
      'clubIdLabel': 'Club ID',
      'clubLocationLabel': 'Location',
      'clubCoordinatesLabel': 'Coordinates',
      'notSetLabel': 'Not set',
      // PlayerProfileView
      'newMedRecord': 'New Medical Record',
      'editMedRecord': 'Edit Medical Record',
      'injuryType': 'Injury type',
      'diagnosis': 'Diagnosis',
      'recoveryTips': 'Recovery tips',
      'expReturnDate': 'Expected return date',
      'create': 'Create',
      'addFitnessRecordTitle': 'Add Fitness Record',
      'recordName': 'Record name',
      'value': 'Value',
      'requestDocument': 'Request Document',
      'documentName': 'Document name',
      'noteToPlayer': 'Note to player',
      'request': 'Request',
      'titlePlayerBiometrics': 'PLAYER BIOMETRICS',
      'titleFitnessRecords': 'FITNESS RECORDS',
      'titleMedicalRecords': 'MEDICAL RECORDS',
      'titlePlayerStats': 'PLAYER STATS',
      'titlePlayerVideos': 'PLAYER VIDEOS',
      'role': 'Role',
      'jerseyNumber': 'Jersey Number',
      'age': 'Age',
      'position': 'Position',
      'addARecord': 'Add a record',
      'addMedicalRecord': 'Add medical record',
      'message': 'Message',
      'opening': 'Opening...',
      'height': 'Height',
      'weight': 'Weight',
      'bmi': 'BMI',
      'bodyFat': 'Body Fat',
      'updateMetric': 'Update %s',
      'update': 'Update',
      // TeamStats & GameHistory
      'editStats': 'Edit Stats',
      'stat': 'Stat',
      'lastGame': 'Last Game',
      'cumulative': 'Cumulative',
      'statistics': '%s Statistics',
      'matches': 'Matches',
      'trainingTeamStats': 'TRAINING TEAM STATS',
      'matchTeamStats': 'MATCH TEAM STATS',
      'title': 'Title',
      'lastEntry': 'Last entry',
      'gameHistoryTitle': 'GAME HISTORY',
      'vsOpponent': 'Vs %s',
      'gameStatsTitle': 'GAME STATS',
      'gameFilesTitle': 'GAME FILES',
      'gameVideosTitle': 'GAME VIDEOS',
      'coachNotesTitle': 'COACH NOTES',
      'open': 'open',
      'noCoachNotesYet': 'No coach notes yet.',
      'writeNote': 'Write a note...',
      'saveNote': 'Save Note',
      'uploadGameVideo': 'Upload Game Video',
      'uploadingVideo': 'Uploading video... this may take a moment.',
      'videoUploaded': 'Video uploaded.',
      'removeVideoTitle': 'Remove video?',
      'removeVideoDesc': '"%s" will be removed from this game.',
      'remove': 'Remove',
      'noVideosYet': 'No videos yet.',
      'upload': 'Upload',
      'postNote': 'Post Note',
      'updateNoteTitle': 'Update Note',
      'originalStatsSheet': 'Original stats sheet',
      'videoUnavailable': 'This video is unavailable.',
      'filePickerError': 'Could not open the file picker: %s',
      'fileReadError': 'Could not read the selected file.',
      'videoTooLarge': 'That video is larger than 500 MB.',
      'uploadGameVideoTitle': 'Upload game video',
      'titleOptional': 'Title (optional)',
      'statsPdfError': 'Could not open stats PDF: %s',
      'saveNoteError': 'Could not save note: %s',
      'deleteNoteTitle': 'Delete note?',
      'deleteNoteDesc': 'This note will be permanently removed.',
      'deleteNoteError': 'Could not delete note: %s',
      'openFileError': 'Could not open file: %s',
      'openDocumentError': 'Could not open document: %s',
      'uploadGameFileTitle': 'Upload game file',
      'descOptional': 'Description (optional)',
      'fileUploaded': 'File uploaded.',
      'fileUploadError': 'Could not upload file: %s',
      'uploading': 'Uploading...',
      'uploadGameFile': 'Upload Game File',
      'noDocsUploaded': 'No documents uploaded.',
      'matchStatsPdf': 'Match stats sheet.pdf',
      // MatchDetailView
      'eventUpdated': 'Event updated.',
      'eventUpdateError': 'Could not update event: %s',
      'deleteEventTitle': 'Delete event?',
      'eventDeleted': 'Event deleted.',
      'eventDeleteError': 'Could not delete event: %s',
      'squadSaved': 'Squad saved successfully!',
      'squadSaveError': 'Failed to save squad: %s',
      'attendanceSaved': 'Attendance saved!',
      'attendanceSaveError': 'Failed to save attendance: %s',
      'noTeamVisiblePlans': 'No team-visible plans available.',
      'loadPlansError': 'Could not load plans: %s',
      'addPlanError': 'Could not add plan: %s',
      'planAddedToMatch': 'Plan added to match.',
      'attachPlanError': 'Could not attach plan: %s',
      'documentUploaded': 'Document uploaded!',
      'uploadFailed': 'Upload failed: %s',
      'downloadingDocument': 'Downloading document...',
      'documentDeleted': 'Document deleted.',
      'deleteFailed': 'Delete failed: %s',
      'openMapError': 'Could not open map',
      'startersCount': 'Starters (%s)',
      'reservesCount': 'Reserves (%s)',
      'statsUploadFailed': 'Stats upload failed: %s',
      'statsSavedForMatch': 'Stats saved for this match.',
      'saveStatsError': 'Could not save stats: %s',
      'deleteMatchStatsTitle': 'Delete match stats?',
      'matchStatsDeleted': 'Match stats deleted.',
      'deleteStatsError': 'Could not delete stats: %s',
      'openMatchStatsPdfError': 'Could not open the match stats PDF: %s',
      'player': 'Player',
      'thisIsUs': 'This is us',
      // Missing Phase 7 Strings
      'selectAttributes': 'Select attributes',
      'noVideoEndpoint': 'The backend has no analysis video upload endpoint yet.',
      'removeVideoConfirm': 'Remove "%s"? This cannot be undone.',
      'videoRemoved': 'Video removed.',
      'videoRemoveError': 'Could not remove the video.',
      'videoSizeLimit': 'Video is too large. The maximum size is 500 MB.',
      'uploadingVideoMsg': 'Uploading video...',
      'videoUploadFailed': 'Could not upload the video.',
      'uploadPlayerVideo': 'Upload Player Video',
      'selectVideoFile': 'Select Video File',
      'record': 'Record',
      'addFitnessRecord': 'Add Fitness Record',
      'editRecord': 'Edit record',
      'addRecord': 'Add Record',
      'documentUploadedSuccess': 'Document uploaded successfully.',
      'documentUploadFailed': 'Could not upload document.',
      'documentDownloadFailed': 'Could not download document.',
      'documentPreviewFailed': 'Could not preview document.',
      'medicalRecordSaved': 'Medical record saved.',
      'saveRecordError': 'Could not save record: %s',
      'addAnotherDocument': 'Add another document',
      'share': 'Share',
      'usePin': 'Use pin',
      'cannotOpen': 'Cannot open %s.',
      'couldNotOpen': 'Could not open this %s.',
      'tryAgain': 'Try again',
      'couldNotStartRecording': 'Could not start recording',
      'gettingLocation': 'Getting current location...',
      'couldNotGetLocation': 'Could not get location: %s',
      'openingDocument': 'Opening document...',
      'openFileErrorMsg': 'Could not open file: %s',
      'googleSignUpFailed': 'Google sign-up failed: %s',
      'profileImageUploadFailed': 'Profile image upload failed.',
      'googleSignInFailed': 'Google sign-in failed: %s',
      'pleaseEnterName': 'Please enter your name (at least 2 characters).',
      'pleaseSelectDob': 'Please select your date of birth.',
      'addMapPin': 'Add map pin',
      // Misc
      'titleJoinRequests': 'Join Requests',
      'titleMyInvitations': 'My Invitations',
      'titleAttendance': 'Attendance',
      'titleEquipo': 'Equipo',
      'titleAddTeam': 'ADD TEAM',
      'titleAnnouncement': 'Announcement',
      'titleInviteMember': 'Invite Member',
      'titleAddEvent': 'ADD EVENT',
      'titleEditEvent': 'EDIT EVENT',
      'titleCreateClub': 'CREATE CLUB',
      // FAB
      'fabAddAnnouncements': 'Add Announcements',
      'fabMyInvitations': 'My Invitations',
      'fabAddMember': 'Add Member',
      'fabCreateTeam': 'Create Team',
      'fabSettings': 'Settings',
      'fabJoinTeam': 'Join Team',
      'fabAskEquipo': 'Ask Equipo',
      'fabInjuredPlayers': 'Injured Players',
      // Home
      // Onboarding
      'obUniteTitle': 'Unite Your Entire Squad',
      'obUniteDesc': 'Seamlessly connect Coaches, Players, Doctors, and Analysts in one centralized hub.',
      'obTacticalTitle': 'Tactical Insights',
      'obTacticalDesc': 'Empower your analysts and coaches with deep insights and real-time report exchange.',
      'obPeakTitle': 'Peak Player Condition',
      'obPeakDesc': 'Keep your team game-ready with updated medical reports and fitness tracking.',
      'obLetsStart': "Let's Start",
    },
    'ar': {
      // Settings
      'settings': 'الإعدادات',
      'language': 'اللغة',
      'theme': 'المظهر',
      'lightMode': 'فاتح',
      'darkMode': 'داكن',
      'myTeams': 'فِرَقي',
      'myClubs': 'أنديتي',
      'noTeamsAvailable': 'لا توجد فرق متاحة',
      'noClubsAvailable': 'لا توجد أندية متاحة',
      'teamMember': 'عضو في الفريق',
      'member': 'عضو',
      'termsOfPrivacy': 'سياسة الخصوصية',
      'logOut': 'تسجيل الخروج',
      'logOutConfirm': 'هل أنت متأكد أنك تريد\nتسجيل الخروج؟',
      'yesLogOut': 'نعم، تسجيل الخروج',
      'leaveTeam': 'مغادرة الفريق',
      'leaveClub': 'مغادرة النادي',
      // Common
      'cancel': 'إلغاء',
      'save': 'حفظ',
      'delete': 'حذف',
      'edit': 'تعديل',
      'leave': 'مغادرة',
      'next': 'التالي',
      'back': 'رجوع',
      'skip': 'تخطّي',
      'ok': 'حسناً',
      'retry': 'إعادة المحاولة',
      'orContinueWith': 'أو المتابعة باستخدام',
      // Nav
      'home': 'الرئيسية',
      'events': 'الأحداث',
      'team': 'الفريق',
      'profile': 'الملف الشخصي',
      'messages': 'الرسائل',
      // Login
      'login': 'تسجيل الدخول',
      'loginTitle': 'مرحباً بعودتك',
      'email': 'البريد الإلكتروني',
      'emailOrPhone': 'البريد الإلكتروني أو الهاتف',
      'password': 'كلمة المرور',
      'forgotPassword': 'هل نسيت كلمة المرور؟',
      'signIn': 'تسجيل الدخول',
      'signInWithGoogle': 'الدخول عبر جوجل',
      'noAccount': 'ليس لديك حساب؟',
      'createAccount': 'إنشاء حساب',
      // Reset
      'resetPassword': 'إعادة تعيين كلمة المرور',
      'resetPasswordEmailHint': 'أدخل البريد الإلكتروني المرتبط بحسابك وسنرسل لك رمزاً من 6 أرقام.',
      'resetPasswordCodeHint': 'أدخل الرمز الذي أرسلناه إليك واختر كلمة مرور جديدة.',
      'sendCode': 'إرسال الرمز',
      'resendCode': 'إعادة إرسال الرمز',
      'sixDigitCode': 'رمز من 6 أرقام',
      'newPassword': 'كلمة المرور الجديدة',
      'confirmNewPassword': 'تأكيد كلمة المرور الجديدة',
      'verifyCode': 'التحقق من الرمز',
      'useDifferentCode': 'استخدام رمز مختلف',
      // Signup & Complete Profile
      'signUpTitle': 'إنشاء حساب',
      'addPhotoOpt': 'إضافة صورة (اختياري)',
      'nameLabel': 'الاسم',
      'fullName': 'الاسم الكامل',
      'usernameOpt': 'اسم المستخدم (اختياري)',
      'emailLabel': 'البريد الإلكتروني',
      'phoneOpt': 'رقم الهاتف (اختياري)',
      'dobLabel': 'تاريخ الميلاد',
      'dobLabelRequired': 'تاريخ الميلاد *',
      'confirmPasswordLabel': 'تأكيد كلمة المرور',
      'finishSignUp': 'إنهاء التسجيل',
      'orSignUpWith': 'أو التسجيل باستخدام',
      'signUpWithGoogle': 'التسجيل عبر جوجل',
      'completeProfileTitle1': 'إكمال',
      'completeProfileTitle2': 'الملف الشخصي',
      'completeProfileDesc': 'مجرد بضع تفاصيل إضافية للبدء.',
      'completeProfileBtn': 'إكمال الملف الشخصي',
      'updateDetailsHint': 'يمكنك تحديث هذه التفاصيل لاحقاً في ملفك الشخصي.',
      'congratsReady': 'أنت جاهز للانطلاق',
      'congratsExplore': 'ابدأ الاستكشاف',
      'congratsDesc': 'اكتمل التسجيل. لقد خطوت خطوتك الأولى نحو إدارة فريق أكثر ذكاءً وتواصلاً.',
      // Titles
      'titleSearch': 'البحث',
      'titleMessages': 'الرسائل',
      'homeAnnouncements': 'الإعلانات',
      'homeWelcome': 'مرحباً بك في Equipex!',
      'homeClubSetup': 'نظِّم ناديك. الآن أنشئ فريقك الأول للبدء.',
      'homeStartClub': 'ابدأ بإنشاء ناديك لبناء مجتمعك الرياضي.',
      'homeCreateFirstTeam': 'إنشاء فريقك الأول',
      'homeCreateFirstClub': 'إنشاء ناديك الأول',
      'homeAddFirstEvent': 'أضف حدثك الأول',
      'homeNoEvents': 'لا توجد أحداث بعد',
      'homeTapToSchedule': 'اضغط لجدولة مباراة، تدريب، أو اجتماع.',
      'homeEventsAppearHere': 'ستظهر الأحداث هنا بمجرد أن يجدولها مديرك.',
      'homeNoAnnouncements': 'لا توجد إعلانات بعد',
      'homeAddFirstAnnouncement': 'أضف إعلانك الأول',
      'homeAnnouncementsAppearHere': 'ستظهر إعلانات فريقك هنا.',
      'homeKeepTeamInLoop': 'أبقِ فريقك على اطلاع — انشر تحديثاً أو تنبيهاً.',
      'deleteAnnouncementTitle': 'حذف الإعلان؟',
      'deleteAnnouncementDesc': 'سيتم إزالة هذا الإعلان لجميع أفراد الفريق.',
      'homePickImage': 'اختر صورة جديدة',
      'homeCaption': 'التسمية التوضيحية',
      'homeUrgent': 'عاجل',
      'homeImportant': 'مهم',
      'homeNormal': 'عادي',
      'monday': 'الإثنين',
      'tuesday': 'الثلاثاء',
      'wednesday': 'الأربعاء',
      'thursday': 'الخميس',
      'friday': 'الجمعة',
      'saturday': 'السبت',
      'sunday': 'الأحد',
      'eventsTitle': 'الأحداث',
      'match': 'مباراة',
      'training': 'تدريب',
      'meeting': 'اجتماع',
      'test': 'اختبار',
      'add': 'إضافة',
      'noEventsOnThisDay': 'لا توجد أحداث في هذا اليوم',
      'addEvent': 'إضافة حدث',
      // TeamView
      'teamTitle': 'الفريق',
      'teamMembers': 'الأعضاء',
      'teamStats': 'الإحصائيات',
      'teamPlans': 'الخطط',
      'teamAddAnotherMember': 'أضف عضواً آخر في الفريق لبدء الدردشة.',
      'teamChat': 'دردشة الفريق',
      'teamErrorStartConversation': 'تعذر بدء المحادثة.',
      'teamLeaveTeam': 'مغادرة الفريق',
      'teamLeaveTeamPrompt': 'مغادرة الفريق؟',
      'teamNoMembers': 'لا يوجد أعضاء بعد. أضف أعضاء من القائمة.',
      'teamMessageBtn': 'مراسلة',
      'teamOpening': 'جاري الفتح...',
      'teamMessageTeamBtn': 'مراسلة الفريق',
      // ProfileView
      'profileTitle': 'ملفي الشخصي',
      'profileUpdated': 'تم تحديث الملف الشخصي بنجاح!',
      'profileUpdateFailed': "تعذر تحديث ملفك الشخصي. يرجى المحاولة مرة أخرى.",
      'profileRole': 'الدور',
      'profileId': 'المعرف',
      'profileAge': 'العمر',
      'profileYrs': 'سنوات',
      'profileExp': 'سنوات الخبرة',
      'profileNA': 'غير متاح',
      'profileNoBio': 'لا توجد نبذة بعد.',
      'profileUser': 'مستخدم',
      'profileName': 'الاسم',
      'profileUsername': 'اسم المستخدم',
      'profileBioLabel': 'نبذة',
      'profileUsernameHint': '@اسم_المستخدم',
      'profileBioHint': 'أخبرنا عن نفسك...',
      'profileSaving': 'جاري الحفظ...',
      'profileSaveChanges': 'حفظ التغييرات',
      'profileNoTeams': 'لا توجد فرق بعد.',
      'profileNoCommonTeams': 'لا توجد فرق مشتركة.',
      // MessagesView
      'messagesNoConversations': 'لا توجد محادثات بعد.',
      'messagesPhoto': 'صورة',
      'messagesVideo': 'فيديو',
      'messagesVoiceNote': 'رسالة صوتية',
      'messagesDocument': 'مستند',
      'messagesLocation': 'موقع',
      'messagesFile': 'ملف',
      // AddClubView
      'addClubTitle': 'إنشاء نادٍ',
      'addClubLogoReq': 'شعار النادي مطلوب',
      'addClubTapToSelect': 'اضغط لاختيار شعار النادي',
      'addClubName': 'اسم النادي',
      'addClubEstDate': 'تاريخ التأسيس (اختياري)',
      'addClubSelectDate': 'اختر تاريخاً',
      'addClubLocation': 'الموقع (اختياري)',
      'addClubCityCountry': 'المدينة، البلد',
      'addClubTapMap': 'اضغط على أيقونة الخريطة لإضافة موقع',
      'addClubCreating': 'جاري الإنشاء...',
      'addClubCreateClubBtn': 'إنشاء النادي',
      // AddTeamView
      'addTeamTitle': 'إضافة فريق',
      'addTeamName': 'اسم الفريق',
      'addTeamClub': 'النادي',
      'addTeamCategory': 'فئة الفريق',
      'addTeamAdding': 'جاري الإضافة...',
      'addTeamAddTeamBtn': 'إضافة فريق',
      'addTeamEnterName': 'الرجاء إدخال اسم الفريق.',
      'addTeamChooseClubFirst': 'اختر النادي والفئة أولاً.',
      'addTeamErrorCreate': 'تعذر إنشاء الفريق.',
      // PlansView
      'plansDeletePlanTitle': 'حذف الخطة؟',
      'plansDeletePlanDesc': 'ستتم إزالة هذه الخطة. لا يمكن التراجع عن هذا الإجراء.',
      'plansDelete': 'حذف',
      'plansOptions': 'خيارات الخطة',
      'plansEdit': 'تعديل',
      'plansNoPlansAdd': 'لا توجد خطط بعد.\nاضغط + لإضافة واحدة.',
      'plansNoPlans': 'لا توجد خطط بعد.',
      'plansAddPlanBtn': 'إضافة خطة',
      'plansPlanTitle': 'خطة',
      'plansCreatedBy': 'تم الإنشاء بواسطة',
      'plansTeamStaff': 'موظفي الفريق',
      'plansNoDesc': 'لا يوجد وصف',
      'plansNoTactics': 'لم يتم حفظ تكتيكات',
      'plansDocuments': 'المستندات',
      'plansErrorOpenDoc': 'تعذر فتح المستند.',
      // AddPlansView
      'addPlansTitleReq': 'عنوان الخطة مطلوب.',
      'addPlansEditPlan': 'تعديل الخطة',
      'addPlansAddPlan': 'إضافة خطة',
      'addPlansTitle': 'العنوان',
      'addPlansOffensive': 'هجومي',
      'addPlansDefensive': 'دفاعي',
      'addPlansDesc': 'الوصف',
      'addPlansVisibility': 'الرؤية',
      'addPlansOnlyMe': 'أنا فقط',
      'addPlansTeam': 'الفريق',
      'addPlansAttachments': 'المرفقات',
      'addPlansUploadedDocs': 'المستندات المرفوعة',
      'addPlansUploaded': 'مرفوع',
      'addPlansDiscard': 'تجاهل',
      'addPlansTapToAttach': 'اضغط هنا لإرفاق المستندات\n(PDF، JPG، PNG، DOC، DOCX)',
      'addPlansTapToAddAnother': 'اضغط لإضافة مرفق آخر',
      'addPlansTacticalBoard': 'لوحة التكتيك',
      'addPlansEdit': 'تعديل',
      'addPlansYourTeam': 'فريقك',
      'addPlansOpponent': 'الخصم',
      'addPlansSavePlay': 'حفظ التكتيك',
      'addPlansReset': 'إعادة تعيين',
      'addPlansUndo': 'تراجع',
      'addPlansDone': 'تم',
      'addPlansPlayName': 'اسم التكتيك',
      'addPlansSave': 'حفظ',
      'addPlansSavedPlays': 'التكتيكات المحفوظة',
      'addPlansPresetPlays': 'تكتيكات مسبقة الصنع',
      'addPlansSavePlanBtn': 'حفظ الخطة',
      'addPlansAddPlanBtn': 'إضافة الخطة',
      // AddAnnouncementView
      'addAnnounceTitle': 'إعلان',
      'addAnnounceCaption': 'تعليق الإعلان',
      'addAnnounceUrgent': 'عاجل',
      'addAnnounceImportant': 'مهم',
      'addAnnounceNormal': 'عادي',
      'addAnnounceBtn': 'إضافة إعلان',
      'addAnnouncePickImage': 'اختر صورة للإعلان',
      'addAnnounceSuccess': 'تمت إضافة الإعلان بنجاح',
      // AddMembersView
      'addMembersInviteMember': 'دعوة عضو',
      'addMembersRoleTeamMgr': 'الدور: مدير الفريق',
      'addMembersRole': 'الدور',
      'addMembersJersey': 'رقم القميص',
      'addMembersPosition': 'مركز اللاعب',
      'addMembersEmail': 'عنوان البريد الإلكتروني',
      'addMembersSending': 'جاري الإرسال...',
      'addMembersSendBtn': 'إرسال الدعوة',
      'addMembersClub': 'النادي',
      'addMembersTeam': 'الفريق',
      'addMembersNoTeams': 'لا توجد فرق بعد',
      'addMembersNoTeamsDesc': 'تم إعداد النادي الخاص بك. قم الآن بإنشاء فريقك الأول للبدء.',
      'addMembersCreateFirstTeam': 'إنشاء فريقك الأول',
      'addMembersEmailReq': 'يرجى إدخال عنوان بريد إلكتروني.',
      'addMembersValidJersey': 'أدخل رقم قميص صحيح (1-999).',
      'addMembersPosReq': 'يرجى اختيار مركز اللاعب.',
      'addMembersErrClub': 'لا يمكن تحديد النادي لهذه الدعوة.',
      'addMembersSentClub': 'تم إرسال دعوة إلى %s كمدير فريق!',
      'addMembersErrSend': 'تعذر إرسال الدعوة.',
      'addMembersTeamReq': 'يرجى اختيار فريق أولاً.',
      'addMembersErrClubTeam': 'لا يمكن تحديد النادي لهذا الفريق.',
      'addMembersSentTeam': 'تم إرسال دعوة إلى %e كـ %r!',
      'rolePlayer': 'لاعب',
      'roleCoach': 'مدرب',
      'roleFitnessCoach': 'مدرب لياقة بدنية',
      'roleTeamAnalyst': 'محلل الفريق',
      'roleTeamDoctor': 'طبيب الفريق',
      'roleTeamManager': 'مدير الفريق',
      'roleClubManager': 'مدير النادي',
      'posPG': 'صانع ألعاب',
      'posSG': 'مدافع مسدد الهدف',
      'posSF': 'لاعب هجوم صغير الجسم',
      'posPF': 'لاعب هجوم قوي الجسم',
      'posC': 'لاعب وسط',
      // JoinTeamView / IncomingRequestsView
      'joinNoPending': 'لا توجد دعوات معلقة',
      'joinNoPendingDesc': 'عندما يدعوك مدير للانضمام إلى فريق،\nستظهر الدعوة هنا.',
      'joinRole': 'الدور: %s',
      'decline': 'رفض',
      'accept': 'قبول',
      'joinDetails': 'تفاصيل الدعوة',
      'joinTeamClub': 'الفريق / النادي',
      'joinPosition': 'المركز',
      'joinJersey': 'رقم القميص',
      'joinInvitedBy': 'مدعو بواسطة',
      'joinManager': 'المدير',
      'joinSentTo': 'أرسلت إلى',
      'joinStatus': 'الحالة',
      'joinPending': 'قيد الانتظار',
      'joinNA': 'غير متوفر',
      'incNoTeamSelected': 'لم يتم تحديد فريق.',
      'incErrLoad': 'تعذر تحميل الدعوات.',
      'incCancelled': 'تم إلغاء الدعوة لـ %s.',
      'incErrCancel': 'تعذر إلغاء الدعوة.',
      'incNoPendingDesc': 'الدعوات التي ترسلها ستظهر هنا.',
      // SearchView
      'searchTitle': 'بحث',
      'searchHint': 'البحث عن الفرق، المستخدمين، الأحداث...',
      'searchFilterTitle': 'تصفية حسب النوع',
      'searchMinChars': 'اكتب حرفين على الأقل.',
      'searchErrFailed': 'فشل البحث. يرجى المحاولة مرة أخرى.',
      'searchNoResults': 'لم يتم العثور على نتائج.',
      'searchFilterAll': 'الكل',
      'searchFilterTeams': 'الفرق',
      'searchFilterUsers': 'المستخدمون',
      'searchFilterEvents': 'الأحداث',
      'searchFilterPlans': 'الخطط',
      'searchFilterAnnouncements': 'الإعلانات',
      'searchFilterStats': 'الإحصائيات',
      // AskEqiupeIoView
      'askEqWelcome': 'مرحبًا بك في مساعد Equipo! 🚀',
      'askEqPrompt': "اسألني عن مباريات فريقك، هدافيك، التوقعات، أو من هو مصاب.",
      'askEqPickTeam': 'اختر فريقًا أولاً (استخدم مبدل الفريق أعلاه)، ثم اسأل.',
      'askEqNoAnswer': "لم أحصل على إجابة لذلك. حاول إعادة صياغة السؤال؟",
      'askEqError': 'المساعد غير متوفر حاليًا. يرجى المحاولة مرة أخرى.',
      'askEqTitle': 'Equipo',
      'askEqThinking': 'Equipo يفكر…',
      'askEqTypeMsg': 'اكتب رسالتك...',
      'askEqFileSoon': 'إرفاق الملفات قريبًا...',
      // NotificationsView
      'notifJustNow': 'الآن',
      'notifMinsAgo': 'منذ %d دقيقة',
      'notifHoursAgo': 'منذ %d ساعة',
      'notifDaysAgo': 'منذ %d يوم',
      'titleNotifications': 'الإشعارات',
      'notifUnreadCount': '%d غير مقروءة',
      'notifAllCaughtUp': 'لا توجد إشعارات جديدة',
      'notifMarkAllRead': 'تحديد الكل كمقروء',
      'notifEmpty': 'لا توجد إشعارات بعد.',
      // SettingsView
      'leaveTeamTitle': 'مغادرة الفريق؟',
      'leaveTeamDesc': 'هل أنت متأكد من مغادرة "%s"؟ ستفقد إمكانية الوصول إلى كافة بيانات وفعاليات الفريق.',
      'leaveClubTitle': 'مغادرة النادي؟',
      'leaveClubDesc': 'هل أنت متأكد من مغادرة "%s"؟ قد تفقد إمكانية الوصول إلى فرق النادي وفعالياته.',
      'errAccount': 'تعذر تحديد الحساب.',
      'leftClub': 'لقد غادرت %s',
      'errLeaveClub': 'تعذر مغادرة النادي.',
      'titleSettings': 'الإعدادات',
      'termsTitle': 'شروط الخصوصية',
      'termsS1T': '١. معلومات الحساب',
      'termsS1B': 'يخزن إكويبو المعلومات الشخصية التي تقدمها، مثل اسمك وبريدك الإلكتروني ودورك وصورتك الشخصية، لضمان عمل تجربتك في النادي والفريق بشكل صحيح.',
      'termsS2T': '٢. بيانات النادي والفريق',
      'termsS2B': 'تُستخدم عضوياتك، فرقك، أنديتك، فعالياتك، سجلات الحضور، البيانات الطبية واللياقة البدنية، وسجلات الأداء فقط لتقديم الميزات للأعضاء المصرح لهم.',
      'termsS3T': '٣. السجلات الخاصة',
      'termsS3B': 'يجب الوصول إلى المعلومات الطبية واللياقة فقط من قبل الأدوار المسموح لها بإدارتها أو مراجعتها. لا تشارك المعلومات الخاصة بعضو آخر خارج التطبيق دون إذن.',
      'termsS4T': '٤. الملفات والوسائط',
      'termsS4B': 'قد يتم تخزين الصور ومقاطع الفيديو والملفات والمستندات المحملة لعرضها أو مراجعتها أو مشاركتها مع الفريق أو أعضاء النادي ذوي الصلة.',
      'termsS5T': '٥. مسؤوليتك',
      'termsS5B': 'أنت توافق على الحفاظ على أمان بيانات الدخول الخاصة بك، واستخدام المنصة باحترام، وتحميل المحتوى الذي يحق لك مشاركته فقط.',
      'termsS6T': '٦. التحديثات',
      'termsS6B': 'قد يتم تحديث هذه الشروط مع تطور المنصة. استمرارك في استخدام التطبيق يعني أنك تقبل الشروط الحالية المعروضة هنا.',
      'clubIdLabel': 'رقم النادي',
      'clubLocationLabel': 'الموقع',
      'clubCoordinatesLabel': 'الإحداثيات',
      'notSetLabel': 'غير محدد',
      // PlayerProfileView
      'newMedRecord': 'سجل طبي جديد',
      'editMedRecord': 'تعديل السجل الطبي',
      'injuryType': 'نوع الإصابة',
      'diagnosis': 'التشخيص',
      'recoveryTips': 'نصائح التعافي',
      'expReturnDate': 'تاريخ العودة المتوقع',
      'create': 'إنشاء',
      'addFitnessRecordTitle': 'إضافة سجل لياقة',
      'recordName': 'اسم السجل',
      'value': 'القيمة',
      'requestDocument': 'طلب مستند',
      'documentName': 'اسم المستند',
      'noteToPlayer': 'ملاحظة للاعب',
      'request': 'طلب',
      'titlePlayerBiometrics': 'القياسات الحيوية للاعب',
      'titleFitnessRecords': 'سجلات اللياقة',
      'titleMedicalRecords': 'السجلات الطبية',
      'titlePlayerStats': 'إحصائيات اللاعب',
      'titlePlayerVideos': 'فيديوهات اللاعب',
      'role': 'الدور',
      'jerseyNumber': 'رقم القميص',
      'age': 'العمر',
      'position': 'المركز',
      'addARecord': 'إضافة سجل',
      'addMedicalRecord': 'إضافة سجل طبي',
      'message': 'مراسلة',
      'opening': 'جاري الفتح...',
      'height': 'الطول',
      'weight': 'الوزن',
      'bmi': 'مؤشر كتلة الجسم',
      'bodyFat': 'نسبة الدهون',
      'updateMetric': 'تحديث %s',
      'update': 'تحديث',
      // TeamStats & GameHistory
      'editStats': 'تعديل الإحصائيات',
      'stat': 'الإحصائية',
      'lastGame': 'آخر مباراة',
      'cumulative': 'التراكمي',
      'statistics': 'إحصائيات %s',
      'matches': 'المباريات',
      'trainingTeamStats': 'إحصائيات فريق التدريب',
      'matchTeamStats': 'إحصائيات فريق المباراة',
      'title': 'العنوان',
      'lastEntry': 'آخر إدخال',
      'gameHistoryTitle': 'تاريخ المباريات',
      'vsOpponent': 'ضد %s',
      'gameStatsTitle': 'إحصائيات المباراة',
      'gameFilesTitle': 'ملفات المباراة',
      'gameVideosTitle': 'فيديوهات المباراة',
      'coachNotesTitle': 'ملاحظات المدرب',
      'open': 'فتح',
      'noCoachNotesYet': 'لا توجد ملاحظات للمدرب بعد.',
      'writeNote': 'اكتب ملاحظة...',
      'saveNote': 'حفظ الملاحظة',
      'uploadGameVideo': 'رفع فيديو المباراة',
      'uploadingVideo': 'جاري رفع الفيديو... قد يستغرق هذا بعض الوقت.',
      'videoUploaded': 'تم رفع الفيديو.',
      'removeVideoTitle': 'إزالة الفيديو؟',
      'removeVideoDesc': 'سيتم إزالة "%s" من هذه المباراة.',
      'remove': 'إزالة',
      'noVideosYet': 'لا توجد فيديوهات بعد.',
      'upload': 'رفع',
      'postNote': 'نشر الملاحظة',
      'updateNoteTitle': 'تحديث الملاحظة',
      'originalStatsSheet': 'ورقة الإحصائيات الأصلية',
      'videoUnavailable': 'هذا الفيديو غير متاح.',
      'filePickerError': 'تعذر فتح منتقي الملفات: %s',
      'fileReadError': 'تعذر قراءة الملف المحدد.',
      'videoTooLarge': 'حجم الفيديو أكبر من 500 ميغابايت.',
      'uploadGameVideoTitle': 'رفع فيديو المباراة',
      'titleOptional': 'العنوان (اختياري)',
      'statsPdfError': 'تعذر فتح ملف الإحصائيات: %s',
      'saveNoteError': 'تعذر حفظ الملاحظة: %s',
      'deleteNoteTitle': 'حذف الملاحظة؟',
      'deleteNoteDesc': 'ستتم إزالة هذه الملاحظة نهائيًا.',
      'deleteNoteError': 'تعذر حذف الملاحظة: %s',
      'openFileError': 'تعذر فتح الملف: %s',
      'openDocumentError': 'تعذر فتح المستند: %s',
      'uploadGameFileTitle': 'رفع ملف المباراة',
      'descOptional': 'الوصف (اختياري)',
      'fileUploaded': 'تم رفع الملف.',
      'fileUploadError': 'تعذر رفع الملف: %s',
      'uploading': 'جاري الرفع...',
      'uploadGameFile': 'رفع ملف المباراة',
      'noDocsUploaded': 'لم يتم رفع أي مستندات.',
      'matchStatsPdf': 'ورقة إحصائيات المباراة.pdf',
      // MatchDetailView
      'eventUpdated': 'تم تحديث الفعالية.',
      'eventUpdateError': 'تعذر تحديث الفعالية: %s',
      'deleteEventTitle': 'حذف الفعالية؟',
      'eventDeleted': 'تم حذف الفعالية.',
      'eventDeleteError': 'تعذر حذف الفعالية: %s',
      'squadSaved': 'تم حفظ التشكيلة بنجاح!',
      'squadSaveError': 'فشل في حفظ التشكيلة: %s',
      'attendanceSaved': 'تم حفظ الحضور!',
      'attendanceSaveError': 'فشل في حفظ الحضور: %s',
      'noTeamVisiblePlans': 'لا توجد خطط مرئية للفريق.',
      'loadPlansError': 'تعذر تحميل الخطط: %s',
      'addPlanError': 'تعذر إضافة الخطة: %s',
      'planAddedToMatch': 'تمت إضافة الخطة إلى المباراة.',
      'attachPlanError': 'تعذر إرفاق الخطة: %s',
      'documentUploaded': 'تم رفع المستند!',
      'uploadFailed': 'فشل الرفع: %s',
      'downloadingDocument': 'جاري تحميل المستند...',
      'documentDeleted': 'تم حذف المستند.',
      'deleteFailed': 'فشل الحذف: %s',
      'openMapError': 'تعذر فتح الخريطة',
      'startersCount': 'الأساسيون (%s)',
      'reservesCount': 'الاحتياط (%s)',
      'statsUploadFailed': 'فشل رفع الإحصائيات: %s',
      'statsSavedForMatch': 'تم حفظ إحصائيات هذه المباراة.',
      'saveStatsError': 'تعذر حفظ الإحصائيات: %s',
      'deleteMatchStatsTitle': 'حذف إحصائيات المباراة؟',
      'matchStatsDeleted': 'تم حذف إحصائيات المباراة.',
      'deleteStatsError': 'تعذر حذف الإحصائيات: %s',
      'openMatchStatsPdfError': 'تعذر فتح ملف إحصائيات المباراة: %s',
      'player': 'لاعب',
      'thisIsUs': 'هذا نحن',
      // Missing Phase 7 Strings
      'selectAttributes': 'حدد السمات',
      'noVideoEndpoint': 'لا يوجد نقطة نهاية لرفع فيديو التحليل في الخادم بعد.',
      'removeVideoConfirm': 'إزالة "%s"؟ لا يمكن التراجع عن هذا.',
      'videoRemoved': 'تم إزالة الفيديو.',
      'videoRemoveError': 'تعذر إزالة الفيديو.',
      'videoSizeLimit': 'حجم الفيديو كبير جداً. الحد الأقصى هو 500 ميغابايت.',
      'uploadingVideoMsg': 'جاري رفع الفيديو...',
      'videoUploadFailed': 'تعذر رفع الفيديو.',
      'uploadPlayerVideo': 'رفع فيديو اللاعب',
      'selectVideoFile': 'حدد ملف الفيديو',
      'record': 'سجل',
      'addFitnessRecord': 'إضافة سجل لياقة',
      'editRecord': 'تعديل السجل',
      'addRecord': 'إضافة سجل',
      'documentUploadedSuccess': 'تم رفع المستند بنجاح.',
      'documentUploadFailed': 'تعذر رفع المستند.',
      'documentDownloadFailed': 'تعذر تحميل المستند.',
      'documentPreviewFailed': 'تعذر معاينة المستند.',
      'medicalRecordSaved': 'تم حفظ السجل الطبي.',
      'saveRecordError': 'تعذر حفظ السجل: %s',
      'addAnotherDocument': 'إضافة مستند آخر',
      'share': 'مشاركة',
      'usePin': 'استخدام الدبوس',
      'cannotOpen': 'لا يمكن فتح %s.',
      'couldNotOpen': 'تعذر فتح هذا الـ %s.',
      'tryAgain': 'حاول مرة أخرى',
      'couldNotStartRecording': 'تعذر بدء التسجيل',
      'gettingLocation': 'جاري الحصول على الموقع الحالي...',
      'couldNotGetLocation': 'تعذر الحصول على الموقع: %s',
      'openingDocument': 'جاري فتح المستند...',
      'openFileErrorMsg': 'تعذر فتح الملف: %s',
      'googleSignUpFailed': 'فشل التسجيل عبر جوجل: %s',
      'profileImageUploadFailed': 'فشل رفع صورة الملف الشخصي.',
      'googleSignInFailed': 'فشل تسجيل الدخول عبر جوجل: %s',
      'pleaseEnterName': 'الرجاء إدخال اسمك (حرفين على الأقل).',
      'pleaseSelectDob': 'الرجاء تحديد تاريخ ميلادك.',
      'addMapPin': 'إضافة دبوس خريطة',
      // Misc
      'titleJoinRequests': 'طلبات الانضمام',
      'titleMyInvitations': 'دعواتي',
      'titleAttendance': 'الحضور',
      'titleEquipo': 'إكيبو',
      'titleAddTeam': 'إضافة فريق',
      'titleAnnouncement': 'إعلان',
      'titleInviteMember': 'دعوة عضو',
      'titleAddEvent': 'إضافة حدث',
      'titleEditEvent': 'تعديل حدث',
      'titleCreateClub': 'إنشاء نادي',
      // FAB
      'fabAddAnnouncements': 'إضافة إعلانات',
      'fabMyInvitations': 'دعواتي',
      'fabAddMember': 'إضافة عضو',
      'fabCreateTeam': 'إنشاء فريق',
      'fabSettings': 'الإعدادات',
      'fabJoinTeam': 'الانضمام لفريق',
      'fabAskEquipo': 'اسأل إكيبو',
      'fabInjuredPlayers': 'اللاعبون المصابون',
      // Home
      // Onboarding
      'obUniteTitle': 'وحّد فريقك بالكامل',
      'obUniteDesc': 'اربط بين المدربين واللاعبين والأطباء والمحللين في مركز واحد.',
      'obTacticalTitle': 'رؤى تكتيكية',
      'obTacticalDesc': 'مكّن المحللين والمدربين من الحصول على رؤى عميقة وتبادل التقارير.',
      'obPeakTitle': 'أفضل حالة للاعبين',
      'obPeakDesc': 'حافظ على جاهزية فريقك عبر تقارير طبية محدثة وتتبع اللياقة.',
      'obLetsStart': 'لنبدأ',
    },
  };
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) =>
      AppLocalizations.supportedLocales
          .any((l) => l.languageCode == locale.languageCode);

  @override
  Future<AppLocalizations> load(Locale locale) async {
    // Normalise to a supported locale so an unsupported country/script variant
    // (e.g. ar_EG) still resolves to our base 'ar' strings.
    final normalized = AppLocalizations.localeForCode(locale.languageCode);
    return AppLocalizations(normalized);
  }

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}
