// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Accessibility Navigator';

  @override
  String get initializing => 'Initializing...';

  @override
  String get readyCameraActive => 'Ready. Camera active.';

  @override
  String get cameraInitFailed =>
      'Camera initialization failed. Please check permissions.';

  @override
  String get errorStartingApp => 'Error starting app. Please restart.';

  @override
  String get appReadySpeak =>
      'App ready. Camera is active and scanning for obstacles.';

  @override
  String get cameraEnabled => 'Camera enabled';

  @override
  String get cameraDisabled => 'Camera disabled';

  @override
  String get cameraScanning => 'Camera enabled. Scanning for obstacles.';

  @override
  String get navigationStarted => 'Starting navigation';

  @override
  String get navigationStopped => 'Navigation stopped';

  @override
  String get navigationStoppedCameraActive =>
      'Navigation stopped. Camera active.';

  @override
  String get youHaveArrived => 'You have arrived.';

  @override
  String get sosActivated => 'SOS activated.';

  @override
  String get sosEmergencyHelpRequested => 'Emergency help requested.';

  @override
  String get autoDescriptionEnabled => 'Auto description enabled';

  @override
  String get autoDescriptionDisabled => 'Auto description disabled';

  @override
  String get autoDescriptionPaused => 'Auto description paused';

  @override
  String get autoDescriptionResumed => 'Auto description resumed';
}
