import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:just_audio/just_audio.dart';

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
      title: 'Gator SafeSense',
      theme: ThemeData(
        primarySwatch: Colors.green,
      ),
      home: FutureBuilder(
        future: _fbApp,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            print('You have an error! ${snapshot.error.toString()}');
            return const Text('Something went wrong!');
          }
          else if (snapshot.hasData) {
            return const MyHomePage(title: 'Gator SafeSense');
          }
          else {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }
        }
      )
    );
  }
}

class TestPage extends StatefulWidget {
  const TestPage({Key? key, required this.title}) : super(key: key);

  // This widget is the home page of your application. It is stateful, meaning
  // that it has a State object (defined below) that contains fields that affect
  // how it looks.

  // This class is the configuration for the state. It holds the values (in this
  // case the title) provided by the parent (in this case the App widget) and
  // used by the build method of the State. Fields in a Widget subclass are
  // always marked "final".

  final String title;

  @override
  State<TestPage> createState() => _TestPageState();
}

class _TestPageState extends State<TestPage> {
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

  late AudioPlayer player;

  double? _userAccelerometerChange;
  double? _gyroscopeChange;
  List<double> _UACList = [];
  List<double> _GCList = [];
  bool _fallDetected = false;
  bool _phoneDropDetected = false;
  int _counter = 0;
  int _time = 0;

  //Timer to store a sensor reading every 100 milliseconds
  Timer? _timer;
  void startTimer() {
    _timer = Timer.periodic(const Duration(milliseconds: 100), (timer) {timerCallback();});
  }
  void timerCallback() {
    if (!_listenSensor) {
      _timer?.cancel();
    }
    else {
      // if (_accelerometerData?.length == 100) {
      //   _accelerometerData?.removeRange(0, 70);
      //   _userAccelerometerData?.removeRange(0, 70);
      //   _gyroscopeData?.removeRange(0, 70);
      //   _magnetometerData?.removeRange(0, 70);
      //   _UACList.removeRange(0, 70);
      //   _GCList.removeRange(0, 70);
      // }
      _accelerometerData?.add(_accelerometerValues!);
      _userAccelerometerData?.add(_userAccelerometerValues!);
      _gyroscopeData?.add(_gyroscopeValues!);
      _magnetometerData?.add(_magnetometerValues!);

      //Set changes and add to list
      _userAccelerometerChange = sqrt(pow(_userAccelerometerValues![0], 2) + pow(_userAccelerometerValues![1], 2) + pow(_userAccelerometerValues![2], 2));
      _UACList.add(_userAccelerometerChange!);
      _gyroscopeChange = sqrt(pow(_gyroscopeValues![0], 2) + pow(_gyroscopeValues![1], 2) + pow(_gyroscopeValues![2], 2));
      _GCList.add(_gyroscopeChange!);

      //Add to time counter
      _counter++;

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
    
    player = AudioPlayer();
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
      "Time" : _time,
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
      _phoneDropDetected = false;
      _time = 0;
      _counter = 0;
    });
  }

  Future<void> playChirp() async {
    await player.setAsset('assets/audio/chirp.mp3');
    await player.play();
  }

  void detectFall() {
    setState(() {
      _fallDetected = true;
      _listenSensor = false;
      _time = _counter - 16;
    });
    playChirp();
  }

  bool detectPhoneDrop(int timeCheck) {
    int count = 0;
    if (_GCList[timeCheck] > 7) {count++;}
    if (_GCList[timeCheck + 1] > 7) {count++;}
    if (_GCList[timeCheck + 2] > 7) {count++;}
    if (_GCList[timeCheck + 3] > 7) {count++;}
    if (_GCList[timeCheck + 4] > 7) {count++;}
    if (_GCList[timeCheck + 5] > 7) {count++;}
    if (_GCList[timeCheck + 6] > 7) {count++;}
    if (_GCList[timeCheck + 7] > 7) {count++;}

    if (count >= 4) {
      setState(() {
        _UACList = [];
        _GCList = [];
      });
      return true;
    }
    return false;
  }

  bool detectNoStop(int timeCheck) {
    int count = 0;
    if (_UACList[timeCheck + 5] < 5) {count++;}
    if (_UACList[timeCheck + 6] < 5) {count++;}
    if (_UACList[timeCheck + 7] < 5) {count++;}
    if (_UACList[timeCheck + 8] < 5) {count++;}
    if (_UACList[timeCheck + 9] < 5) {count++;}
    if (_UACList[timeCheck + 10] < 5) {count++;}
    if (_UACList[timeCheck + 11] < 5) {count++;}
    if (_UACList[timeCheck + 12] < 5) {count++;}

    if (count >= 4) {
      setState(() {
        _UACList = [];
        _GCList = [];
      });
      return false;
    }
    return true;
  }

  void checkFall() {
    //Never checks any data for first 1.5 seconds when sensors start
    if (_fallDetected || _UACList.length < 30) {
      return;
    }
    //Checks for fall every 0.1 seconds after 1.5 seconds of sensor recording
    int timeCheck = _UACList.length - 1 - 15;
    //First check: Initial falling motion with low UAC spike
    if (_UACList[timeCheck] > 3) {
      //Second check with high UAC spike in next 3 200 millisecond checks
      // if (_UACList[timeCheck + 1] > 9 || _UACList[timeCheck + 2] > 9 || _UACList[timeCheck + 3] > 9) {
      if (_UACList[timeCheck + 1] > 20 || _UACList[timeCheck + 2] > 20 || _UACList[timeCheck + 3] > 20 || _UACList[timeCheck + 4] > 20 || _UACList[timeCheck + 5] > 20 ) {
        //Third check with GC spike over 4 200 millisecond checks
        if (_GCList[timeCheck] > 4.5 || _GCList[timeCheck + 1] > 4.5 || _GCList[timeCheck + 2] > 4.5 || _GCList[timeCheck + 3] > 4.5) {
          //Next checks cover possible activities which cause fall detection i.e. drop phone or walking
          //Drop phone test: gyroscope values are greater than 10 over 3 checks
          if (detectPhoneDrop(timeCheck)) {
            return;
          }
          if (detectNoStop(timeCheck)) {
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
            Text("Time of fall: ${_time.toString()}"),
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
          const SizedBox(
            height: 10,
          ),
          FloatingActionButton(
            onPressed: () {Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const MyHomePage(title: "Gator SafeSense")),
            );},
            tooltip: 'Home Page',
            child: const Icon(Icons.home),
          ),
        ],
      )
    );
  }
}

//Charles home page
class MyHomePage extends StatefulWidget {
  const MyHomePage({Key? key, required this.title}) : super(key: key);

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  static const countdownDuration = Duration(seconds: 30);

  var seconds = 30;
  Duration duration = const Duration(seconds: 30);
  Timer? timer;
  bool hasFallen = false;
  bool isCountDown = true;
  bool contactAuthorities = false;

  bool _listenSensor = false;
  final _streamSubscriptions = <StreamSubscription<dynamic>>[];

  List<double>? _accelerometerValues;
  List<double>? _userAccelerometerValues;
  List<double>? _gyroscopeValues;
  List<double>? _magnetometerValues;

  double? _userAccelerometerChange;
  double? _gyroscopeChange;
  List<double> _UACList = [];
  List<double> _GCList = [];
  bool _fallDetected = false;

  //Timer to store a sensor reading every 100 milliseconds
  Timer? _sensorTimer;

  //Audio
  late AudioPlayer player;

  void startSensorTimer() {
    _sensorTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {timerCallback();});
  }
  void timerCallback() {
    if (!_listenSensor) {
      _sensorTimer?.cancel();
    }
    else {
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

    startSensorTimer();
    player = AudioPlayer();
  }

  void detectFall() {
    setState(() {
      _fallDetected = true;
      _listenSensor = false;
    });
    playChirp();
    fallTrigger();
  }

  bool detectPhoneDrop(int timeCheck) {
    int count = 0;
    if (_GCList[timeCheck] > 7) {count++;}
    if (_GCList[timeCheck + 1] > 7) {count++;}
    if (_GCList[timeCheck + 2] > 7) {count++;}
    if (_GCList[timeCheck + 3] > 7) {count++;}
    if (_GCList[timeCheck + 4] > 7) {count++;}
    if (_GCList[timeCheck + 5] > 7) {count++;}
    if (_GCList[timeCheck + 6] > 7) {count++;}
    if (_GCList[timeCheck + 7] > 7) {count++;}

    if (count >= 4) {
      setState(() {
        _UACList = [];
        _GCList = [];
      });
      return true;
    }
    return false;
  }

  bool detectNoStop(int timeCheck) {
    int count = 0;
    if (_UACList[timeCheck + 5] < 5) {count++;}
    if (_UACList[timeCheck + 6] < 5) {count++;}
    if (_UACList[timeCheck + 7] < 5) {count++;}
    if (_UACList[timeCheck + 8] < 5) {count++;}
    if (_UACList[timeCheck + 9] < 5) {count++;}
    if (_UACList[timeCheck + 10] < 5) {count++;}
    if (_UACList[timeCheck + 11] < 5) {count++;}
    if (_UACList[timeCheck + 12] < 5) {count++;}

    if (count >= 4) {
      setState(() {
        _UACList = [];
        _GCList = [];
      });
      return false;
    }
    return true;
  }

  void checkFall() {
    //Never checks any data for first 1.5 seconds when sensors start
    if (_fallDetected || _UACList.length < 30) {
      return;
    }
    //Checks for fall every 0.1 seconds after 1.5 seconds of sensor recording
    int timeCheck = _UACList.length - 1 - 15;
    //First check: Initial falling motion with low UAC spike
    if (_UACList[timeCheck] > 3) {
      //Second check with high UAC spike in next 3 200 millisecond checks
      // if (_UACList[timeCheck + 1] > 9 || _UACList[timeCheck + 2] > 9 || _UACList[timeCheck + 3] > 9) {
      if (_UACList[timeCheck + 1] > 20 || _UACList[timeCheck + 2] > 20 || _UACList[timeCheck + 3] > 20 || _UACList[timeCheck + 4] > 20 || _UACList[timeCheck + 5] > 20 ) {
        //Third check with GC spike over 4 200 millisecond checks
        if (_GCList[timeCheck] > 4.5 || _GCList[timeCheck + 1] > 4.5 || _GCList[timeCheck + 2] > 4.5 || _GCList[timeCheck + 3] > 4.5) {
          //Next checks cover possible activities which cause fall detection i.e. drop phone or walking
          //Drop phone test: gyroscope values are greater than 10 over 3 checks
          if (detectPhoneDrop(timeCheck)) {
            return;
          }
          if (detectNoStop(timeCheck)) {
            return;
          }
          detectFall();
        }
      }
    }
  }

  void startTimer() {
    setState(() {
      timer = Timer.periodic(const Duration(seconds: 1), (_) => decrement());
    });
  }

  void decrement() {
    setState(() {
      if (isCountDown) {
        seconds = duration.inSeconds - 1;
        print('Duration: $seconds');
        if (seconds < 0) {
          confirmedFall();
        } else {
          duration = Duration(seconds: seconds);
        }
      }
    });
  }

  void resetTimer() {
    timer?.cancel();
    duration = countdownDuration;
  }

  void resetApp() {
    setState(() {
      hasFallen = false;
      isCountDown = true;
      contactAuthorities = false;
      _listenSensor = false;
      _accelerometerValues = [];
      _userAccelerometerValues = [];
      _gyroscopeValues = [];
      _magnetometerValues = [];

      _userAccelerometerChange = null;
      _gyroscopeChange = null;
      _UACList = [];
      _GCList = [];
      _fallDetected = false;
    });

    resetTimer();
    stopAlarm();
  }

  //Function used when accelerometer data indicates possibility of fall.
  //Proceeds to prompt user if a fall occurred.
  void fallTrigger() {
    setState(() {
      hasFallen = true;
      startTimer();
    });
  }

  void confirmedFall() {
    setState(() {
      contactAuthorities = true;
      isCountDown = false;
      hasFallen = true;
      resetTimer();
    });
    playAlarm();
  }

  Future<void> playAlarm() async {
    await player.setAsset('assets/audio/alarm.mp3');
    await player.play();
  }

  Future<void> playChirp() async {
    await player.setAsset('assets/audio/chirp.mp3');
    await player.play();
  }

  Future<void> stopAlarm() async {
    await player.stop();
  }

  void _setListenSensor() {
    if (!_listenSensor) {
      startSensorTimer();
    }

    setState(() {
      _listenSensor = !_listenSensor;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: Text(widget.title),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Visibility(
                  child: _listenSensor ?
                    const Text("Fall Sensors On", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 40))
                      : const Text("Fall Sensors Off", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 40)),
                  visible: !hasFallen),
              Visibility(
                child: const Text('Fall detected \n Are you OK?',
                    style:
                    TextStyle(fontWeight: FontWeight.bold, fontSize: 40)),
                visible: (hasFallen & !contactAuthorities),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Visibility(
                      child: ElevatedButton(
                          child: const Text("Yes",
                              style: TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 50)),
                          onPressed: resetApp,
                          style: ButtonStyle(
                              backgroundColor: MaterialStateProperty.all<Color>(
                                  Colors.green),
                              shadowColor: MaterialStateProperty.all<Color>(
                                Colors.green.withOpacity(0.5),
                              ),
                              fixedSize: MaterialStateProperty.all<Size>(
                                  const Size(180, 400)))),
                      visible: (hasFallen & !contactAuthorities)),
                  const SizedBox(
                    width: 9,
                  ),
                  Visibility(
                    child: ElevatedButton(
                        child: const Text("No",
                            style: TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 50)),
                        onPressed: confirmedFall,
                        style: ButtonStyle(
                            backgroundColor:
                            MaterialStateProperty.all<Color>(Colors.red),
                            shadowColor: MaterialStateProperty.all<Color>(
                                Colors.red.withOpacity(0.5)),
                            fixedSize: MaterialStateProperty.all<Size>(
                                const Size(180, 400)))),
                    visible: (hasFallen & !contactAuthorities),
                  )
                ],
              ),
              Visibility(
                  child: const Text(
                    'Contacting help in...',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 30),
                  ),
                  visible: (hasFallen & !contactAuthorities)),
              Visibility(
                  child: buildTime(),
                  visible: (hasFallen & !contactAuthorities)),
              Visibility(
                  child: const Text('Help is on the way',
                      style:
                      TextStyle(fontWeight: FontWeight.bold, fontSize: 30)),
                  visible: contactAuthorities),
              Visibility(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Visibility(
                      //     child: ElevatedButton(
                      //         child: const Text("Noise",
                      //             style: TextStyle(
                      //                 fontWeight: FontWeight.bold, fontSize: 50)),
                      //         onPressed: playAlarm,
                      //         style: ButtonStyle(
                      //             backgroundColor:
                      //             MaterialStateProperty.all<Color>(Colors.blue),
                      //             shadowColor: MaterialStateProperty.all<Color>(
                      //               Colors.green.withOpacity(0.5),
                      //             ),
                      //             fixedSize: MaterialStateProperty.all<Size>(
                      //                 const Size(180, 400)))),
                      //     visible: (contactAuthorities)),
                      // const SizedBox(
                      //   width: 9,
                      // ),
                      Visibility(
                        child: ElevatedButton(
                            child: const Text("Reset",
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 50,
                                )),
                            onPressed: resetApp,
                            style: ButtonStyle(
                                backgroundColor:
                                MaterialStateProperty.all<Color>(Colors.red),
                                shadowColor: MaterialStateProperty.all<Color>(
                                    Colors.red.withOpacity(0.5)),
                                fixedSize: MaterialStateProperty.all<Size>(
                                    const Size(180, 400)))),
                        visible: (contactAuthorities),
                      ),
                    ],
                  )),
            ],
          ),
        ),
        floatingActionButton: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            FloatingActionButton(
              onPressed: _setListenSensor,
              tooltip: 'Trigger Fall',
              child: _listenSensor ? const Icon(Icons.pause_rounded) : const Icon(Icons.play_arrow_rounded),
            ),
            const SizedBox(
              width: 9,
            ),
            FloatingActionButton(
              onPressed: () {Navigator.push(context,
                MaterialPageRoute(builder: (context) => const TestPage(title: "Gator SafeSense Test")),
              );},
              tooltip: 'Test Page',
              child: const Icon(Icons.storage),
            ),
          ],
        ),
      // This trailing comma makes auto-formatting nicer for build methods.
    );
  }

  Widget buildTime() {
    return Text('${duration.inSeconds}', style: const TextStyle(fontSize: 40));
  }
}
