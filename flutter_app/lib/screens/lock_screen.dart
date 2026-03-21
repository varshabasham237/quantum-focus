import 'package:flutter/material.dart';
import '../services/security_service.dart';

class LockScreen extends StatefulWidget {
  final Widget child; // The screen to show after unlocking
  const LockScreen({Key? key, required this.child}) : super(key: key);

  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> {
  bool _isAuthenticating = false;
  String _authMessage = "Unlock Quantum Focus";

  @override
  void initState() {
    super.initState();
    _attemptUnlock();
  }

  Future<void> _attemptUnlock() async {
    setState(() {
      _isAuthenticating = true;
      _authMessage = "Authenticating...";
    });

    final success = await SecurityService().authenticateBiometrics("Please authenticate to access your Focus Dashboard.");
    
    if (!mounted) return;

    if (success) {
      // Replace the lock screen with the actual application contents
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) => widget.child,
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(opacity: animation, child: child);
          },
        ),
      );
    } else {
      setState(() {
        _isAuthenticating = false;
        _authMessage = "Authentication Failed. Try again.";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black, // Sleek, dark lock screen
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.lock_outline, size: 80, color: Colors.indigoAccent),
            const SizedBox(height: 20),
            Text(
              "Quantum Focus is Locked",
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            const SizedBox(height: 10),
            Text(
              _authMessage,
              style: const TextStyle(fontSize: 16, color: Colors.grey),
            ),
            const SizedBox(height: 40),
            if (!_isAuthenticating)
              ElevatedButton.icon(
                icon: const Icon(Icons.fingerprint),
                label: const Text("Unlock with Biometrics"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.indigoAccent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
                onPressed: _attemptUnlock,
              )
            else
              const CircularProgressIndicator(color: Colors.indigoAccent),
          ],
        ),
      ),
    );
  }
}
