// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Hindi (`hi`).
class AppLocalizationsHi extends AppLocalizations {
  AppLocalizationsHi([String locale = 'hi']) : super(locale);

  @override
  String get appTitle => 'एक्सेसिबिलिटी नेविगेटर';

  @override
  String get initializing => 'आरंभ हो रहा है...';

  @override
  String get readyCameraActive => 'तैयार। कैमरा सक्रिय है।';

  @override
  String get cameraInitFailed =>
      'कैमरा आरंभ करने में विफल। कृपया अनुमतियां जांचें।';

  @override
  String get errorStartingApp =>
      'ऐप शुरू करने में त्रुटि। कृपया पुनरारंभ करें।';

  @override
  String get appReadySpeak =>
      'ऐप तैयार है। कैमरा सक्रिय है और बाधाओं की तलाश कर रहा है।';

  @override
  String get cameraEnabled => 'कैमरा सक्षम';

  @override
  String get cameraDisabled => 'कैमरा अक्षम';

  @override
  String get cameraScanning => 'कैमरा सक्षम। बाधाओं की तलाश की जा रही है।';

  @override
  String get navigationStarted => 'नेविगेशन शुरू हो रहा है';

  @override
  String get navigationStopped => 'नेविगेशन रुक गया';

  @override
  String get navigationStoppedCameraActive =>
      'नेविगेशन रुक गया। कैमरा सक्रिय है।';

  @override
  String get youHaveArrived => 'आप पहुंच गए हैं।';

  @override
  String get sosActivated => 'SOS सक्रिय हो गया।';

  @override
  String get sosEmergencyHelpRequested =>
      'आपातकालीन सहायता का अनुरोध किया गया।';

  @override
  String get autoDescriptionEnabled => 'ऑटो विवरण सक्षम';

  @override
  String get autoDescriptionDisabled => 'ऑटो विवरण अक्षम';

  @override
  String get autoDescriptionPaused => 'ऑटो विवरण रुका हुआ है';

  @override
  String get autoDescriptionResumed => 'ऑटो विवरण फिर से शुरू';
}
