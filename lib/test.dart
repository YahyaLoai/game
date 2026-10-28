
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';

class TestApp extends StatelessWidget {
  const TestApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'App Lifecycle Test',
      theme: ThemeData(primarySwatch: Colors.blue, useMaterial3: true),
      home: const LifecycleTestPage(),
    );
  }
}

class LifecycleTestPage extends StatefulWidget {
  const LifecycleTestPage({super.key});

  @override
  State<LifecycleTestPage> createState() => _LifecycleTestPageState();
}

class _LifecycleTestPageState extends State<LifecycleTestPage>
    with WidgetsBindingObserver {
  late AppLifecycleListener _listener;

  @override
  void initState() {
    super.initState();
    _setupLifecycleListener();
  }

  void _setupLifecycleListener() {
    _listener = AppLifecycleListener(
      onStateChange: _onStateChange,
      onResume: _onResume,
      onInactive: _onInactive,
      onHide: _onHide,
      onShow: _onShow,
      onPause: _onPause,
      onRestart: _onRestart,
      onDetach: _onDetach,
    );
  }

  void _onStateChange(AppLifecycleState state) {}

  void _onResume() {
    print("resume");
  }

  void _onInactive() {
    print("inactive");
  }

  void _onHide() {
    print("hide");
  }

  void _onShow() {
    print("show");
  }

  void _onPause() {
    print("pause");
  }

  void _onRestart() {
    print("restart");
  }

  void _onDetach() {
    print("detached");
  }

  @override
  void dispose() {
    _listener.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Test"),
        leading: IconButton(onPressed: () {}, icon: Icon(Icons.arrow_back)),
        backgroundColor: Colors.white,
        actions: [IconButton(onPressed: () {}, icon: Icon(Icons.settings))],
      ),
      backgroundColor: Colors.blue,
      body: SafeArea(
        child: GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => BatteryLevelPage()),
            );
          },
          child: Center(
            child: Hero(
              tag: "mykey",
              child: Container(height: 100, width: 100, color: Colors.yellow),
            ),
          ),
        ),
      ),
    );
  }
}

class BatteryLevel {
  static const methodChannel = MethodChannel(
    // A name must be the same as
    // the name in the native implementation.
    'io.flutterengineering.battery/methods',
  );
  static Future<int?> getBatteryLevel() async {
    try {
      final batteryLevel = await methodChannel.invokeMethod<int>(
        'getBatteryLevel',
      );
      return batteryLevel;
    } catch (e) {
      debugPrint(e.toString());
      
      return null;
    }
  }
}

class BatteryLevelPage extends StatelessWidget {
  const BatteryLevelPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          children: [
            Hero(
              tag: "mykey",
              child: Container(height: 100, width: 100, color: Colors.red),
            ),
            Text("Battery Level: ${BatteryLevel.getBatteryLevel()}"),
          ],
        ),
      ),
    );
  }
}
