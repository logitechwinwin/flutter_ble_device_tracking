import 'dart:async';
import 'dart:io';

import 'package:device_tracking/model/common/device_status.dart';
import 'package:device_tracking/utils/string_utils.dart';
import 'package:device_tracking/utils/widget_utils.dart';
import 'package:device_tracking/views/main/device_view.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart' as blue;
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';
import 'package:nb_utils/nb_utils.dart';
import '../../model/common/device_model.dart';
import '../../model/common/home_data.dart';
import '../../views/auth/login_view.dart';
import '../../views/main/bluetooth_pair_view.dart';
import '../../views/auth/profile_view.dart';
import '../base_view_model.dart';
import 'package:permission_handler/permission_handler.dart';

class MainViewModel extends BaseViewModel with WidgetsBindingObserver {
  List<DeviceModel> mList = [];
  bool isBluetooth = false;
  StreamSubscription<BluetoothDiscoveryResult>? streamSubscription;

  initialize(BuildContext context) async {
    List<blue.BluetoothDevice> connectedDevices = [];
    List<BluetoothDevice> androidBondedDevices = [];
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
      } else if (Platform.isIOS) {
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
    }

    HomeData? homeData = await sharedService.getHomeData();
    if (homeData != null) {
      mList = homeData.deviceList ?? [];
      if (Platform.isAndroid) {
        connectedDevices.clear();
        connectedDevices = blue.FlutterBluePlus.connectedDevices;
        print(
          ">>> m_v_model: initialize(): ConnectedDevices count:: ${connectedDevices.length}",
        );
        for (var device in mList) {
          bool isConnected = connectedDevices.any(
            (d) => d.remoteId.str == device.id,
          );
          print(
            ">>> m_v_model: Initialize: id:: ${device.id}, isConnected:: ${isConnected}",
          );
          if (isConnected) {
            device.status = DeviceStatus.connected;
          } else {
            device.status = DeviceStatus.disconnected;
          }
        }
      } else if (Platform.isIOS) {
        connectedDevices.clear();
        connectedDevices = blue.FlutterBluePlus.connectedDevices;
        print(
          ">>> m_v_model: initialize(): ConnectedDevices count:: ${connectedDevices.length}",
        );
        for (var device in mList) {
          bool isConnected = connectedDevices.any(
            (d) => d.remoteId.str == device.id,
          );
          print(
            ">>> m_v_model: Initialize: id:: ${device.id}, isConnected:: ${isConnected}",
          );
          if (isConnected) {
            device.status = DeviceStatus.connected;
          } else {
            device.status = DeviceStatus.disconnected;
          }
        }
      }
    }

    sharedService.saveHomeData(homeData);
    notifyListeners();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  initUI(BuildContext context) {}

  onClickLogout(BuildContext context) async {
    await FirebaseAuth.instance.signOut().then((_) {
      if (context.mounted) {
        LoginView().launch(context, isNewTask: true);
      }
    });
  }

  onClickProfile(BuildContext context) async {
    await ProfileView().launch(context);
    if (context.mounted) {
      initialize(context);
    }
    notifyListeners();
  }

  onClickBluetooth(BuildContext context) async {
    await const BluetoothPairView().launch(context);
    if (context.mounted) {
      initialize(context);
    }
    notifyListeners();
  }

  onClickItemDelete(BuildContext context, DeviceModel item) async {
    HomeData? data = await sharedService.getHomeData();
    //    print("ssssssssssssssssssssss1:: ${data?.deviceList?.length}");
    if (data != null) {
      mList = data.deviceList ?? [];
      bool alreadyExists = data.deviceList!.any((d) => d.id == item.id);
      if (alreadyExists) {
        data.deviceList!.removeWhere((element) => element.id == item.id);
        mList.remove(item);
        sharedService.saveHomeData(data);
        print("ssssssssssssssssssssss2");
        notifyListeners();
      }
    }
  }

  onClickItemDisconnect(BuildContext context, DeviceModel item) async {
    HomeData? homeData = await sharedService.getHomeData();
    if (homeData != null) {
      mList = homeData.deviceList ?? [];
      final whereIndex = mList.indexWhere((element) => element.id == item.id);
      if (whereIndex >= 0) {
        if (homeData.deviceList?[whereIndex].status ==
            DeviceStatus.disconnected) {
          showMessage(StringUtils.txtThisDeviceIsAlreadyDisconnected, null);
          return;
        }

        if (Platform.isAndroid) {
          List<blue.BluetoothDevice> connectedDevices =
              blue.FlutterBluePlus.connectedDevices;
          final existingIndex = connectedDevices.indexWhere(
            (element) => element.remoteId.str == item.id,
          );
          print("AAAA::: ${connectedDevices.length}");
          if (existingIndex >= 0) {
            try {
              await connectedDevices[existingIndex].disconnect(timeout: 5);
              homeData.deviceList?[whereIndex].status =
                  DeviceStatus.disconnected;
            } catch (e) {
              print("Error disconnecting: $e");
            }
          }
        } else if (Platform.isIOS) {
          List<blue.BluetoothDevice> connectedDevices =
              blue.FlutterBluePlus.connectedDevices;
          final existingIndex = connectedDevices.indexWhere(
            (element) => element.remoteId.str == item.id,
          );
          if (existingIndex >= 0) {
            try {
              await connectedDevices[existingIndex].disconnect(timeout: 5);
              homeData.deviceList?[whereIndex].status =
                  DeviceStatus.disconnected;
            } catch (e) {
              print("Error disconnecting: $e");
            }
          }
        }

        sharedService.saveHomeData(homeData);
        if (context.mounted) {
          initialize(context);
        }
        notifyListeners();
      }
    }
  }

  onClickScan(BuildContext context) async {
    if (Platform.isAndroid) {
      List<BluetoothDevice> mBondList = [];
      mBondList = await FlutterBluetoothSerial.instance.getBondedDevices();
      for (int i = 0; i < mBondList.length; i++) {
        final existingIndex = mList.indexWhere(
          (element) => element.id == mBondList[i].address,
        );
        if (existingIndex >= 0) {
          mList[existingIndex].status = DeviceStatus.connected;
        }
        notifyListeners();
      }

      streamSubscription = FlutterBluetoothSerial.instance
          .startDiscovery()
          .listen((discoveryResult) {
            final existingIndex = mList.indexWhere(
              (element) => element.id == discoveryResult.device.address,
            );
            if (existingIndex >= 0) {
              mList[existingIndex].status = DeviceStatus.connected;
            }
            notifyListeners();
          });

      streamSubscription!.onDone(() {
        notifyListeners();
      });
      streamSubscription!.onError((_) {
        notifyListeners();
      });
    } else if (Platform.isIOS) {}
  }

  void onClickItemName(BuildContext context, DeviceModel item) async {
    await DeviceView().launch(context);
    // Navigator.push(context, Builder(builder: (context) => DeviceView(DeviceModel: item)));
    if (context.mounted) {
      initialize(context);
    }
    notifyListeners();
  }

  void onChangeItemInfo(BuildContext context, DeviceModel item) async {
    HomeData? homeData = await sharedService.getHomeData();
    if (homeData != null) {
      mList = homeData.deviceList ?? [];
      final whereIndex = mList.indexWhere((element) => element.id == item.id);
      if (whereIndex >= 0) {
        mList[whereIndex].name = item.name;
        mList[whereIndex].description = item.description;
        sharedService.saveHomeData(homeData);
        if (context.mounted) {
          initialize(context);
        }
        notifyListeners();
      }
    }
  }
}
