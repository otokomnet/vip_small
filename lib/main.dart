import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_blue/flutter_blue.dart';

var token = '';
FlutterBlue flutterBlue = FlutterBlue.instance;

void main() => runApp(new MyApp());
/*void main() {

 SystemChrome.setPreferredOrientations(
      [DeviceOrientation.landscapeLeft,DeviceOrientation.landscapeRight])
      .then((_) {

    runApp(MyApp());

  });
}*/

class MyApp extends StatelessWidget {
  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return new MaterialApp(
        title: 'Smart Control',
        theme: new ThemeData(
          primarySwatch: Colors.blue,
        ),
        ////DEBUG BANNER ini silmek icin alttakini ac !!!!!!!!!!!!!!!!!!!!!!!
        //debugShowCheckedModeBanner: false,
        home: new MyHomePage(title: 'Smart Control'));
  }
}

class MyHomePage extends StatefulWidget {
  MyHomePage({Key key, this.title}) : super(key: key);
  final String title;

  @override
  _MyHomePageState createState() => new _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  @override
  void initState() {
    super.initState();
  }

  //void onTabTapped(int index) {
  /*void _incrementCounter() {
    setState(() {
    });
  }*/

  @override
  Widget build(BuildContext context) {
    return new WillPopScope(
        onWillPop: _onWillPop,
        child: Scaffold(
            backgroundColor: Colors.black,
            appBar: AppBar(
              title: Text(
                'Vip.Smart.Control',
                textAlign: TextAlign.right,
              ),
            ),
            body: AccountWidget(this)));
  }

  _buildProgressBarTile() {
    return Padding(
      padding: const EdgeInsets.all(4.0),
      child: new LinearProgressIndicator(),
    );
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
        ) ??
        false;
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
  bool enable = false;

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

  _buildProgressBarTile() {
    return Padding(
      padding: const EdgeInsets.all(4.0),
      child: new LinearProgressIndicator(),
    );
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
    device
        .writeCharacteristic(
      characteristic,
      sendList[sentCount],
      type: CharacteristicWriteType.withResponse,
    )
        .then((success) {
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

    /////////////bluetoote gidecek deger token ile buraya getiriliyor.//////////////////////////////
    var json = token;
    //print("===== json: " + json);
    // print("*10/28#\n");
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
          print('onValueChanged: e=' +
              d[0].toString() +
              ", mn=" +
              d[1].toString() +
              ", mx=" +
              d[2].toString() +
              ", t=" +
              d[3].toString() +
              ", s=" +
              d[4].toString());

          /* if (!setTemperature) {
            _lowerValue = d[1].toDouble();
            _upperValue = d[2].toDouble();
            setTemperature = true;
          }*/
          data = d[3].toString();
          if (!deviceSaving) {
            // switchOn = (d[4].toString() == "1");
          }
        });
      });
      // Add to map
      valueChangedSubscriptions[c.uuid] = sub;
    }
    setState(() {});
  }

  @override
  /////////////////////////////////////////////////
  //////////////////////////BURADA BUTONLAR OLACAK ////////////////////////////////////////////////////////////////////////////////
  ////////////////////////////////////////////////
  Widget build(BuildContext context) {
    /////////QR kod tara butonu idi bosaltildi
    /////////BLUETOOTH BAGLANTI SAYFASI
//=================================================================================
    var bleRow = Column(
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.all(4.0),
          child: new Stack(
            children: [
              /////////////////////////
              new Image.asset('img/bt_blue_ok.jpg',
                  scale: 2.0, width: 100, height: 100),
              new RawMaterialButton(
                child: Text(''),
                constraints:
                    const BoxConstraints(minWidth: 100, minHeight: 100),
                onPressed: isScanning ? null : _startScan,
              ),
            ],
          ),
        ),
        //////////////////////////////////
        Padding(
          padding: const EdgeInsets.all(4.0),
          child: new Stack(
            children: [
              //yer kaplasin diye -gereksiz
              RawMaterialButton(
                child: Text(''),
                constraints:
                    const BoxConstraints(minWidth: 10.0, minHeight: 10.0),
                onPressed: () {},
              ),
            ],
          ),
        )
      ],
      //  mainAxisSize: MainAxisSize.min,
      //   mainAxisAlignment: MainAxisAlignment.start,
    );

    ///bunu bosaltip cikis butonuna yama---------------->
//=============================================
    ///////////Disconnect butonu///////ana ekranın altinda ////////////////////////////////////////
    /* var disconnectBtn = RaisedButton(
      onPressed: () => _disconnect(), child: new Text("<-"),
      color: Colors.amber,
    );
*/
//////device setting ve cekbox//////////////////////////////////////////////////////////////////////////////////////////////////////////
///////////////////start//////////////////////////
    ///sutun (Clumn) olarak paketliyor//////////////////////////////////////////////////////////////////////////////////////
    var deviceSetting = Column(
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.all(1.0),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(1.0),
              child: Row(children: <Widget>[
////////////////////////////////////////////////////

                Padding(
                  padding: const EdgeInsets.all(18.0),
                  child: new Stack(
                    children: [
                      /////////////////////////
                      new Image.asset(
                          'img/bt_tv_200.jpg', scale: 2.0, width: 100, height: 100
                      ),
                      new RawMaterialButton(
                        child: Text(''),
                        constraints: const BoxConstraints(
                            minWidth: 100, minHeight: 100),
                        onPressed: () {
                          token = "*10/28#\n";
                          saveDeviceSetting();
                        },
                      ),

                    ],),
                ),
////////////////////////////////////////////
              ],
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.start,
              ),
            ),
          ),
        ),
        //BOS SATIR==========//////////////bos satir//////////////
        Padding(
          padding: const EdgeInsets.all(1.0),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(1.0),
              child: Row(children: <Widget>[
                ////////////////////////////////////////////
                /////////////BOS SIYAH/////////////////////
                Padding(
                  padding: const EdgeInsets.all(1.0),
                  child: new Stack(
                    children: [
                      /////////////////////////
                      new Image.asset('img/bt_exit_ok-200.jpg', scale: 2.0,
                          width: 120,
                          height: 120
                      ),
                      /////////////////////////
                    ],),
                ),
              ],
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.start,
              ),
            ),
          ),
        ),
        ///////////////////EOBS///////////
        Padding(
          padding: const EdgeInsets.all(1.0),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(1.0),
              child: Row(children: <Widget>[
////////////////////////////////////////////////////

                /////////////BOS SIYAH/////////////////////
                Padding(
                  padding: const EdgeInsets.all(1.0),
                  child: new Stack(
                    children: [
                      /////////////////////////
                      new Image.asset('img/bt_exit_ok-200.jpg', scale: 2.0,
                          width: 120,
                          height: 120
                      ),
                      /////////////////////////

                    ],),

                ),
                //////////////EBS////////////////////
                /////////////BOS SIYAH/////////////////////
                Padding(
                  padding: const EdgeInsets.all(1.0),
                  child: new Stack(
                    children: [
                      /////////////////////////
                      new Image.asset('img/bt_exit_ok-200.jpg', scale: 2.0,
                          width: 120,
                          height: 120
                      ),
                      /////////////////////////

                    ],),

                ),
                //////////////EBS////////////////////
                Padding(
                  padding: const EdgeInsets.all(1.0),
                  child: new Stack(
                    children: [
                      /////////////////////////
                      new Image.asset('img/bt_buzdolabi_200.jpg', scale: 2.0,
                          width: 100,
                          height: 100
                      ),
                      /////////////////////////
                      RawMaterialButton(
                        child: Text(''),
                        constraints: const BoxConstraints(
                            minWidth: 100, minHeight: 100),
                        onPressed: () {
                          token = "*10/36#\n";
                          saveDeviceSetting();
                        },
                      ),


                    ],),
                ),

//////////////
                /////////////BOS SIYAH/////////////////////
                Padding(
                  padding: const EdgeInsets.all(1.0),
                  child: new Stack(
                    children: [
                      /////////////////////////
                      new Image.asset('img/bt_exit_ok-200.jpg', scale: 2.0,
                          width: 120,
                          height: 120
                      ),
                      /////////////////////////

                    ],),

                ),
                //////////////EBS////////////////////
                Padding(
                  padding: const EdgeInsets.all(1.0),
                  child: new Stack(
                    children: [
                      /////////////////////////
                      new Image.asset('img/bt-sol-masa-200.jpg', scale: 2.0,
                          width: 100,
                          height: 100
                      ),
                      /////////////////////////
                      RawMaterialButton(
                        child: Text(''),
                        constraints: const BoxConstraints(
                            minWidth: 100, minHeight: 100),
                        onPressed: () {
                          token = "*10/30#\n";
                          saveDeviceSetting();
                        },
                      ),


                    ],),
                ),
                ///////////
              ],
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.start,
              ),
            ),
          ),
        ),
        //////////////////////////////
        //BOS SATIR==========//////////////bos satir//////////////
        Padding(
          padding: const EdgeInsets.all(1.0),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(1.0),
              child: Row(children: <Widget>[
                ////////////////////////////////////////////
                /////////////BOS SIYAH/////////////////////
                Padding(
                  padding: const EdgeInsets.all(1.0),
                  child: new Stack(
                    children: [
                      /////////////////////////
                      new Image.asset('img/bt_exit_ok-200.jpg', scale: 2.0,
                          width: 120,
                          height: 120
                      ),
                      /////////////////////////
                    ],),
                ),
              ],
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.start,
              ),
            ),
          ),
        ),
        ///////////////////EOBS///////////
        Padding(
          padding: const EdgeInsets.all(1.0),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(1.0),
              child: Row(children: <Widget>[
////////////////////////////////////////////////////

////////////////////////////////////////
                Padding(
                  padding: const EdgeInsets.all(1.0),
                  child: new Stack(
                    children: [
                      /////////////////////////
                      new Image.asset('img/bt-sag-masa-200.jpg', scale: 2.0,
                          width: 100,
                          height: 100
                      ),
                      /////////////////////////
                      RawMaterialButton(
                        child: Text(''),
                        constraints: const BoxConstraints(
                            minWidth: 100, minHeight: 100),
                        onPressed: () {
                          token = "*10/34#\n";
                          saveDeviceSetting();
                        },
                      ),

                    ],),
                ),
                /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
                /////////////BOS SIYAH/////////////////////
                Padding(
                  padding: const EdgeInsets.all(1.0),
                  child: new Stack(
                    children: [
                      /////////////////////////
                      new Image.asset('img/bt_exit_ok-200.jpg', scale: 2.0,
                          width: 120,
                          height: 120
                      ),
                      /////////////////////////

                    ],),

                ),
                //////////////EBS////////////////////
                //////////////////////////////////
                Padding(
                  padding: const EdgeInsets.all(1.0),
                  child: new Stack(
                    children: [
                      /////////////////////////
                      new Image.asset('img/bt_sunroof_200.jpg', scale: 2.0,
                          width: 100,
                          height: 100
                      ),
                      /////////////////////////
                      RawMaterialButton(
                        child: Text(''),
                        constraints: const BoxConstraints(
                            minWidth: 100, minHeight: 100),
                        onPressed: () {
                          token = "*10/38#\n";
                          saveDeviceSetting();
                        },
                      ),


                    ],),

                ),
                ////////////////
                /////////////BOS SIYAH/////////////////////
                Padding(
                  padding: const EdgeInsets.all(1.0),
                  child: new Stack(
                    children: [
                      /////////////////////////
                      new Image.asset('img/bt_exit_ok-200.jpg', scale: 2.0,
                          width: 120,
                          height: 120
                      ),
                      /////////////////////////

                    ],),

                ),
                //////////////EBS////////////////////
                Padding(
                  padding: const EdgeInsets.all(1.0),
                  child: new Stack(
                    children: [
                      /////////////////////////
                      new Image.asset('img/bt-sol-masa-200.jpg', scale: 2.0,
                          width: 100,
                          height: 100
                      ),
                      /////////////////////////
                      RawMaterialButton(
                        child: Text(''),
                        constraints: const BoxConstraints(
                            minWidth: 100, minHeight: 100),
                        onPressed: () {
                          token = "*10/32#\n";
                          saveDeviceSetting();
                        },
                      ),


                    ],),
                ),
                //////////////////////////////////

              ],
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.start,
              ),
            ),
          ),
        ),
        //////////////////////////////
        //BOS SATIR==========//////////////bos satir//////////////
        Padding(
          padding: const EdgeInsets.all(1.0),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(1.0),
              child: Row(children: <Widget>[
                ////////////////////////////////////////////
                /////////////BOS SIYAH/////////////////////
                Padding(
                  padding: const EdgeInsets.all(1.0),
                  child: new Stack(
                    children: [
                      /////////////////////////
                      new Image.asset('img/bt_exit_ok-200.jpg', scale: 2.0,
                          width: 120,
                          height: 120
                      ),
                      /////////////////////////
                    ],),
                ),
              ],
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.start,
              ),
            ),
          ),
        ),
        ///////////////////EOBS///////////
        Padding(
          padding: const EdgeInsets.all(1.0),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(1.0),
              child: Row(children: <Widget>[
////////////////////////////////////////////////////
                Padding(
                  padding: const EdgeInsets.all(1.0),
                  child: new Stack(
                    children: [
                      /////////////////////////
                      new Image.asset(
                          'img/led1_ok.jpg', scale: 2.0, width: 100, height: 100
                      ),
                      new RawMaterialButton(
                        child: Text(''),
                        constraints: const BoxConstraints(
                            minWidth: 100, minHeight: 100),
                        onPressed: () {
                          token = "*10/11#\n";
                          saveDeviceSetting();
                        },
                      ),

                    ],),
                ),

                /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
                /////////////BOS SIYAH/////////////////////
                Padding(
                  padding: const EdgeInsets.all(1.0),
                  child: new Stack(
                    children: [
                      /////////////////////////
                      new Image.asset('img/bt_exit_ok-200.jpg', scale: 2.0,
                          width: 120,
                          height: 120
                      ),
                      /////////////////////////

                    ],),

                ),
                //////////////EBS////////////////////
                Padding(
                  padding: const EdgeInsets.all(1.0),
                  child: new Stack(
                    children: [
                      /////////////////////////
                      new Image.asset(
                          'img/led2_ok.jpg', scale: 2.0, width: 100, height: 100
                      ),
                      /////////////////////////
                      RawMaterialButton(
                        child: Text(''),
                        constraints: const BoxConstraints(
                            minWidth: 100, minHeight: 100),
                        onPressed: () {
                          token = "*10/13#\n";
                          saveDeviceSetting();
                        },
                      ),


                    ],),
                ),
                /////////////////////////////////

              ],
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.start,
              ),
            ),
          ),
        ),
///////////////////////////////
        //BOS SATIR==========//////////////bos satir//////////////
        Padding(
          padding: const EdgeInsets.all(1.0),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(1.0),
              child: Row(children: <Widget>[
                ////////////////////////////////////////////
                /////////////BOS SIYAH/////////////////////
                Padding(
                  padding: const EdgeInsets.all(1.0),
                  child: new Stack(
                    children: [
                      /////////////////////////
                      new Image.asset('img/bt_exit_ok-200.jpg', scale: 2.0,
                          width: 120,
                          height: 120
                      ),
                      /////////////////////////
                    ],),
                ),
              ],
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.start,
              ),
            ),
          ),
        ),
        ///////////////////EOBS///////////
        Padding(
          padding: const EdgeInsets.all(1.0),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(1.0),
              child: Row(children: <Widget>[
////////////////////////////////////////////////////


                /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

                Padding(
                  padding: const EdgeInsets.all(1.0),
                  child: new Stack(
                    children: [
                      /////////////////////////
                      new Image.asset(
                          'img/led3_ok.jpg', scale: 2.0, width: 100, height: 100
                      ),
                      /////////////////////////
                      RawMaterialButton(
                        child: Text(''),
                        constraints: const BoxConstraints(
                            minWidth: 100, minHeight: 100),
                        onPressed: () {
                          token = "*10/15#\n";
                          saveDeviceSetting();
                        },
                      ),


                    ],),
                ),
                //////////////////////////////////
                /////////////BOS SIYAH/////////////////////
                Padding(
                  padding: const EdgeInsets.all(1.0),
                  child: new Stack(
                    children: [
                      /////////////////////////
                      new Image.asset('img/bt_exit_ok-200.jpg', scale: 2.0,
                          width: 120,
                          height: 120
                      ),
                      /////////////////////////

                    ],),

                ),
                //////////////EBS////////////////////
                Padding(
                  padding: const EdgeInsets.all(1.0),
                  child: new Stack(
                    children: [
                      /////////////////////////
                      new Image.asset(
                          'img/led4_ok.jpg', scale: 2.0, width: 100, height: 100
                      ),
                      /////////////////////////
                      RawMaterialButton(
                        child: Text(''),
                        constraints: const BoxConstraints(
                            minWidth: 100, minHeight: 100),
                        onPressed: () {
                          token = "*10/17#\n";
                          saveDeviceSetting();
                        },
                      ),


                    ],),
                ),
                //////////////////////////////////


              ],
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.start,
              ),
            ),
          ),
        ),
        /////////
      ],
    );
    //////////////end///////////////////

    //////////////Yukarda Tanimladi burada ekrana yerlestiriyor ve tetiklenmeleri isliyor.///////////////////////////////
    return Container(
      child: Column(
        children: <Widget>[
          (isScanning || isConnecting) ? _buildProgressBarTile() : Container(),
          (isConnected == false)
              ? new Flexible(
                  child: new ListView(
                      children: isScanning
                          ? new List<Widget>()
                          : buildDeviceListView()))
              : new Container(
                  child: characteristic != null ? deviceSetting : null),
          Container(
            ////////bagli ise disconnect goster, gegil ise connect goster
            //child: isConnected ? (isConnecting ? Container(child: Text("Connecting!..."),) : disconnectBtn) : bleRow,
            child: isConnected
                ? (isConnecting
                    ? Container(
                        child: Text("Connecting!..."),
                      )
                    : null)
                : bleRow,
            padding: EdgeInsets.fromLTRB(0, 30, 0, 0),
          ),
        ],
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.start,
      ),
      color: Colors.black54,
    );
  }
}
