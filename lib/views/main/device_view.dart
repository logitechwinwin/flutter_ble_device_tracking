import 'package:device_tracking/model/common/device_model.dart';
import 'package:device_tracking/views/dialog/edit_text_dlg.dart';
import 'package:device_tracking/views/items/item_device_view.dart';
import 'package:flutter/material.dart';
import 'package:stacked/stacked.dart';

import '../../../utils/color_utils.dart';
import '../../../utils/size_utils.dart';
import '../../../utils/widget_utils.dart';
import '../../utils/image_utils.dart';
import '../../utils/string_utils.dart';
import '../../utils/system_utils.dart';
import '../../view_models/main/device_view_model.dart';

class DeviceView extends StatefulWidget {
  DeviceView({this.selectedIndex, super.key});

  int? selectedIndex;

  @override
  State<DeviceView> createState() => _DeviceViewState();
}

class _DeviceViewState extends State<DeviceView> with TickerProviderStateMixin {
  @override
  Widget build(BuildContext context) {
    return ViewModelBuilder<DeviceViewModel>.reactive(
      viewModelBuilder: () => DeviceViewModel(),
      builder: (context, model, child) => buildWidget(context, model, child),
      onViewModelReady: (viewModel) => viewModel.initialize(context),
    );
  }

  @override
  void initState() {
    super.initState();
  }

  buildWidget(BuildContext context, DeviceViewModel model, Widget? child) {
    setStatusBarColor(ColorUtils.appColorPrimaryDark);
    var width = MediaQuery.of(context).size.width;
    var height = MediaQuery.of(context).size.height;

    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (result, details) async {
        if (result) return;
        showDialog(
          context: context,
          builder: (BuildContext dlgContext) => const ExitDialog(),
        );
      },
      child: SizedBox(
        child: Scaffold(
          backgroundColor: ColorUtils.appColorPrimaryDark,
          appBar: AppBar(
            backgroundColor: ColorUtils.appColorPrimaryDark,
            title: textView(
              StringUtils.txtDevice,
              textColor: ColorUtils.appColorWhite,
              fontSize: SizeUtils.textSizeXLarge,
              fontWeight: FontWeight.bold,
            ),
            leading: IconButton(
              onPressed: () {
                model.onClickBack(context);
                //    Navigator.pop(context);
              },
              icon: Icon(Icons.arrow_back, color: ColorUtils.appColorWhite),
            ),
          ),
          body: Center(
            child: Builder(
              builder: (context) {
                return Column(
                  children: [
                    Container(
                      width: width * 0.75,
                      height: height * 0.75,
                      alignment: Alignment.center,
                      padding: const EdgeInsets.fromLTRB(0, 0, 0, 0),
                      child: textView(
                        //model.userModel!.userName,
                        "Device Name",
                        textColor: ColorUtils.appColorWhite,
                        fontSize: SizeUtils.textSizeXLarge,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
