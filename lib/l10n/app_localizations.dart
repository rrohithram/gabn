import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_hi.dart';

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

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
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
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('hi'),
  ];

  /// The title of the application
  ///
  /// In en, this message translates to:
  /// **'Accessibility Navigator'**
  String get appTitle;

  /// No description provided for @initializing.
  ///
  /// In en, this message translates to:
  /// **'Initializing...'**
  String get initializing;

  /// No description provided for @readyCameraActive.
  ///
  /// In en, this message translates to:
  /// **'Ready. Camera active.'**
  String get readyCameraActive;

  /// No description provided for @cameraInitFailed.
  ///
  /// In en, this message translates to:
  /// **'Camera initialization failed. Please check permissions.'**
  String get cameraInitFailed;

  /// No description provided for @errorStartingApp.
  ///
  /// In en, this message translates to:
  /// **'Error starting app. Please restart.'**
  String get errorStartingApp;

  /// No description provided for @appReadySpeak.
  ///
  /// In en, this message translates to:
  /// **'App ready. Camera is active and scanning for obstacles.'**
  String get appReadySpeak;

  /// No description provided for @cameraEnabled.
  ///
  /// In en, this message translates to:
  /// **'Camera enabled'**
  String get cameraEnabled;

  /// No description provided for @cameraDisabled.
  ///
  /// In en, this message translates to:
  /// **'Camera disabled'**
  String get cameraDisabled;

  /// No description provided for @cameraScanning.
  ///
  /// In en, this message translates to:
  /// **'Camera enabled. Scanning for obstacles.'**
  String get cameraScanning;

  /// No description provided for @navigationStarted.
  ///
  /// In en, this message translates to:
  /// **'Starting navigation'**
  String get navigationStarted;

  /// No description provided for @navigationStopped.
  ///
  /// In en, this message translates to:
  /// **'Navigation stopped'**
  String get navigationStopped;

  /// No description provided for @navigationStoppedCameraActive.
  ///
  /// In en, this message translates to:
  /// **'Navigation stopped. Camera active.'**
  String get navigationStoppedCameraActive;

  /// No description provided for @youHaveArrived.
  ///
  /// In en, this message translates to:
  /// **'You have arrived.'**
  String get youHaveArrived;

  /// No description provided for @sosActivated.
  ///
  /// In en, this message translates to:
  /// **'SOS activated.'**
  String get sosActivated;

  /// No description provided for @sosEmergencyHelpRequested.
  ///
  /// In en, this message translates to:
  /// **'Emergency help requested.'**
  String get sosEmergencyHelpRequested;

  /// No description provided for @autoDescriptionEnabled.
  ///
  /// In en, this message translates to:
  /// **'Auto description enabled'**
  String get autoDescriptionEnabled;

  /// No description provided for @autoDescriptionDisabled.
  ///
  /// In en, this message translates to:
  /// **'Auto description disabled'**
  String get autoDescriptionDisabled;

  /// No description provided for @autoDescriptionPaused.
  ///
  /// In en, this message translates to:
  /// **'Auto description paused'**
  String get autoDescriptionPaused;

  /// No description provided for @autoDescriptionResumed.
  ///
  /// In en, this message translates to:
  /// **'Auto description resumed'**
  String get autoDescriptionResumed;
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
      <String>['en', 'hi'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'hi':
      return AppLocalizationsHi();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
