import 'package:device_tracking/extentions/widget_extensions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';
import 'dart:io';

import '../../utils/color_utils.dart';
import '../../utils/size_utils.dart';
import '../../utils/string_utils.dart';
import '../../utils/widget_utils.dart';

// ignore: must_be_immutable
class ItemBluetoothPairedDeviceView extends StatefulWidget {
  ItemBluetoothPairedDeviceView({
    super.key,
    required this.title,
    required this.address,
    required this.device,
    this.onItemClicked,
    this.onClickConnect,
    this.isDevicePaired,
  });

  final String title;
  final String address;
  final dynamic device;
  Function? onItemClicked;
  Function? onClickConnect;
  Function? isDevicePaired;

  @override
  State<StatefulWidget> createState() => _ItemBluetoothPairedDeviceViewState();
}

class _ItemBluetoothPairedDeviceViewState
    extends State<ItemBluetoothPairedDeviceView> {
  @override
  Widget build(BuildContext context) {
    bool platformStateIsConnected = false;
    bool platformStateIsDisconnected = false;
    //    bool platformStateIsPaired = widget.isDevicePaired == null ? false : widget.isDevicePaired!()??false;
    //    bool platformStateIsPaired = widget.isDevicePaired == true;
    bool platformStateIsPaired =
        widget.isDevicePaired != null && widget.isDevicePaired == true;

    if (Platform.isAndroid) {
      // platformStateIsConnected = widget.device.isBonded &&
      //                             widget.device.isConnected;
      // platformStateIsDisconnected = widget.device.isBonded;
      platformStateIsConnected = widget.device.isConnected;
      platformStateIsDisconnected = widget.device.isDisconnected;
    } else if (Platform.isIOS) {
      platformStateIsConnected = widget.device.isConnected;
      platformStateIsDisconnected = widget.device.isDisconnected;
      print(
        ">>> item: isDisCon: ${platformStateIsDisconnected} --- isPaired: ${platformStateIsPaired}",
      );
    }
    return GestureDetector(
      onTap: () {
        if (widget.onItemClicked != null) {
          widget.onItemClicked!();
        }
      },
      child: Column(
        children: <Widget>[
          Container(
            color: ColorUtils.appColorTransparent,
            padding: const EdgeInsets.fromLTRB(0, 15, 0, 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: <Widget>[
                SizedBox(
                  child: Icon(
                    Icons.bluetooth_outlined,
                    color:
                        platformStateIsConnected
                            ? ColorUtils.appColorGreen
                            : ColorUtils.appColorWhite_50,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: SizedBox(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Container(
                          child: textView(
                            widget.title,
                            fontSize: SizeUtils.textSizeLargeMedium,
                            textColor: ColorUtils.appColorWhite,
                          ),
                        ),
                        Container(
                          child: textView(
                            widget.address,
                            fontSize: SizeUtils.textSizeSmall,
                            textColor: ColorUtils.appColorWhite_50,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Container(
                  margin: const EdgeInsets.fromLTRB(10, 0, 0, 0),
                  alignment: Alignment.center,
                  child: RoundButton(
                    isStroked: true,
                    height: 30,
                    padding: const EdgeInsets.all(0),
                    textContent:
                        platformStateIsDisconnected && platformStateIsPaired
                            ? StringUtils.txtDisconnected
                            : StringUtils.txtUnpaired,
                    textSize: SizeUtils.textSizeMedium,
                    textColor: ColorUtils.appColorWhite_50,
                    strokeColor: ColorUtils.appColorWhite_20,
                    radius: 5,
                    onPressed: () {
                      if (widget.onClickConnect != null) {
                        widget.onClickConnect!();
                      }
                    },
                  ),
                ).visible(!(platformStateIsConnected)),
                Container(
                  margin: const EdgeInsets.fromLTRB(10, 0, 0, 0),
                  alignment: Alignment.center,
                  child: RoundButton(
                    isStroked: true,
                    height: 30,
                    padding: const EdgeInsets.all(0),
                    textContent: StringUtils.txtConnected,
                    textSize: SizeUtils.textSizeSMedium,
                    strokeColor: ColorUtils.appColorWhite_20,
                    radius: 5,
                    onPressed: () {
                      if (widget.onClickConnect != null) {
                        widget.onClickConnect!();
                      }
                    },
                  ),
                ).visible(platformStateIsConnected),
              ],
            ),
          ),
          Container(color: ColorUtils.appColorWhite_20, height: 0.5),
        ],
      ),
    );
  }
}
