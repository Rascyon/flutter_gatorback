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

  // This widget is the root of the application.
  @override
  Widget build(BuildContext context) {
    final Future<FirebaseApp> _fbApp = Firebase.initializeApp();

    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
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
            return const MyHomePage(title: 'Gator Safe Sense');
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

  double? _userAccelerometerChange;
  double? _gyroscopeChange;
  List<double> _UACList = [];
  List<double> _GCList = [];
  bool _fallDetected = false;
  bool _phoneDropDetected = false;

  //Timer to store a sensor reading every 200 milliseconds
  Timer? _timer;
  void startTimer() {
    _timer = Timer.periodic(const Duration(milliseconds: 200), (timer) {timerCallback();});
  }
  void timerCallback() {
    if (!_listenSensor) {
      _timer?.cancel();
    }
    else {
      if (_accelerometerData?.length == 100) {
        _accelerometerData?.removeRange(0, 70);
        _userAccelerometerData?.removeRange(0, 70);
        _gyroscopeData?.removeRange(0, 70);
        _magnetometerData?.removeRange(0, 70);
        _UACList.removeRange(0, 70);
        _GCList.removeRange(0, 70);
      }
      _accelerometerData?.add(_accelerometerValues!);
      _userAccelerometerData?.add(_userAccelerometerValues!);
      _gyroscopeData?.add(_gyroscopeValues!);
      _magnetometerData?.add(_magnetometerValues!);

      //Set changes and add to list
      _userAccelerometerChange = sqrt(pow(_userAccelerometerValues![0], 2) + pow(_userAccelerometerValues![1], 2) + pow(_userAccelerometerValues![2], 2));
      _UACList.add(_userAccelerometerChange!);
      _gyroscopeChange = sqrt(pow(_gyroscopeValues![0], 2) + pow(_gyroscopeValues![1], 2) + pow(_gyroscopeValues![2], 2));
      _GCList.add(_gyroscopeChange!);

      //Check for fall
      checkFall();
    }
  }

  @override
  void initState() {
    super.initState();
    _streamSubscriptions.add(
      accelerometerEvents.listen((AccelerometerEvent event) {
        if (_listenSensor) {
          setState(() {
            _accelerometerValues = <double>[event.x, event.y, event.z];
          });
        }
      }),
    );
    _streamSubscriptions.add(
      userAccelerometerEvents.listen((UserAccelerometerEvent event) {
        if (_listenSensor) {
          setState(() {
            _userAccelerometerValues = <double>[event.x, event.y, event.z];
          });
        }
      }),
    );
    _streamSubscriptions.add(
      gyroscopeEvents.listen((GyroscopeEvent event) {
        if (_listenSensor) {
          setState(() {
            _gyroscopeValues = <double>[event.x, event.y, event.z];
          });
        }
      }),
    );
    _streamSubscriptions.add(
      magnetometerEvents.listen((MagnetometerEvent event) {
        if (_listenSensor) {
          setState(() {
            _magnetometerValues = <double>[event.x, event.y, event.z];
          });
        }
      }),
    );
  }

  void _setListenSensor() {
    if (!_listenSensor) {
      startTimer();
    }

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
      "UAC" : _UACList,
      "GC" : _GCList,
    });
  }

  void _clearData() {
    setState(() {
      _accelerometerValues = [];
      _userAccelerometerValues = [];
      _gyroscopeValues = [];
      _magnetometerValues = [];

      _accelerometerData = [];
      _userAccelerometerData = [];
      _gyroscopeData = [];
      _magnetometerData = [];

      _UACList = [];
      _GCList = [];

      _fallDetected = false;
    });
  }

  void detectFall() {
    setState(() {
      _fallDetected = true;
      _listenSensor = false;
    });
  }

  bool detectPhoneDrop(int timeCheck) {
    int count = 0;
    if (_GCList[timeCheck] > 10) {count++;}
    if (_GCList[timeCheck + 1] > 10) {count++;}
    if (_GCList[timeCheck + 2] > 10) {count++;}
    if (_GCList[timeCheck + 3] > 10) {count++;}

    if (count >= 2) {
      setState(() {
        _phoneDropDetected = true;
      });
      return true;
    }
    return false;
  }

  void checkFall() {
    //Never checks any data for first 3 seconds when sensors start
    if (_fallDetected || _UACList.length < 30) {
      return;
    }
    //Checks for fall after 3 seconds
    int timeCheck = _UACList.length - 1 - 15;
    //First check: Initial falling motion with low UAC spike
    if (_UACList[timeCheck] > 3) {
      //Second check with high UAC spike in next 3 200 millisecond checks
      // if (_UACList[timeCheck + 1] > 9 || _UACList[timeCheck + 2] > 9 || _UACList[timeCheck + 3] > 9) {
      if (_UACList[timeCheck + 1] > 20 || _UACList[timeCheck + 2] > 20 || _UACList[timeCheck + 3] > 20) {
        //Third check with GC spike over 4 200 millisecond checks
        if (_GCList[timeCheck] > 4.5 || _GCList[timeCheck + 1] > 4.5 || _GCList[timeCheck + 2] > 4.5 || _GCList[timeCheck + 3] > 4.5) {
          //Next checks cover possible activities which cause fall detection i.e. drop phone or walking
          //Drop phone test: gyroscope values are greater than 10 over 3 checks
          if (detectPhoneDrop(timeCheck)) {
            return;
          }
          detectFall();
        }
      }
    }
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
            Text('Fall Detected: ${_fallDetected.toString()}'),
            Text('Phone Drop Detected: ${_phoneDropDetected.toString()}'),
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
