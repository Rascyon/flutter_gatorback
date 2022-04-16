import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    final Future<FirebaseApp> _fbApp = Firebase.initializeApp();

    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        // This is the theme of your application.
        //
        // Try running your application with "flutter run". You'll see the
        // application has a blue toolbar. Then, without quitting the app, try
        // changing the primarySwatch below to Colors.green and then invoke
        // "hot reload" (press "r" in the console where you ran "flutter run",
        // or simply save your changes to "hot reload" in a Flutter IDE).
        // Notice that the counter didn't reset back to zero; the application
        // is not restarted.
        primarySwatch: Colors.blue,
      ),
      home: FutureBuilder(
        future: _fbApp,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            print('You have an error! ${snapshot.error.toString()}');
            return const Text('Something went wrong!');
          }
          else if (snapshot.hasData) {
            return const MyHomePage(title: 'Flutter Demo Home Page');
          }
          else {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }
        }
      )
      // const MyHomePage(title: 'Flutter Demo Home Page'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({Key? key, required this.title}) : super(key: key);

  // This widget is the home page of your application. It is stateful, meaning
  // that it has a State object (defined below) that contains fields that affect
  // how it looks.

  // This class is the configuration for the state. It holds the values (in this
  // case the title) provided by the parent (in this case the App widget) and
  // used by the build method of the State. Fields in a Widget subclass are
  // always marked "final".

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  bool _listenSensor = false;

  List<double>? _accelerometerValues;
  List<double>? _userAccelerometerValues;
  List<double>? _gyroscopeValues;
  List<double>? _magnetometerValues;
  List<List<double>>? _accelerometerData;
  List<List<double>>? _userAccelerometerData;
  List<List<double>>? _gyroscopeData;
  List<List<double>>? _magnetometerData;
  final _streamSubscriptions = <StreamSubscription<dynamic>>[];

  @override
  void initState() {
    super.initState();
    _streamSubscriptions.add(
      accelerometerEvents.listen((AccelerometerEvent event) {
        if (_listenSensor) {
          _accelerometerData?.add(<double>[event.x, event.y, event.z]);
          setState(() {
            _accelerometerValues = <double>[event.x, event.y, event.z];
          });
        }
      }),
    );
    _streamSubscriptions.add(
      userAccelerometerEvents.listen((UserAccelerometerEvent event) {
        if (_listenSensor) {
          _userAccelerometerData?.add(<double>[event.x, event.y, event.z]);
          setState(() {
            _userAccelerometerValues = <double>[event.x, event.y, event.z];
          });
        }
      }),
    );
    _streamSubscriptions.add(
      gyroscopeEvents.listen((GyroscopeEvent event) {
        if (_listenSensor) {
          _gyroscopeData?.add(<double>[event.x, event.y, event.z]);
          setState(() {
            _gyroscopeValues = <double>[event.x, event.y, event.z];
          });
        }
      }),
    );
    _streamSubscriptions.add(
      magnetometerEvents.listen((MagnetometerEvent event) {
        if (_listenSensor) {
          _magnetometerData?.add(<double>[event.x, event.y, event.z]);
          setState(() {
            _magnetometerValues = <double>[event.x, event.y, event.z];
          });
        }
      }),
    );
  }

  void _setListenSensor() {
    setState(() {
      _listenSensor = !_listenSensor;
    });
  }

  void _sendData() {
    DatabaseReference ref = FirebaseDatabase.instance.ref("test");
    ref.set({
      "accelerometer" : _accelerometerData,
      "userAccelerometer" : _userAccelerometerData,
      "gyroscope" : _gyroscopeData,
      "magnetometer" : _magnetometerData,
    });
  }

  void _clearData() {
    _accelerometerData = [];
    _userAccelerometerData = [];
    _gyroscopeData = [];
    _magnetometerData = [];
  }

  @override
  Widget build(BuildContext context) {
    final accelerometer = _accelerometerValues?.map((double v) => v.toStringAsFixed(1)).toList();
    final gyroscope = _gyroscopeValues?.map((double v) => v.toStringAsFixed(1)).toList();
    final userAccelerometer = _userAccelerometerValues?.map((double v) => v.toStringAsFixed(1)).toList();
    final magnetometer = _magnetometerValues?.map((double v) => v.toStringAsFixed(1)).toList();
    // This method is rerun every time setState is called, for instance as done
    // by the _incrementCounter method above.
    //
    // The Flutter framework has been optimized to make rerunning build methods
    // fast, so that you can just rebuild anything that needs updating rather
    // than having to individually change instances of widgets.
    return Scaffold(
      appBar: AppBar(
        // Here we take the value from the MyHomePage object that was created by
        // the App.build method, and use it to set our appbar title.
        title: Text(widget.title),
      ),
      body: Center(
        // Center is a layout widget. It takes a single child and positions it
        // in the middle of the parent.
        child: Column(
          // Column is also a layout widget. It takes a list of children and
          // arranges them vertically. By default, it sizes itself to fit its
          // children horizontally, and tries to be as tall as its parent.
          //
          // Invoke "debug painting" (press "p" in the console, choose the
          // "Toggle Debug Paint" action from the Flutter Inspector in Android
          // Studio, or the "Toggle Debug Paint" command in Visual Studio Code)
          // to see the wireframe for each widget.
          //
          // Column has various properties to control how it sizes itself and
          // how it positions its children. Here we use mainAxisAlignment to
          // center the children vertically; the main axis here is the vertical
          // axis because Columns are vertical (the cross axis would be
          // horizontal).
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Text(
              'Listening to Sensors: ${_listenSensor.toString()}',
            ),
            Text('Accelerometer: $accelerometer'),
            Text('UserAccelerometer: $userAccelerometer'),
            Text('Gyroscope: $gyroscope'),
            Text('Magnetometer: $magnetometer'),
          ],
        ),
      ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton(
            onPressed: _setListenSensor,
            tooltip: 'Start/Pause Sensor Data',
            child: _listenSensor ? const Icon(Icons.pause_rounded) : const Icon(Icons.play_arrow_rounded),
          ),
          const SizedBox(
            height: 10,
          ),
          FloatingActionButton(
            onPressed: _sendData,
            tooltip: 'Send Sensor Data',
            child: const Icon(Icons.cloud),
          ),
          const SizedBox(
            height: 10,
          ),
          FloatingActionButton(
            onPressed: _clearData,
            tooltip: 'Clear Sensor Data',
            child: const Icon(Icons.clear),
          ),
        ],
      )
    );
  }
}
