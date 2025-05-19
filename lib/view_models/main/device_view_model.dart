import 'dart:async';
import 'dart:io';

import 'package:device_tracking/model/common/device_status.dart';
import 'package:device_tracking/utils/string_utils.dart';
import 'package:device_tracking/utils/system_utils.dart';
import 'package:device_tracking/utils/widget_utils.dart';
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

class DeviceViewModel extends BaseViewModel with WidgetsBindingObserver {
  List<DeviceModel> mList = [];

  initialize(BuildContext context) async {}

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  initUI(BuildContext context) {}

  onClickLogout(BuildContext context) async {}

  onClickProfile(BuildContext context) async {}

  onClickBluetooth(BuildContext context) async {}

  onClickItemDelete(BuildContext context, DeviceModel item) async {}

  onClickItemDisconnect(BuildContext context, DeviceModel item) async {}

  onClickScan(BuildContext context) async {}

  void onClickItemName(BuildContext context, DeviceModel item) {}

  onClickBack(BuildContext context) async {
    finishView(context);
  }
}
