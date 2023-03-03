import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:emartconsumer/constants.dart';
import 'package:emartconsumer/model/ConversationModel.dart';
import 'package:emartconsumer/model/CurrencyModel.dart';
import 'package:emartconsumer/model/HomeConversationModel.dart';
import 'package:emartconsumer/services/FirebaseHelper.dart';
import 'package:emartconsumer/services/helper.dart';
import 'package:emartconsumer/services/localDatabase.dart';
import 'package:emartconsumer/ui/StoreSelection/StoreSelection.dart';
import 'package:emartconsumer/ui/auth/AuthScreen.dart';
import 'package:emartconsumer/ui/chat/ChatScreen.dart';
import 'package:emartconsumer/ui/onBoarding/OnBoardingScreen.dart';
import 'package:emartconsumer/userPrefrence.dart';
import 'package:emartconsumer/utils/Styles.dart';
import 'package:firebase_auth/firebase_auth.dart' as auth;
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'model/User.dart';
import 'utils/DarkThemeProvider.dart';

Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  // If you're going to use other Firebase services in the background, such as Firestore,
  // make sure you call `initializeApp` before using other Firebase services.
  print('Handling a background message ${message.messageId}');
}

void showFlutterNotification(RemoteMessage message) {
  RemoteNotification? notification = message.notification;
  AndroidNotification? android = message.notification?.android;
  if (notification != null && android != null && !kIsWeb) {
    flutterLocalNotificationsPlugin.show(
      notification.hashCode,
      notification.title,
      notification.body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          channel.id,
          channel.name,
          channelDescription: channel.description,
          // TODO add a proper drawable resource to android, for now using
          //      one that already exists in example app.
          icon: android.smallIcon,
        ),
      ),
    );
  }
}

late AndroidNotificationChannel channel;

bool isFlutterLocalNotificationsInitialized = false;
late FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin;

Future<void> setupFlutterNotifications() async {
  if (isFlutterLocalNotificationsInitialized) {
    return;
  }
  channel = const AndroidNotificationChannel(
    'high_importance_channel', // id
    'High Importance Notifications', // title
    description: 'This channel is used for important notifications.', // description
    importance: Importance.high,
  );

  flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

  /// Create an Android Notification Channel.
  ///
  /// We use this channel in the `AndroidManifest.xml` file to override the
  /// default FCM channel to enable heads up notifications.
  await flutterLocalNotificationsPlugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()?.createNotificationChannel(channel);

  /// Update the iOS foreground notification presentation options to allow
  /// heads up notifications.
  await FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(
    alert: true,
    badge: true,
    sound: true,
  );
  isFlutterLocalNotificationsInitialized = true;
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  await EasyLocalization.ensureInitialized();

  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  if (!kIsWeb) {
    await setupFlutterNotifications();
  }

  await UserPreference.init();

  runApp(
    MultiProvider(
      providers: [
        Provider<CartDatabase>(
          create: (_) => CartDatabase(),
        )
      ],
      child: EasyLocalization(
          supportedLocales: const [Locale('en'), Locale('ar'), Locale('nl')],
          path: 'assets/translations',
          fallbackLocale: const Locale('en'),
          saveLocale: false,
          useOnlyLangCode: true,
          useFallbackTranslations: true,
          child: const MyApp()),
    ),
  );
}

class MyApp extends StatefulWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  MyAppState createState() => MyAppState();
}

class MyAppState extends State<MyApp> with WidgetsBindingObserver {
  /// this key is used to navigate to the appropriate screen when the
  /// notification is clicked from the system tray
  final GlobalKey<NavigatorState> navigatorKey = GlobalKey(debugLabel: 'Main Navigator');

  static User? currentUser;
  late StreamSubscription tokenStream;
  static Position selectedPosition = Position.fromMap({'latitude': 0.0, 'longitude': 0.0});

  // Set default `_initialized` and `_error` state to false
  bool _initialized = false, isColorLoad = false;
  bool _error = false;

  //  late Stream<StripeKeyModel> futureStirpe;
  //  String? data,d;

  // Define an async function to initialize FlutterFire
  void initializeFlutterFire() async {
    try {
      /// Wait for Firebase to initialize and set `_initialized` state to true

      FirebaseFirestore.instance.collection(Setting).doc("globalSettings").get().then((dineinresult) {
        if (dineinresult != null && dineinresult.exists && dineinresult.data() != null && dineinresult.data()!.containsKey("website_color")) {
          COLOR_PRIMARY = int.parse(dineinresult.data()!["website_color"].replaceFirst("#", "0xff"));
        }
        setState(() {
          isColorLoad = true;
        });
      });

      await FirebaseFirestore.instance.collection(Setting).doc("Version").get().then((value) {
        print(value.data());
        appVersion = value.data()!['app_version'].toString();
      });

      FirebaseMessaging.onMessage.listen(showFlutterNotification);

      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        _handleNotification(message.data, navigatorKey);
      });

      tokenStream = FireStoreUtils.firebaseMessaging.onTokenRefresh.listen((event) {
        if (currentUser != null) {
          print('token $event');
          currentUser!.fcmToken = event;
          FireStoreUtils.updateCurrentUser(currentUser!);
        }
      });

      setState(() {
        _initialized = true;
      });
    } catch (e) {
      // Set `_error` state to true if Firebase initialization fails
      setState(() {
        _error = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Show error message if initialization failed
    if (_error) {
      return MaterialApp(
          locale: context.locale,
          supportedLocales: context.supportedLocales,
          localizationsDelegates: context.localizationDelegates,
          home: Scaffold(
            body: Container(
              color: Colors.white,
              child: Center(
                  child: Column(
                children: [
                  const Icon(
                    Icons.error_outline,
                    color: Colors.red,
                    size: 25,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Failed to initialise firebase!'.tr(),
                    style: const TextStyle(color: Colors.red, fontSize: 25),
                  ),
                ],
              )),
            ),
          ));
    }

    // Show a loader until FlutterFire is initialized
    if (!_initialized || !isColorLoad) {
      return Container(
        color: Colors.white,
        child: Center(
          child: CircularProgressIndicator.adaptive(
            valueColor: AlwaysStoppedAnimation(Color(COLOR_PRIMARY)),
          ),
        ),
      );
    }

    return ChangeNotifierProvider(
      create: (_) {
        return themeChangeProvider;
      },
      child: Consumer<DarkThemeProvider>(
        builder: (context, value, child) {
          return MaterialApp(
              navigatorKey: navigatorKey,
              localizationsDelegates: context.localizationDelegates,
              locale: context.locale,
              supportedLocales: context.supportedLocales,
              debugShowCheckedModeBanner: false,
              theme: Styles.themeData(themeChangeProvider.darkTheme, context),
              home: const OnBoarding());
        },
      ),
    );

    // return MaterialApp(
    //     navigatorKey: navigatorKey,
    //     localizationsDelegates: context.localizationDelegates,
    //     supportedLocales: context.supportedLocales,
    //     locale: context.locale,
    //     title: ('EMART').tr(),
    //     // theme: ThemeData(
    //     //     fontFamily: 'Poppinsm',
    //         appBarTheme: AppBarTheme(
    //             centerTitle: true,
    //             color: Colors.transparent,
    //             elevation: 0,
    //             actionsIconTheme: IconThemeData(color: Color(COLOR_PRIMARY)),
    //             iconTheme: IconThemeData(color: Color(COLOR_PRIMARY)),
    //             systemOverlayStyle: SystemUiOverlayStyle.dark),
    //     //     bottomSheetTheme: const BottomSheetThemeData(backgroundColor: Colors.white),
    //     //     primaryColor: Color(COLOR_PRIMARY),
    //     //     iconTheme: const IconThemeData(color: Colors.white),
    //     //     brightness: Brightness.light),
    //     // darkTheme: ThemeData(
    //     //     fontFamily: 'Poppinsm',
    //         appBarTheme: AppBarTheme(
    //             centerTitle: true,
    //             color: Colors.transparent,
    //             elevation: 0,
    //             actionsIconTheme: IconThemeData(color: Color(COLOR_PRIMARY)),
    //             iconTheme: IconThemeData(color: Color(COLOR_PRIMARY)),
    //             systemOverlayStyle: SystemUiOverlayStyle.light)
    //     //     bottomSheetTheme: BottomSheetThemeData(backgroundColor: Colors.grey.shade900),
    //     //     primaryColor: Color(COLOR_PRIMARY),
    //     //     brightness: Brightness.dark),
    //     debugShowCheckedModeBanner: false,
    //     theme: Styles.themeData(themeChangeProvider.darkTheme, context),
    //
    //     // color: Color(COLOR_PRIMARY),
    //     home: const OnBoarding());
  }

  DarkThemeProvider themeChangeProvider = DarkThemeProvider();

  @override
  void initState() {
    initializeFlutterFire();
    WidgetsBinding.instance.addObserver(this);
    getCurrentAppTheme();
    super.initState();
  }

  void getCurrentAppTheme() async {
    themeChangeProvider.darkTheme = await themeChangeProvider.darkThemePreference.getTheme();
  }

  @override
  void dispose() {
    tokenStream.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {}
}

class OnBoarding extends StatefulWidget {
  const OnBoarding({Key? key}) : super(key: key);

  @override
  State createState() {
    return OnBoardingState();
  }
}

class OnBoardingState extends State<OnBoarding> {
  late Future<List<CurrencyModel>> futureCurrency;

  Future hasFinishedOnBoarding() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    bool finishedOnBoarding = (prefs.getBool(FINISHED_ON_BOARDING) ?? false);

    if (finishedOnBoarding) {
      auth.User? firebaseUser = auth.FirebaseAuth.instance.currentUser;
      if (firebaseUser != null) {
        User? user = await FireStoreUtils.getCurrentUser(firebaseUser.uid);
        print(user!.toJson().toString());
        if (user != null && user.role == USER_ROLE_CUSTOMER) {
          if (user.active) {
            user.active = true;
            user.role = USER_ROLE_CUSTOMER;
            user.fcmToken = await FireStoreUtils.firebaseMessaging.getToken() ?? '';
            await FireStoreUtils.updateCurrentUser(user);
            MyAppState.currentUser = user;
            isSkipLogin = false;
            pushReplacement(context, const StoreSelection());
          } else {
            user.lastOnlineTimestamp = Timestamp.now();
            user.fcmToken = "";
            await FireStoreUtils.updateCurrentUser(user);
            await auth.FirebaseAuth.instance.signOut();
            MyAppState.currentUser = null;
            pushReplacement(context, const AuthScreen());
          }

          //UserPreference.setUserId(userID: user.userID);
          //

        } else {
          pushReplacement(context, const AuthScreen());
        }
      } else {
        pushReplacement(context, const AuthScreen());
      }
    } else {
      pushReplacement(context, const OnBoardingScreen());
    }
  }

  @override
  void initState() {
    super.initState();
    hasFinishedOnBoarding();
    // futureCurrency= FireStoreUtils().getCurrency();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: CircularProgressIndicator.adaptive(
          valueColor: AlwaysStoppedAnimation(Color(COLOR_PRIMARY)),
        ),
      ),
    );
  }
}

/// this faction is called when the notification is clicked from system tray
/// when the app is in the background or completely killed
void _handleNotification(Map<String, dynamic> message, GlobalKey<NavigatorState> navigatorKey) {
  /// right now we only handle click actions on chat messages only
  try {
    print("data is ${message.toString()}");
    if (message.containsKey('members') && message.containsKey('isGroup') && message.containsKey('conversationModel')) {
      List<User> members = List<User>.from((jsonDecode(message['members']) as List<dynamic>).map((e) => User.fromPayload(e))).toList();
      ConversationModel conversationModel = ConversationModel.fromPayload(jsonDecode(message['conversationModel']));
      navigatorKey.currentState?.push(
        MaterialPageRoute(
          builder: (_) => ChatScreen(
            homeConversationModel: HomeConversationModel(members: members, conversationModel: conversationModel),
          ),
        ),
      );
    }
  } catch (e, s) {
    print('MyAppState._handleNotification $e $s');
  }
}
