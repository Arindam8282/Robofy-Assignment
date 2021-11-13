import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:robofy/components/NotificationBadge.dart';
import 'package:robofy/model/push_notification.dart';
import 'package:overlay_support/overlay_support.dart';

Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  print("Handling a background message: ${message.messageId}");
}

class NotificationsPage extends MaterialPageRoute<Null> {
  late final FirebaseMessaging _messaging;
  late int Notifications;
  PushNotification? _notifyInfo;
  var fcmToken;
  ButtonStyle style =
      ElevatedButton.styleFrom(textStyle: const TextStyle(fontSize: 20));
  // PageTwo(this._messaging,this.Notifications,
  //     this.notifyInfo,this.fcmToken);
  void registerNotification() async {
    await Firebase.initializeApp();
    _messaging = FirebaseMessaging.instance;

    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    NotificationSettings settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      provisional: false,
      sound: true,
    );
    fcmToken = await _messaging.getToken();
    print('token ${fcmToken}');
    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      print('User granted permission');

      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        print(
            'Message title: ${message.notification?.title}, body: ${message.notification?.body}, data: ${message.data} total: ${message}');

        // Parse the message received
        PushNotification notification = PushNotification(
          title: message.notification?.title,
          body: message.notification?.body,
          dataTitle: message.data['title'],
          dataBody: message.data['body'],
        );

        setState(() {
          _notifyInfo = notification;
          Notifications++;
        });

        if (_notifyInfo != null) {
          // For displaying the notification as an overlay
          showSimpleNotification(
            Text(
              _notifyInfo!.title!,
              style:
                  TextStyle(fontWeight: FontWeight.bold, color: Colors.black),
            ),
            leading: Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.red),
                shape: BoxShape.circle,
                image: DecorationImage(
                    image: NetworkImage(message.data['img'] != null
                        ? message.data['img']
                        : 'https://stockative.in/static/media/blank-profile.c3f94521.png'),
                    fit: BoxFit.fitHeight),
              ),
            ),
            subtitle: Text(
              _notifyInfo!.body!,
              style: TextStyle(color: Colors.grey.shade700),
            ),
            background: Colors.grey.shade200,
            duration: Duration(seconds: 2),
          );
        }
      });
    } else {
      print('User declined or has not accepted permission');
    }
  }

  // For handling notification when the app is in terminated state
  checkForInitialMessage() async {
    await Firebase.initializeApp();
    RemoteMessage? initialMessage =
        await FirebaseMessaging.instance.getInitialMessage();

    if (initialMessage != null) {
      PushNotification notification = PushNotification(
        title: initialMessage.notification?.title,
        body: initialMessage.notification?.body,
        dataTitle: initialMessage.data['title'],
        dataBody: initialMessage.data['body'],
      );

      setState(() {
        _notifyInfo = notification;
        Notifications++;
      });
    }
  }

  @override
  void initState() {
    Notifications = 0;
    registerNotification();
    checkForInitialMessage();
    // For handling notification when the app is in background
    // but not terminated
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      PushNotification notification = PushNotification(
        title: message.notification?.title,
        body: message.notification?.body,
        dataTitle: message.data['title'],
        dataBody: message.data['body'],
      );

      setState(() {
        _notifyInfo = notification;
        Notifications++;
      });
    });
  }

  NotificationsPage(
      this._messaging, this.Notifications, this._notifyInfo, this.fcmToken)
      : super(builder: (BuildContext ctx) {
          return Scaffold(
              appBar: AppBar(
                brightness: Brightness.dark,
                backgroundColor: Colors.red.shade400,
                elevation: 1.0,
              ),
              body: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'New Notification',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.black,
                        fontSize: 20,
                      ),
                    ),
                    SizedBox(height: 16.0),
                    _notifyInfo != null
                        ? Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'User: ${_notifyInfo.dataTitle ?? _notifyInfo.title}',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16.0,
                                ),
                              ),
                              SizedBox(height: 8.0),
                              Text(
                                'Message: ${_notifyInfo.dataBody ?? _notifyInfo.body}',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16.0,
                                ),
                              ),
                            ],
                          )
                        : Container(),
                  ],
                ),
              ));
        });
}
