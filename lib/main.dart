import 'package:bot_toast/bot_toast.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'service/language_change_provider.dart';
import 'settings/locator.dart';
import 'utils/color_utils.dart';
import 'utils/string_utils.dart';
import 'utils/widget_utils.dart';
import 'views/auth/splash_view.dart';
import './firebase_options.dart';

Future<void> main() async {
  
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  setupLocator();

  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]).then((
    _,
  ) {
    runApp(const MyApp());
  });
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  // Create a GlobalKey for Navigator
  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<LanguageChangeProvider>(
      create: (context) => LanguageChangeProvider(),
      child: Builder(
        builder:
            ((context) => MaterialApp(
              navigatorKey: navigatorKey,  // Set navigatorKey here
              title: StringUtils.txtAppName,
              debugShowCheckedModeBanner: false,
              locale:
                  Provider.of<LanguageChangeProvider>(
                    context,
                    listen: true,
                  ).getCurLocale,
              theme: ThemeData(
                primaryColor: ColorUtils.appColorPrimary,
                primaryColorDark: ColorUtils.appColorPrimaryDark,
                colorScheme: ColorScheme.fromSwatch().copyWith(
                  secondary: ColorUtils.appColorPrimaryDark,
                ),
                brightness: Brightness.light,
                textSelectionTheme: TextSelectionThemeData(
                  selectionHandleColor: Colors.transparent,
                  selectionColor: ColorUtils.appColorPrimary,
                ),
              ),
              scrollBehavior: MyCustomScrollBehavior(),
              builder: BotToastInit(),
              navigatorObservers: [BotToastNavigatorObserver()],
              home: const SplashView(),
            )),
      ),
    );
  }
}
