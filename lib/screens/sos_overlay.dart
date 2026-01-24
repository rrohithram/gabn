import 'package:flutter/material.dart';
import '../services/sos_service.dart';
import '../services/settings_service.dart';

class SosOverlay extends StatefulWidget {
  const SosOverlay({super.key});

  @override
  State<SosOverlay> createState() => _SosOverlayState();
}

class _SosOverlayState extends State<SosOverlay> with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  final SosService _sos = SosService();
  final SettingsService _settings = SettingsService();

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat(reverse: true);
    
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _sos.addListener(_update);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _sos.removeListener(_update);
    super.dispose();
  }

  void _update() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    if (!_sos.isSosActive) return const SizedBox.shrink();

    final contactName = _sos.contacts.isNotEmpty ? _sos.contacts.first.name : "Emergency Services";

    return Material(
      color: Colors.transparent,
      child: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          color: Colors.red.withOpacity(0.9),
        ),
        child: SafeArea(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.warning_amber_rounded,
                color: Colors.white,
                size: 80,
              ),
              const SizedBox(height: 20),
              Text(
                'EMERGENCY SOS',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: _settings.textSize * 1.5,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Calling: $contactName',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: _settings.textSize,
                ),
              ),
              const Spacer(),
              ScaleTransition(
                scale: _pulseAnimation,
                child: Container(
                  width: 200,
                  height: 200,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 8),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '${_sos.currentCountdown}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 100,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const Spacer(),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
                child: SizedBox(
                  width: double.infinity,
                  height: 100 * _settings.buttonSize,
                  child: ElevatedButton(
                    onPressed: () => _sos.cancelSos(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.red,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      elevation: 10,
                    ),
                    child: Text(
                      'CANCEL',
                      style: TextStyle(
                        fontSize: _settings.textSize * 1.5,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
