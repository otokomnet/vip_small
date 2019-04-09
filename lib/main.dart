import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_blue/flutter_blue.dart';
import 'package:barcode_scan/barcode_scan.dart';
import 'package:flutter_range_slider/flutter_range_slider.dart';

List<Widget> _children = [];

var token = '';

//final GoogleSignIn _googleSignIn = GoogleSignIn();

FlutterBlue flutterBlue = FlutterBlue.instance;

void main() => runApp(new MyApp());

class MyApp extends StatelessWidget {
  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return new MaterialApp(
        title: 'Smart Control (Fish Pool)',
        theme: new ThemeData(
          primarySwatch: Colors.amber,
        ),
        home: new MyHomePage(title: 'Smart Control (Fish Pool)'));
  }
}

class MyHomePage extends StatefulWidget {
  MyHomePage({Key key, this.title}) : super(key: key);

  // This widget is the home page of your application. It is stateful, meaning
  // that it has a State object (defined below) that contains fields that affect
  // how it looks.

  // This class is the configuration for the state. It holds the values (in this
  // case the title) provided by the parent (in this case the App widget) and
  // used by the build method of the State. Fields in a Widget subclass are
  // always marked "final".

  final String title;

  @override
  _MyHomePageState createState() => new _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {

  @override
  void initState() {
    super.initState();
  }

  void onTabTapped(int index) {
    setState(() {

    });
  }

  @override
  Widget build(BuildContext context) {
    return new WillPopScope(
        onWillPop: _onWillPop,
        child: Scaffold(
            appBar: AppBar(
              title: Text('Smart Control (Fish Pool)'),
            ),
            body: AccountWidget(this)
        ));
  }

  _buildProgressBarTile() {
    return new LinearProgressIndicator();
  }

  Future<bool> _onWillPop() {
    return showDialog(
      context: context,
      builder: (context) => new AlertDialog(
        title: new Text('Do you want to exit Smart Control?'),
        content: new Text(''),
        actions: <Widget>[
          new FlatButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: new Text('No'),
          ),
          new FlatButton(
            onPressed: () => exit(1),
            child: new Text('Yes'),
          ),
        ],
      ),
    ) ?? false;
  }
}

// ignore: must_be_immutable
class AccountWidget extends StatefulWidget {
  _MyHomePageState parent;

  AccountWidget(this.parent);

  @override
  _AccountWidget createState() => new _AccountWidget(this.parent);
}

class _AccountWidget extends State<AccountWidget> {
  _MyHomePageState parent;
  _AccountWidget(this.parent);
  bool deviceSaving = false;


  String barcode = "";
  TextEditingController temperature = new TextEditingController();


  FlutterBlue _flutterBlue = FlutterBlue.instance;

  // Scanning
  StreamSubscription _scanSubscription;
  Map<DeviceIdentifier, ScanResult> scanResults = new Map();
  bool isScanning = false;

  // State
  StreamSubscription _stateSubscription;
  BluetoothState state = BluetoothState.unknown;

  // Device
  BluetoothDevice device;

  bool get isConnected => (device != null);
  StreamSubscription deviceConnection;
  StreamSubscription deviceStateSubscription;
  List<BluetoothService> services = new List();
  Map<Guid, StreamSubscription> valueChangedSubscriptions = {};
  BluetoothDeviceState deviceState = BluetoothDeviceState.disconnected;

  BluetoothCharacteristic characteristic;
  bool isConnecting = false;

  var params = [];
  var data = "0";

  bool switchOn = false;
  bool setTemperature = false;
  bool enable = false;

  double _lowerValue = 20.0;
  double _upperValue = 80.0;

  @override
  void initState() {
    super.initState();
    // Immediately get the state of FlutterBlue
    _flutterBlue.state.then((s) {
      setState(() {
        state = s;
      });
    });
    // Subscribe to state changes
    _stateSubscription = _flutterBlue.onStateChanged().listen((s) {
      setState(() {
        state = s;
      });
    });
  }

  @override
  void dispose() {
    print("dispose..........");
    _stateSubscription?.cancel();
    _stateSubscription = null;
    _scanSubscription?.cancel();
    _scanSubscription = null;
    deviceConnection?.cancel();
    deviceConnection = null;
    super.dispose();
  }

  Future scan() async {
    try {
      String barcode = await BarcodeScanner.scan();
      setState(() {
        this.barcode = barcode;
        this.params = barcode.split(',');
        print(this.params);
        _startScan();
      });
    } on PlatformException catch (e) {
      if (e.code == BarcodeScanner.CameraAccessDenied) {
        setState(() {
          this.barcode = 'The user did not grant the camera permission!';
        });
      } else {
        setState(() => this.barcode = 'Unknown error: $e');
      }
    } on FormatException {
      setState(() => this.barcode =
      'null (User returned using the "back"-button before scanning anything. Result)');
    } catch (e) {
      setState(() => this.barcode = 'Unknown error: $e');
    }
  }

  _buildProgressBarTile() {
    return new LinearProgressIndicator();
  }

  _startScan() {
    scanResults.clear();
    _scanSubscription = _flutterBlue
        .scan(
      timeout: const Duration(seconds: 1),
    )
        .listen((scanResult) {
      print('localName: ${scanResult.advertisementData.localName}');
      setState(() {
        if (scanResult.advertisementData.localName.isNotEmpty) {
          scanResults[scanResult.device.id] = scanResult;
          if (params.length == 3) {
            if (params[0] == scanResult.device.id.toString() &&
                isConnected == false) {
              _stopScan();
              _connect(scanResult.device);
            }
          }
        }
      });
    }, onDone: _stopScan);

    setState(() {
      isScanning = true;
    });
  }

  _stopScan() {
    _scanSubscription?.cancel();
    _scanSubscription = null;
    barcode = "";
    setState(() {
      isScanning = false;
    });
  }

  _disconnect() {
    print("disconnect.....");
    barcode = "";
    // Remove all value changed listeners
    valueChangedSubscriptions.forEach((uuid, sub) => sub.cancel());
    valueChangedSubscriptions.clear();
    deviceStateSubscription?.cancel();
    deviceStateSubscription = null;
    deviceConnection?.cancel();
    deviceConnection = null;
    setState(() {
      device = null;
      characteristic = null;
    });
  }

  _connect(BluetoothDevice d) async {
    isConnecting = true;
    device = d;
    // Connect to device
    deviceConnection = _flutterBlue
        .connect(device, timeout: const Duration(seconds: 4))
        .listen(
      null,
      onDone: null,
    );

    // Update the connection state immediately
    device.state.then((s) {
      setState(() {
        deviceState = s;
      });
    });

    // Subscribe to connection changes
    deviceStateSubscription = device.onStateChanged().listen((s) {
      print("====== state changed");
      setState(() {
        deviceState = s;
      });
      if (s == BluetoothDeviceState.connected) {
        device.discoverServices().then((s) {
          setState(() {
            services = s;
            services.forEach((ser) {
              ser.characteristics.forEach((char) {
                print("====== uuid: " + char.uuid.toString());
                if (char.properties.write) {
                  setState(() {
                    characteristic = char;
                    isConnecting = false;
                    if (characteristic.properties.notify) {
                      setNotification(characteristic);
                    }
                  });
                }
              });
            });
          });
        });
      } else if (s == BluetoothDeviceState.disconnected) {
        print("====== state disconnected");
        setState(() {
          _disconnect();
          _startScan();
        });
      }
    });
  }

  List<Widget> buildDeviceListView() {
    return scanResults.values
        .map((r) => Container(
      child: RaisedButton(
        onPressed: () => _connect(r.device),
        child: Text(r.advertisementData.localName),
        color: Colors.blue,
        textColor: Colors.white,
        splashColor: Colors.blueGrey,
      ),
      padding: EdgeInsets.all(10.0),
    ))
        .toList();
  }

  var sendList = new List<List<int>>();
  var sentCount = 0;
  saveCharToDevice() {
    device.writeCharacteristic(
      characteristic,
      sendList[sentCount],
      type: CharacteristicWriteType.withResponse,
    ).then((success) {
      print("============ save success: " + sentCount.toString());
      print("============ save successl: " + sendList.length.toString());
      sentCount++;
      if (sentCount < sendList.length) {
        saveCharToDevice();
        setState(() {
          deviceSaving = true;
        });
      } else {
        setState(() {
          deviceSaving = false;
        });
      }
    }).catchError((error) {
      print("============ save error");
      print(error);
      setState(() {
        deviceSaving = false;
      });
    }).timeout(Duration(seconds: 5));
  }
  void saveDeviceSetting() {
    deviceSaving = true;
    print('save device setting: ' + switchOn.toString());
    var json = '{"switch":"' + (switchOn ? '1' : '0') +
        '","enable":"' + (enable ? '1' : '0')  +
        '","min":"' +  _lowerValue.toInt().toString()  +
        '","max":"' + _upperValue.toInt().toString()  +
        '"}';
    print("===== json: " + json);
    var jsonList = json.codeUnits;
    var json20 = new List<int>();
    var size = jsonList.length;
    var count = 0;
    sentCount = 0;
    sendList.clear();
    jsonList.forEach((intData) {
      json20.add(intData);
      if (json20.length == 20 || (size - 1) == count) {
        sendList.add(json20);
        print("=== json20: " + json20.toString());
        json20 = new List<int>();
      }
      count++;
    });
    saveCharToDevice();
  }
  setNotification(BluetoothCharacteristic c) async {
    print("=================" + c.isNotifying.toString());
    if (c.isNotifying) {
      await device.setNotifyValue(c, false);
      // Cancel subscription
      valueChangedSubscriptions[c.uuid]?.cancel();
      valueChangedSubscriptions.remove(c.uuid);
    } else {
      await device.setNotifyValue(c, true);
      // ignore: cancel_subscriptions
      final sub = device.onValueChanged(c).listen((d) {
        setState(() {
          print('onValueChanged: e='+ d[0].toString()
              + ", mn=" + d[1].toString()
              + ", mx=" + d[2].toString()
              + ", t=" + d[3].toString()
              + ", s=" + d[4].toString());

          if (!setTemperature) {
            _lowerValue = d[1].toDouble();
            _upperValue = d[2].toDouble();
            setTemperature = true;
          }
          data = d[3].toString();
          if (!deviceSaving) {
            switchOn = (d[4].toString() == "1");
          }
        });
      });
      // Add to map
      valueChangedSubscriptions[c.uuid] = sub;
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    var qrBtn = Container(
        padding: EdgeInsets.all(4.0),
        child: RaisedButton(
            onPressed: scan,
            color: isScanning ? Colors.grey : Colors.black54,
            child: Text("Scan QR Code",
              style: TextStyle(color: Colors.white),
            ))
    );
    var scanBtn = Container(
        padding: EdgeInsets.all(4.0),
        child:
        RaisedButton(
            onPressed: isScanning ? null : _startScan,
            color: isScanning ? Colors.grey : Colors.black54,
            child: Text("Search Device",
              style: TextStyle(color: Colors.white),
            ))
    );
    var bleRow = Row(
      children: <Widget>[qrBtn, scanBtn],
      mainAxisSize: MainAxisSize.max,
      mainAxisAlignment: MainAxisAlignment.center,
    );
    var disconnectBtn = RaisedButton(
      onPressed: () => _disconnect(), child: new Text("Disconnect"),
      color: Colors.redAccent,
    );

    var deviceSetting = Column(children: <Widget>[
      Container(child: Text('Device Settting', style: TextStyle(fontWeight: FontWeight.bold),),),
      Container(child: Checkbox(value: enable, onChanged: (bool value) {
        setState(() {
          enable = value;
          saveDeviceSetting();
        });
      }),),
      Container(
        child: Row(children: <Widget>[
          Text(_lowerValue.toInt().toString()),
          RangeSlider(
            min: 20.0,
            max: 40.0,
            lowerValue: _lowerValue,
            upperValue: _upperValue,
            divisions: 100,
            showValueIndicator: true,
            valueIndicatorMaxDecimals: 0,
            onChanged: (double newLowerValue, double newUpperValue) {
              setState(() {
                _lowerValue = newLowerValue;
                _upperValue = newUpperValue;
              });
            },
            onChangeStart:
                (double startLowerValue, double startUpperValue) {
              print('Started with values: $startLowerValue and $startUpperValue');
            },
            onChangeEnd: (double newLowerValue, double newUpperValue) {
              print('Ended with values: $newLowerValue and $newUpperValue');
              saveDeviceSetting();
            },
          ),
          Text(_upperValue.toInt().toString())
        ],
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
        ),
      )
    ],
      mainAxisSize: MainAxisSize.max,
      mainAxisAlignment: MainAxisAlignment.end,
    );
    return Container(child: Column(
      children: <Widget>[
        (isScanning || isConnecting) ? _buildProgressBarTile() : Container(),
        characteristic != null ? Container( child: Text(data, style: TextStyle(fontSize: 200),),) : Container(),
        characteristic != null ? Container(
          child: Transform.scale( scale: 2.0,
            child: Switch(
                value: switchOn,
                activeColor: Colors.amber,
                onChanged: (bool value) {
                  setState(() {
                    switchOn = value;
                    saveDeviceSetting();
                    print("========== switch: " + switchOn.toString());
                  });
                }
            ),
          ),
          padding: EdgeInsets.fromLTRB(0, 0, 0, 50),
        ) : Container()
        ,
        (isConnected == false)
            ? new Flexible(child: new ListView(children: isScanning ? new List<Widget>() : buildDeviceListView()))
            : new Container(child: characteristic != null ? deviceSetting : null),
        Container(
          child: isConnected ? (isConnecting ? Container(child: Text("Connecting..."),) : disconnectBtn) : bleRow,
          padding: EdgeInsets.fromLTRB(0, 30, 0, 0),
        ),
      ],
      mainAxisSize: MainAxisSize.max,
    ),
      color: Colors.black54,
    );
  }
}