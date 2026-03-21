import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:freerasp/freerasp.dart';
import 'package:local_auth/local_auth.dart';

class SecurityService {
  final LocalAuthentication _auth = LocalAuthentication();
  
  // Singleton
  static final SecurityService _instance = SecurityService._internal();
  factory SecurityService() => _instance;
  SecurityService._internal();

  /// 1. Initialize Anti-Tampering (FreeRASP)
  void initRuntimeProtection() {
    // Only initialize on real devices / production builds, because emulators trigger the threat callbacks!
    if (kDebugMode) {
      print("[SecurityService] Debug mode detected. FreeRASP bypassed for emulator testing.");
      return;
    }

    final config = TalsecConfig(
      androidConfig: AndroidConfig(
        packageName: 'com.antidistraction.anti_distraction_app',
        signingCertHashes: ['YOUR_SHA256_BASE64_HASH_HERE'], // Update before production release
      ),
      iosConfig: IOSConfig(
        bundleIds: ['com.antidistraction.antiDistractionApp'],
        teamId: 'YOUR_TEAM_ID',
      ),
      watcherMail: 'security@quantumfocus.com',
    );

    // Callbacks if threats are detected
    final callback = ThreatCallback(
      onAppIntegrity: () => _handleThreat('App Integrity tampered'),
      onDebug: () => _handleThreat('Debugger attached'),
      onDeviceBinding: () => _handleThreat('Device binding failed'),
      onDeviceID: () => _handleThreat('Device ID spoofed'),
      onHooks: () => _handleThreat('Hook framework detected'),
      onPrivilegedAccess: () => _handleThreat('Privileged/Root access detected'),
      onSimulator: () => _handleThreat('Simulator/Emulator detected'),
      onUnofficialStore: () => _handleThreat('Installed from unofficial store'),
    );

    Talsec.instance.attachListener(callback);
    Talsec.instance.start(config);
    print("[SecurityService] FreeRASP Anti-Tampering active.");
  }

  void _handleThreat(String reason) {
    print("🚨 [FATAL THREAT] $reason — Initiating lockdown sequence.");
    // In production, you would wipe the secure storage here and instantly exit.
    exit(0);
  }

  /// 2. Biometric Authentication Wrapper
  Future<bool> authenticateBiometrics(String reasonMsg) async {
    try {
      final bool canAuthenticateWithBiometrics = await _auth.canCheckBiometrics;
      final bool canAuthenticate = canAuthenticateWithBiometrics || await _auth.isDeviceSupported();

      if (!canAuthenticate) {
        print("[SecurityService] Device does not support biometrics. Allowing fallback.");
        return true; // Pass if device physically doesn't have a scanner (or it's an emulator)
      }

      final bool didAuthenticate = await _auth.authenticate(
        localizedReason: reasonMsg,
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: true, // Force biometric (no pin fallback for high security)
        ),
      );
      return didAuthenticate;
    } catch (e) {
      print("[SecurityService] Biometric error: $e");
      return false;
    }
  }
}
