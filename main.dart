import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:flutter/services.dart';
import 'dart:async';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: SOSPage(),
    );
  }
}

class SOSPage extends StatefulWidget {
  const SOSPage({Key? key}) : super(key: key);

  @override
  _SOSPageState createState() => _SOSPageState();
}

class _SOSPageState extends State<SOSPage> {
  bool sending = false;
  int _volumeButtonPresses = 0;
  Timer? _volumeTimer;
  bool _cooldown = false; // Prevent duplicate triggers

  @override
  void initState() {
    super.initState();
    detectShake(_sendSOS);
    RawKeyboard.instance.addListener(_handleKeyPress);

    // TODO: Add FirebaseAuth to identify the user
    // TODO: Load user's emergency contacts (from Firestore or local storage)
  }

  @override
  void dispose() {
    RawKeyboard.instance.removeListener(_handleKeyPress);
    _volumeTimer?.cancel();
    super.dispose();
  }

  void _handleKeyPress(RawKeyEvent event) {
    if (event.runtimeType.toString() == 'RawKeyDownEvent') {
      if (event.logicalKey == LogicalKeyboardKey.audioVolumeUp ||
          event.logicalKey == LogicalKeyboardKey.audioVolumeDown) {
        _volumeButtonPresses++;

        if (_volumeTimer != null && _volumeTimer!.isActive) {
          _volumeTimer!.cancel();
        }

        _volumeTimer = Timer(const Duration(seconds: 3), () {
          if (_volumeButtonPresses >= 3) {
            _sendSOS();
          }
          _volumeButtonPresses = 0;
        });
      }
    }
  }

  Future<void> _sendSOS() async {
    if (_cooldown) return;
    _cooldown = true;

    setState(() => sending = true);

    // ✅ Location permission check
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        setState(() => sending = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Location permission denied')),
        );
        _cooldown = false;
        return;
      }
    }

    Position position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );

    await FirebaseFirestore.instance.collection('alerts').add({
      // TODO: Use user ID from FirebaseAuth
      'latitude': position.latitude,
      'longitude': position.longitude,
      'timestamp': DateTime.now(),
      // TODO: Add user ID or emergency contact info
    });

    // TODO: Send SMS or Email to emergency contacts
    // TODO: Trigger push notifications or background alerts

    setState(() => sending = false);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('🚨 SOS Alert Sent')));

    Future.delayed(const Duration(seconds: 10), () {
      _cooldown = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child:
            sending
                ? const CircularProgressIndicator()
                : Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ElevatedButton(
                      onPressed: _sendSOS,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        shape: const CircleBorder(),
                        padding: const EdgeInsets.all(60),
                      ),
                      child: const Text(
                        "SOS",
                        style: TextStyle(fontSize: 30, color: Colors.white),
                      ),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: () {
                        // TODO: Navigate to SettingsPage
                        // Navigator.push(context, MaterialPageRoute(builder: (_) => SettingsPage()));
                      },
                      child: const Text("Settings"),
                    ),
                    // TODO: Add buttons for "Alert History", "Emergency Contacts", etc.
                  ],
                ),
      ),
    );
  }
}

void detectShake(Function onShake) {
  userAccelerometerEvents.listen((event) {
    if (event.x.abs() > 15 || event.y.abs() > 15 || event.z.abs() > 15) {
      onShake();
    }
  });
}
