import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:device_tracking/model/common/device_status.dart';
import 'package:device_tracking/utils/time_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart' as blue;
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import 'package:nb_utils/nb_utils.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../model/common/device_model.dart';
import '../../model/common/home_data.dart';
import '../../utils/string_utils.dart';
import '../../utils/system_utils.dart';
import '../../utils/widget_utils.dart';
import '../../views/dialog/edit_text_dlg.dart';
import '../base_view_model.dart';

class BluetoothPairViewModel extends BaseViewModel with WidgetsBindingObserver {
  bool isBluetooth = false;
  StreamSubscription<BluetoothDiscoveryResult>? streamSubscription;
  List<BluetoothDevice> discoveryResultList = [];
  List<BluetoothDevice> mBondList = [];
  bool isDiscovering = false;

  BluetoothConnection? connection;
  bool isConnecting = true;
  bool isDisconnecting = false;
  String messageBuffer = '';

  blue.FlutterBluePlus? flutterBlue;
  StreamSubscription<List<blue.ScanResult>>? streamBlue;
  List<blue.BluetoothDevice> miOSDiscoveryList = [];
  List<blue.BluetoothDevice> miOSConnectedList = [];
  List<String> miOSPairedDeviceIdList = [];
  blue.BluetoothDevice? curBluetoothDevice;

  FlutterReactiveBle flutterReactiveBle = FlutterReactiveBle();

  initialize(BuildContext context) async {
    print(">>> model: initialize(): start");
    if (!await Permission.location.isGranted) {
      await Permission.location.request();
    }
    var status =
        await [
          Permission.bluetoothConnect,
          Permission.bluetoothScan,
          Permission.bluetoothAdvertise,
        ].request();

    if (status.values.any((element) => element.isDenied)) {
      showMessage(StringUtils.txtPleaseEnableAllPermissions, null);
      return;
    }
    if (await blue.FlutterBluePlus.isSupported == false) {
      showMessage(StringUtils.txtBluetoothNotSupportedByThisDevice, null);
    } else {
      if (Platform.isAndroid) {
        isBluetooth = await FlutterBluetoothSerial.instance.isEnabled ?? false;
        discoveryResultList.clear();
      } else if (Platform.isIOS) {
        miOSDiscoveryList.clear();
        blue.FlutterBluePlus.adapterState.listen((
          blue.BluetoothAdapterState state,
        ) {
          if (state == blue.BluetoothAdapterState.on) {
            isBluetooth = true;
          } else {
            isBluetooth = false;
          }
        });
      }
      WidgetsBinding.instance.addObserver(this); // Start observing lifecycle
    }
    notifyListeners();
    print(">>> model: initialize(): ended");
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    try {
      if (Platform.isAndroid) {
        FlutterBluetoothSerial.instance.setPairingRequestHandler(null);
        streamSubscription?.cancel();
      } else if (Platform.isIOS) {
        streamBlue?.cancel();
      }
    } catch (e) {
      debugPrint(e.toString());
    }
    super.dispose();
  }

  // Monitor app lifecycle changes (to know when it goes to background/foreground)
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    if (state == AppLifecycleState.resumed) {
      // App is back from the background
      print("App has resumed!");
      // Here you can navigate back to your home page if needed
    }
  }

  onChangeStatus(bool status) async {
    if (Platform.isAndroid) {
      if (isBluetooth == status) return;
      if (status) {
        final result = await FlutterBluetoothSerial.instance.requestEnable();
        isBluetooth = result ?? false;
      } else {
        final result = await FlutterBluetoothSerial.instance.requestDisable();
        isBluetooth = !(result ?? true);
        discoveryResultList.clear();
      }

      notifyListeners();
    } else if (Platform.isIOS) {
      if (isBluetooth == status) return;
      showMessage(StringUtils.txtCannotChangeBluetoothStatusOnApp, null);
      notifyListeners();
    }
  }

  onClickBleSetting(BuildContext context) async {
    if (Platform.isAndroid) {
      FlutterBluetoothSerial.instance.openSettings();
    } else if (Platform.isIOS) {
      const url = 'app-settings:';
      if (await canLaunch(url)) {
        await launch(url);
      } else {
        print("Could not open the settings page.");
      }
    }
  }

  bool isDevicePaired(dynamic device) {
    if (Platform.isAndroid) {
      return false;
    } else if (Platform.isIOS) {
      print(
        ">>> model: isDevicePaired(): return: ${device.remoteId.str}, ${miOSConnectedList.any((d) => d.remoteId.str == device.remoteId.str)}",
      );
      return miOSConnectedList.any(
        (d) => d.remoteId.str == device.remoteId.str,
      );
    }
    return false;
  }

  onClickScan(BuildContext context) async {
    print(">>> model: onClickScan() start");
    if (!isBluetooth) {
      showMessage(StringUtils.txtPleaseEnableBluetooth, null);
      return;
    }
    if (Platform.isAndroid) {
      if (isDiscovering) {
        print(">>> model: onClickScan() : isDiscovering");
        streamBlue?.cancel();
        if (blue.FlutterBluePlus.isScanningNow) {
          print(
            ">>> model: onClickScan() : isScanningNow: True, now I will stop",
          );
          await blue.FlutterBluePlus.stopScan();
          print(">>> model: onClickScan() : stopSacn() worked well");
        }
        isDiscovering = false;
        notifyListeners();
      } else {
        print(">>> model: onClickScan() : is not Discovering");
        isDiscovering = true;
        miOSDiscoveryList.clear();
        notifyListeners();
        streamBlue = blue.FlutterBluePlus.onScanResults.listen(
          (results) {
            print(
              ">>> model: onClickScan() miOSDiscoveryList: ${miOSDiscoveryList.length}",
            );
            if (results.isNotEmpty) {
              for (int i = 0; i < results.length; i++) {
                blue.ScanResult result = results[i];
                final existingIndex = miOSDiscoveryList.indexWhere(
                  (element) =>
                      element.remoteId.str == result.device.remoteId.str,
                );
                //                if (result.device.advName.isNotEmpty) {
                if (existingIndex >= 0) {
                  miOSDiscoveryList[existingIndex] = blue.BluetoothDevice(
                    remoteId: result.device.remoteId,
                  );
                } else {
                  miOSDiscoveryList.add(
                    blue.BluetoothDevice(remoteId: result.device.remoteId),
                  );
                  //                  }
                }
              }
              notifyListeners();
            }
          },
          onDone: () {
            print(">>>>>>>>>>>>>> model: onClickScan() onScanResults OnDone");
            isDiscovering = false;
            notifyListeners();
          },
          onError: (e) {
            print(
              ">>>>>>>>>>>>>>> model: onClickScan() onScanResults Error: ${e.toString()}",
            );
            isDiscovering = false;
            notifyListeners();
          },
        );
        // cleanup: cancel subscription when scanning stops
        blue.FlutterBluePlus.cancelWhenScanComplete(streamBlue!);
        await blue.FlutterBluePlus.adapterState
            .where((val) => val == blue.BluetoothAdapterState.on)
            .first;
        await blue.FlutterBluePlus.startScan();
        // wait for scanning to stop
        await blue.FlutterBluePlus.isScanning
            .where((val) => val == false)
            .first;
        print(">>> model: onClickScan() end");
      }
    } else if (Platform.isIOS) {
      if (isDiscovering) {
        print(">>> model: onClickScan() : isDiscovering");
        streamBlue?.cancel();
        if (blue.FlutterBluePlus.isScanningNow) {
          print(
            ">>> model: onClickScan() : isScanningNow: True, now I will stop",
          );
          await blue.FlutterBluePlus.stopScan();
          print(">>> model: onClickScan() : stopSacn() worked well");
        }
        isDiscovering = false;
        notifyListeners();
      } else {
        print(">>> model: onClickScan() : is not Discovering");
        isDiscovering = true;
        miOSDiscoveryList.clear();
        notifyListeners();
        streamBlue = blue.FlutterBluePlus.onScanResults.listen(
          (results) {
            print(
              ">>> model: onClickScan() miOSDiscoveryList: ${miOSDiscoveryList.length}",
            );
            if (results.isNotEmpty) {
              for (int i = 0; i < results.length; i++) {
                blue.ScanResult result = results[i];
                final existingIndex = miOSDiscoveryList.indexWhere(
                  (element) =>
                      element.remoteId.str == result.device.remoteId.str,
                );
                //  if (result.device.advName.isNotEmpty) {
                if (existingIndex >= 0) {
                  miOSDiscoveryList[existingIndex] = blue.BluetoothDevice(
                    remoteId: result.device.remoteId,
                  );
                } else {
                  miOSDiscoveryList.add(
                    blue.BluetoothDevice(remoteId: result.device.remoteId),
                  );
                  //    }
                }
              }
              notifyListeners();
            }
          },
          onDone: () {
            print(">>>>>>>>>>>>>> model: onClickScan() onScanResults OnDone");
            isDiscovering = false;
            notifyListeners();
          },
          onError: (e) {
            print(
              ">>>>>>>>>>>>>>> model: onClickScan() onScanResults Error: ${e.toString()}",
            );
            isDiscovering = false;
            notifyListeners();
          },
        );
        // cleanup: cancel subscription when scanning stops
        blue.FlutterBluePlus.cancelWhenScanComplete(streamBlue!);
        await blue.FlutterBluePlus.adapterState
            .where((val) => val == blue.BluetoothAdapterState.on)
            .first;
        await blue.FlutterBluePlus.startScan();
        // wait for scanning to stop
        await blue.FlutterBluePlus.isScanning
            .where((val) => val == false)
            .first;
        print(">>> model: onClickScan() end");
      }
    }
  }

  onDeviceClicked(BuildContext context, dynamic discoveryResult) async {
    if (isDiscovering) {
      showMessage(StringUtils.txtAppIsScanningDevices, null);
      return;
    }
    if (Platform.isAndroid) {
      /*
      try {
        if (discoveryResult.isConnected) {
          showMessage(StringUtils.txtThisDeviceIsAlreadyConnected, null);
          onClickAddDevice(context, discoveryResult);
          return;
        }
        bool bonded = false;
        if (discoveryResult.isBonded) {
          showMessage(StringUtils.txtThisDeviceIsAlreadyPaired, null);
          return;
        } else {
          showLoading();
          bonded =
              await FlutterBluetoothSerial.instance.bondDeviceAtAddress(
                discoveryResult.address,
              ) ??
              false;
          // await FlutterBluetoothSerial.instance
          //     .bondDeviceAtAddress(discoveryResult.address).then((value) {
          //       bonded = value ?? false;
          //     });
          await Future.delayed(Duration(seconds: 2));
          hideLoading();
          if (context.mounted) {
            onClickScan(context);
          }
        }
        discoveryResultList[discoveryResultList.indexOf(
          discoveryResult,
        )] = BluetoothDevice(
          name: discoveryResult.name ?? '',
          address: discoveryResult.address,
          type: discoveryResult.type,
          bondState:
              bonded ? BluetoothBondState.bonded : BluetoothBondState.none,
        );

        notifyListeners();
      } catch (e) {
        debugPrint(e.toString());
        showMessage(StringUtils.txtErrorOccurredWhileBonding, null);
      }
      */
      if (discoveryResult.isConnected) {
        onClickAddDevice(context, discoveryResult);
        return;
      }
      showMessage(StringUtils.txtPleaseCheckConntection, null);
      return;
    } else if (Platform.isIOS) {
      if (discoveryResult.isConnected) {
        onClickAddDevice(context, discoveryResult);
        return;
      }
      showMessage(StringUtils.txtPleaseCheckConntection, null);
      return;
    }
  }

  onClickConnect(BuildContext context, dynamic item) async {
    if (isDiscovering) {
      showMessage(StringUtils.txtAppIsScanningDevices, null);
      return;
    }
    if (item.isConnected) {
      showMessage(StringUtils.txtYouCanAddThisDevice, null);
      return;
    } else {
      if (Platform.isAndroid) {
        /*
        showLoading();
        flutterReactiveBle
            .connectToDevice(id: item.address)
            .listen((event) {
              hideLoading();
              if (event.connectionState == DeviceConnectionState.connected) {
                discoveryResultList[discoveryResultList.indexOf(
                  item,
                )] = BluetoothDevice(
                  name: item.name ?? '',
                  address: item.address,
                  type: item.type,
                  isConnected: true,
                );

                notifyListeners();
                discoverServices(item.address, item.name);
              } else if (event.connectionState ==
                  DeviceConnectionState.disconnected) {
                discoveryResultList[discoveryResultList.indexOf(
                  item,
                )] = BluetoothDevice(
                  name: item.name ?? '',
                  address: item.address,
                  type: item.type,
                  isConnected: false,
                );

                showMessage(StringUtils.txtBleDeviceDisconnected, null);
              } else if (event.connectionState ==
                  DeviceConnectionState.connecting) {
                showMessage(StringUtils.txtBleDeviceConnecting, null);
                notifyListeners();
              }
            })
            .onError((_) {
              hideLoading();
              showMessage(StringUtils.txtErrorOccurredWhileConnecting, null);
            });
            */

        try {
          showLoading();
          print(">>> view model: onClickConnect(): showLoading().");
          await Future.delayed(Duration(seconds: 1));
          if (item.isDisconnected) {
            print(
              ">>> view model: onClickConnect(): device is not connected yet.",
            );
            await item.connect(timeout: Duration(seconds: 6));
            print(
              ">>> view model:${item.advName}: Connecteing Result: ${item.isConnected}",
            );
          }
          hideLoading();
          if (context.mounted) {
            onClickScan(context);
          }
          notifyListeners();
        } catch (e) {
          debugPrint(e.toString());
          hideLoading();
          showMessage(StringUtils.txtErrorOccurredWhileConnecting, null);
          return;
        }
      } else if (Platform.isIOS) {
        try {
          showLoading();
          print(">>> view model: onClickConnect(): showLoading().");
          await Future.delayed(Duration(seconds: 1));
          if (item.isDisconnected) {
            print(
              ">>> view model: onClickConnect(): device is not connected yet.",
            );
            await item.connect(timeout: Duration(seconds: 6));
            print(
              ">>> view model:${item.advName}: Connecteing Result: ${item.isConnected}",
            );
          }
          hideLoading();
          if (context.mounted) {
            onClickScan(context);
          }
          notifyListeners();
        } catch (e) {
          debugPrint(e.toString());
          hideLoading();
          showMessage(StringUtils.txtErrorOccurredWhileConnecting, null);
          return;
        }
      }
    }
  }

  onTryReconnect(BluetoothDiscoveryResult item) {
    BluetoothConnection.toAddress(item.device.address)
        .then((bleConnection) {
          debugPrint('Connected to the device');
          connection = bleConnection;
          isConnecting = false;
          isDisconnecting = false;

          connection!.input!.listen(onDataReceived).onDone(() {
            if (isDisconnecting) {
              debugPrint('Disconnecting locally!');
            } else {
              debugPrint('Disconnected remotely!');
            }
          });

          notifyListeners();
        })
        .catchError((error) {
          showMessage('Cannot connect, exception occurred', null);
          debugPrint(error.toString());
        });
  }

  onDataReceived(Uint8List data) {
    int backspacesCounter = 0;
    for (var byte in data) {
      if (byte == 8 || byte == 127) {
        backspacesCounter++;
      }
    }
    Uint8List buffer = Uint8List(data.length - backspacesCounter);
    int bufferIndex = buffer.length;

    // Apply backspace control character
    backspacesCounter = 0;
    for (int i = data.length - 1; i >= 0; i--) {
      if (data[i] == 8 || data[i] == 127) {
        backspacesCounter++;
      } else {
        if (backspacesCounter > 0) {
          backspacesCounter--;
        } else {
          buffer[--bufferIndex] = data[i];
        }
      }
    }

    // Create message if there is new line character
    String dataString = String.fromCharCodes(buffer);
    int index = buffer.indexOf(13);
    if (~index != 0) {
      messageBuffer =
          (backspacesCounter > 0
              ? messageBuffer.substring(
                0,
                messageBuffer.length - backspacesCounter,
              )
              : messageBuffer + dataString.substring(0, index));
      messageBuffer = dataString.substring(index);
    } else {
      messageBuffer =
          (backspacesCounter > 0
              ? messageBuffer.substring(
                0,
                messageBuffer.length - backspacesCounter,
              )
              : messageBuffer + dataString);
    }

    debugPrint(dataString);
  }

  discoverServices(String deviceId, String? name) async {
    // showLoading();
    // try {
    //   List<DiscoveredService> serviceList =
    //       await flutterReactiveBle.discoverServices(deviceId);
    //   for (int i = 0; i < serviceList.length; i++) {

    //   }
    //   hideLoading();
    // } catch (e) {
    //   hideLoading();
    //   debugPrint(e.toString());
    // }
  }

  onClickBack(BuildContext context) {
    if (isDiscovering) {
      showMessage(StringUtils.txtAppIsScanningDevices, null);
      return;
    }
    finishView(context);
  }

  onClickAddDevice(BuildContext context, dynamic discoveryResult) {
    if (Platform.isAndroid) {
      print("show dialog");
      showDialog(
        context: context,
        builder:
            (BuildContext dlgContext) => EditTextDlg(
              title: StringUtils.txtDescription,
              hint: StringUtils.txtDescription,
              name: discoveryResult.advName ?? '',
              description: discoveryResult.advName ?? '',
              onClickSave: (String userName, String description) {
                DeviceModel deviceModel = DeviceModel();
                deviceModel.id = discoveryResult.remoteId.str;
                deviceModel.name = userName;
                deviceModel.description = description;
                deviceModel.status = DeviceStatus.connected;
                deviceModel.created = Timestamp.fromDate(DateTime.now());
                onAddDeviceToHome(context, deviceModel);
              },
            ),
      );
    } else if (Platform.isIOS) {
      showDialog(
        context: context,
        builder:
            (BuildContext dlgContext) => EditTextDlg(
              title: StringUtils.txtDescription,
              hint: StringUtils.txtDescription,
              name: discoveryResult.advName ?? '',
              description:
                  discoveryResult.advName.isNotEmpty
                      ? discoveryResult.advName
                      : discoveryResult.platfromName.isNotEmpty
                      ? discoveryResult.platfromName
                      : '',
              onClickSave: (String userName, String description) {
                DeviceModel deviceModel = DeviceModel();
                deviceModel.id = discoveryResult.remoteId.str;
                deviceModel.name = userName;
                deviceModel.description = description;
                deviceModel.status = DeviceStatus.connected;
                deviceModel.created = Timestamp.fromDate(DateTime.now());
                onAddDeviceToHome(context, deviceModel);
              },
            ),
      );
    }
  }

  onAddDeviceToHome(BuildContext context, DeviceModel deviceModel) async {
    HomeData? data = await sharedService.getHomeData();
    if (data == null) {
      data = HomeData();
      data.deviceList = [];
      data.deviceList!.add(deviceModel);
    } else {
      data.deviceList ??= [];
      bool alreadyExists = data.deviceList!.any((d) => d.id == deviceModel.id);
      if (!alreadyExists) {
        data.deviceList!.insert(0, deviceModel);
      } else {
        showMessage(StringUtils.txtDeviceIsAlreadyAdded, null);
        return;
      }
    }

    sharedService.saveHomeData(data);
    if (context.mounted) {
      finishView(context, true);
    }
  }
}
