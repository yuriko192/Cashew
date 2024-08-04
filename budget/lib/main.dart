import 'dart:convert';
import 'package:budget/functions.dart';
import 'package:budget/pages/autoTransactionsPageEmail.dart';
import 'package:budget/struct/defaultPreferences.dart';
import 'package:budget/struct/iconObjects.dart';
import 'package:budget/struct/keyboardIntents.dart';
import 'package:budget/widgets/fadeIn.dart';
import 'package:budget/struct/languageMap.dart';
import 'package:budget/struct/initializeBiometrics.dart';
import 'package:budget/widgets/openBottomSheet.dart';
import 'package:budget/widgets/util/appLinks.dart';
import 'package:budget/widgets/util/onAppResume.dart';
import 'package:budget/widgets/util/watchForDayChange.dart';
import 'package:budget/widgets/watchAllWallets.dart';
import 'package:budget/database/tables.dart';
import 'package:budget/pages/onBoardingPage.dart';
import 'package:budget/struct/databaseGlobal.dart';
import 'package:budget/struct/settings.dart';
import 'package:budget/struct/notificationsGlobal.dart';
import 'package:budget/widgets/navigationSidebar.dart';
import 'package:budget/widgets/globalLoadingProgress.dart';
import 'package:budget/struct/scrollBehaviorOverride.dart';
import 'package:budget/widgets/globalSnackbar.dart';
import 'package:budget/struct/initializeNotifications.dart';
import 'package:budget/widgets/navigationFramework.dart';
import 'package:budget/widgets/restartApp.dart';
import 'package:budget/struct/customDelayedCurve.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:budget/colors.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:device_preview/device_preview.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:easy_localization/easy_localization.dart';

// Requires hot restart when changed
bool enableDevicePreview = false && kDebugMode;
bool allowDebugFlags = true || kIsWeb;
bool allowDangerousDebugFlags = kDebugMode;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await EasyLocalization.ensureInitialized();
  sharedPreferences = await SharedPreferences.getInstance();
  database = await constructDb('db');
  notificationPayload = await initializeNotifications();
  entireAppLoaded = false;
  currenciesJSON = await json.decode(
      await rootBundle.loadString('assets/static/generated/currencies.json'));
  languageNamesJSON = await json
      .decode(await rootBundle.loadString('assets/static/language-names.json'));
  await initializeSettings();
  tz.initializeTimeZones();
  final String? locationName = await FlutterTimezone.getLocalTimezone();
  tz.setLocalLocation(tz.getLocation(locationName ?? "America/New_York"));
  iconObjects.sort((a, b) => (a.mostLikelyCategoryName ?? a.icon)
      .compareTo((b.mostLikelyCategoryName ?? b.icon)));
  setHighRefreshRate();
  runApp(
    DevicePreview(
      enabled: enableDevicePreview,
      builder: (context) => EasyLocalization(
        // The custom LocaleLoader only references the LangCode
        useOnlyLangCode: false,
        assetLoader: RootBundleAssetLoaderCustomLocaleLoader(),
        supportedLocales: supportedLocales.values.toList(),
        path: 'assets/translations/generated',
        useFallbackTranslations: true,
        fallbackLocale: supportedLocales.values.toList().first,
        child: RestartApp(
          child: InitializeApp(key: appStateKey),
        ),
      ),
    ),
  );
}

late Map<String, dynamic> currenciesJSON;
late Map<String, dynamic> languageNamesJSON;
bool authAvailable = false;
late bool entireAppLoaded;
late PackageInfo packageInfoGlobal;

GlobalKey<_InitializeAppState> appStateKey = GlobalKey();
GlobalKey<PageNavigationFrameworkState> pageNavigationFrameworkKey =
    GlobalKey();

class InitializeApp extends StatefulWidget {
  InitializeApp({Key? key}) : super(key: key);

  @override
  State<InitializeApp> createState() => _InitializeAppState();
}

class _InitializeAppState extends State<InitializeApp> {
  void refreshAppState() {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return App(key: ValueKey("Main App"));
  }
}

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

class App extends StatelessWidget {
  const App({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // FeatureDiscovery(
    //   child:
    print("Rebuilt Material App");

    return MaterialApp(
      showPerformanceOverlay: kProfileMode,
      localizationsDelegates: context.localizationDelegates,
      supportedLocales: context.supportedLocales,
      locale:
          enableDevicePreview ? DevicePreview.locale(context) : context.locale,
      // localeListResolutionCallback: (systemLocales, supportedLocales) {
      //   print("LOCALE:" + context.locale.toString());
      //   print("LOCALE:" + Platform.localeName);
      //   return null;
      // },
      shortcuts: shortcuts,
      actions: keyboardIntents,
      themeAnimationDuration: Duration(milliseconds: 400),
      themeAnimationCurve: CustomDelayedCurve(),
      key: ValueKey('CashewAppMain'),
      title: 'Cashew',
      navigatorKey: navigatorKey,
      theme: getLightTheme(),
      darkTheme: getDarkTheme(),
      scrollBehavior: ScrollBehaviorOverride(),
      themeMode: getSettingConstants(appStateSettings)["theme"],
      home: AnimatedSwitcher(
          duration: Duration(milliseconds: 1200),
          switchInCurve: Curves.easeInOutCubic,
          switchOutCurve: Curves.easeInOutCubic,
          transitionBuilder: (Widget child, Animation<double> animation) {
            final inAnimation =
                Tween<Offset>(begin: Offset(-1.0, 0.0), end: Offset(0.0, 0.0))
                    .animate(animation);
            final outAnimation =
                Tween<Offset>(begin: Offset(1.0, 0.0), end: Offset(0.0, 0.0))
                    .animate(animation);

            if (child.key == ValueKey("Onboarding")) {
              return ClipRect(
                child: SlideTransition(
                  position: inAnimation,
                  child: child,
                ),
              );
            } else {
              return ClipRect(
                child: SlideTransition(position: outAnimation, child: child),
              );
            }
          },
          child: appStateSettings["hasOnboarded"] != true
              ? OnBoardingPage(key: ValueKey("Onboarding"))
              : PageNavigationFramework(
                  key: pageNavigationFrameworkKey,
                  widthSideNavigationBar: getWidthNavigationSidebar(context),
                )),
      builder: (context, child) {
        if (kReleaseMode) {
          ErrorWidget.builder = (FlutterErrorDetails errorDetails) {
            return Container(color: Colors.transparent);
          };
        }

        Widget mainWidget = OnAppResume(
          updateGlobalAppLifecycleState: true,
          onAppResume: () async {
            await setHighRefreshRate();
          },
          child: InitializeBiometrics(
            child: InitializeNotificationService(
              child: InitializeAppLinks(
                child: WatchForDayChange(
                  child: WatchSelectedWalletPk(
                    child: WatchAllWallets(
                      child: Stack(
                        children: [
                          Row(
                            children: [
                              AnimatedContainer(
                                duration: appStateSettings["appAnimations"] !=
                                        AppAnimations.all.index
                                    ? Duration.zero
                                    : Duration(milliseconds: 1500),
                                curve: Curves.easeInOutCubicEmphasized,
                                width: getWidthNavigationSidebar(context),
                                color: Theme.of(context).colorScheme.background,
                              ),
                              Expanded(
                                child: Builder(builder: (context) {
                                  double rightPaddingSafeArea =
                                      MediaQuery.paddingOf(context).right;
                                  bool hasRightSafeArea =
                                      rightPaddingSafeArea > 0;
                                  double leftPaddingSafeArea =
                                      MediaQuery.paddingOf(context).left;
                                  bool hasLeftSafeArea =
                                      leftPaddingSafeArea > 0 &&
                                          getIsFullScreen(context) == false;
                                  // Only enable left safe area if no navigation sidebar
                                  return Stack(
                                    children: [
                                      hasRightSafeArea || hasLeftSafeArea
                                          ? Container(
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .background,
                                            )
                                          : SizedBox.shrink(),
                                      hasRightSafeArea || hasLeftSafeArea
                                          ? Padding(
                                              padding: EdgeInsets.only(
                                                right: hasRightSafeArea
                                                    ? rightPaddingSafeArea
                                                    : 0,
                                                left: hasLeftSafeArea
                                                    ? leftPaddingSafeArea
                                                    : 0,
                                              ),
                                              child: ClipRRect(
                                                  borderRadius:
                                                      BorderRadius.horizontal(
                                                    right: hasRightSafeArea
                                                        ? Radius.circular(25)
                                                        : Radius.circular(0),
                                                    left: hasLeftSafeArea
                                                        ? Radius.circular(25)
                                                        : Radius.circular(0),
                                                  ),
                                                  child: child ??
                                                      SizedBox.shrink()),
                                            )
                                          : child ?? SizedBox.shrink(),
                                      GlobalSnackbar(key: snackbarKey),
                                      // SignInWithGoogleFlyIn(),
                                      hasRightSafeArea
                                          ? Align(
                                              alignment: Alignment.centerRight,
                                              child: Container(
                                                width: rightPaddingSafeArea,
                                                color: Theme.of(context)
                                                    .colorScheme
                                                    .background,
                                              ),
                                            )
                                          : SizedBox.shrink(),
                                      hasLeftSafeArea
                                          ? Align(
                                              alignment: Alignment.centerLeft,
                                              child: Container(
                                                width: leftPaddingSafeArea,
                                                color: Theme.of(context)
                                                    .colorScheme
                                                    .background,
                                              ),
                                            )
                                          : SizedBox.shrink(),
                                      // Gradient fade to right overflow, disabled for now
                                      // because many pages have full screen elements/banners etc
                                      // hasRightSafeArea
                                      //     ? Padding(
                                      //         padding: EdgeInsets.only(
                                      //             right: rightPaddingSafeArea),
                                      //         child: Align(
                                      //           alignment: Alignment.centerRight,
                                      //           child: Container(
                                      //             width: 12,
                                      //             foregroundDecoration: BoxDecoration(
                                      //               gradient: LinearGradient(
                                      //                 colors: [
                                      //                   Theme.of(context)
                                      //                       .colorScheme.background
                                      //                       .withOpacity(0.0),
                                      //                   Theme.of(context).colorScheme.background,
                                      //                 ],
                                      //                 begin: Alignment.centerLeft,
                                      //                 end: Alignment.centerRight,
                                      //                 stops: [0.1, 1],
                                      //               ),
                                      //             ),
                                      //           ),
                                      //         ),
                                      //       )
                                      //     : SizedBox.shrink(),
                                    ],
                                  );
                                }),
                              ),
                            ],
                          ),
                          NavigationSidebar(key: sidebarStateKey),
                          // The persistent global Widget stack (stays on navigation change)
                          GlobalLoadingIndeterminate(
                              key: loadingIndeterminateKey),
                          GlobalLoadingProgress(key: loadingProgressKey),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );

        if (kIsWeb) {
          return FadeIn(
              duration: Duration(milliseconds: 1000), child: mainWidget);
        } else {
          return mainWidget;
        }
      },
      // ),
    );
  }
}
