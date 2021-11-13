import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:robofy/Pages/Notifications.dart';
import 'package:robofy/components/NotificationBadge.dart';
import 'package:robofy/model/push_notification.dart';
import 'package:overlay_support/overlay_support.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  print("Handling a background message: ${message.messageId}");
}

class HomePage extends StatefulWidget {
  HomePage(
      {Key? key,
      required this.title,
      required this.logoutAction,
      required this.picture,
      required this.fullname,
      required this.nickname})
      : super(key: key);
  final String? picture;
  final String title;
  final String fullname;
  final String nickname;
  final logoutAction;
  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  var logoutAction;
  var name;
  var picture;
  var message = "";
  late final FirebaseMessaging _messaging;
  late int _totalNotifications;
  var edit = false;
  PushNotification? _notificationInfo;
  static var fcmToken;
  final ButtonStyle style =
      ElevatedButton.styleFrom(textStyle: const TextStyle(fontSize: 20));
  final fullname = TextEditingController();
  final phonenum = TextEditingController();

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
    FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(
        alert: true, badge: true, sound: true);
    fcmToken = await _messaging.getToken();
    print('token ${fcmToken}');
    CollectionReference collectionReference =
        FirebaseFirestore.instance.collection('users');

    QuerySnapshot querySnapshot = await collectionReference.get();
    for (var data in querySnapshot.docs) {
      if (data['utoken'] == fcmToken) {
        setState(() {
          fullname.text = data['uname'];
          phonenum.text = data['uphone'];
        });
      }
    }
    createUserDetails();
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
        print("img : ${message.data['img']}");
        setState(() {
          _notificationInfo = notification;
          _totalNotifications++;
        });

        if (_notificationInfo != null) {
          // For displaying the notification as an overlay
          showSimpleNotification(
            Text(
              _notificationInfo!.title!,
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
              _notificationInfo!.body!,
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

  createUserDetails() async {
    fcmToken = await _messaging.getToken();
    CollectionReference collectionReference =
        FirebaseFirestore.instance.collection('users');

    QuerySnapshot querySnapshot = await collectionReference.get();
    for (var data in querySnapshot.docs) {
      if (data['uid'] == widget.nickname) {
        FirebaseFirestore.instance
            .collection('users')
            .doc(data.id)
            .update({'utoken': fcmToken});
        print("User already exists");
        return;
      }
    }
    Map<String, dynamic> inidata = {
      "uid": widget.nickname,
      "uname": widget.fullname,
      "uphone": "",
      "utoken": fcmToken
    };
    collectionReference.add(inidata);
    print("new user created successfully");
  }

  logout() async {
    await widget.logoutAction();
    // fcmToken = await _messaging.getToken();
    // Map<String, dynamic> inidata = {
    //   "uname": "",
    //   "uphone": "",
    //   "utoken": "${fcmToken}"
    // };
    // CollectionReference collectionReference =
    //     FirebaseFirestore.instance.collection('users');

    // QuerySnapshot querySnapshot = await collectionReference.get();
    // for (var data in querySnapshot.docs) {
    //   if (data['utoken'] == inidata['utoken']) return;
    //   if (data.id == "T9gZlGEojjqArWDIJcjQ") {
    //     FirebaseFirestore.instance
    //         .collection('users')
    //         .doc(data.id)
    //         .update({'utoken': inidata['utoken']});
    //   }
    // }
    // collectionReference.add(inidata);
    // print("token saved successfully");
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
        _notificationInfo = notification;
        _totalNotifications++;
      });
    }
  }

  sendHiToAll() async {
    fcmToken = await _messaging.getToken();
    print("token : ${fcmToken}");
    List<String> tokens = [];
    CollectionReference collectionReference =
        FirebaseFirestore.instance.collection('users');

    QuerySnapshot querySnapshot = await collectionReference.get();
    for (var data in querySnapshot.docs) {
      tokens.add(data['utoken']);
    }
    final response = await http.post(
      Uri.parse('https://fcm.googleapis.com/fcm/send'),
      headers: <String, String>{
        'Content-Type': 'application/json; charset=UTF-8',
        'Authorization':
            'key=AAAA0SGyhMY:APA91bEj0I7DbU3t4wPIZrRTRpn_a8aDAYb-ctflv3jOhit9g9lCKGJZiNXln3AOS_73Hh1ixqiPBAUK3KSWdMxzWCpRBLEcELPQVifkiVaVW038rWlqGf9o6qWYYIhF7q-tJbm4YDo6'
      },
      body: jsonEncode(<String, dynamic>{
        'notification': {
          'title': widget.fullname,
          "body": "Hello",
          "icon": widget.picture.toString(),
          "sound": 'alert',
          "priority": 'high'
        },
        "data": {
          "img": widget.picture.toString(),
          "sound": "arrive",
          "click_action": "FLUTTER_NOTIFICATION_CLICK",
          "status": "done",
        },
        "apns": {
          "headers": {"apns-priority": "5", "apns-push-type": "background"},
          "payload": {
            "aps": {"content-available": 1}
          }
        },
        "registration_ids": tokens
      }),
    );
    print('hi ${response.body}');
  }

  updateUserDetails() async {
    fcmToken = await _messaging.getToken();

    CollectionReference collectionReference =
        FirebaseFirestore.instance.collection('users');

    QuerySnapshot querySnapshot = await collectionReference.get();
    for (var data in querySnapshot.docs) {
      if (data['uid'] == widget.nickname) {
        FirebaseFirestore.instance
            .collection('users')
            .doc(data.id)
            .update({'uphone': phonenum.text});
      }
      // if (data.id == "T9gZlGEojjqArWDIJcjQ") {
      //
      // }
    }
  }

  @override
  void initState() {
    _totalNotifications = 0;
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
        _notificationInfo = notification;
        _totalNotifications++;
      });
    });

    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: Text(widget.title),
          brightness: Brightness.dark,
          backgroundColor: Colors.red.shade400,
          actions: <Widget>[
            FlatButton(
              textColor: Colors.white,
              onPressed: () {
                print("bell clicked");
                Navigator.push(
                    context,
                    NotificationsPage(_messaging, _totalNotifications,
                        _notificationInfo, fcmToken));
              },
              child: Icon(
                Icons.notifications,
                color: Colors.white,
                size: 30,
              ),
              shape: CircleBorder(side: BorderSide(color: Colors.transparent)),
            ),
          ],
        ),
        body: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                margin: EdgeInsets.all(8),
                width: 150,
                height: 150,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  image: DecorationImage(
                      image: NetworkImage(widget.picture.toString()),
                      fit: BoxFit.cover),
                ),
              ),
              // edit == true
              //     ? Padding(
              //         padding: const EdgeInsets.symmetric(
              //             horizontal: 8, vertical: 16),
              //         child: TextFormField(
              //           controller: fullname,
              //           enabled: edit,
              //           decoration: const InputDecoration(
              //             border: UnderlineInputBorder(),
              //             hintText: 'Enter your Fullname',
              //           ),
              //         ),
              //       )
              //     :
              Text('Name : ${widget.fullname}'),
              edit == true
                  ? Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 16),
                      child: TextFormField(
                        controller: phonenum,
                        enabled: edit,
                        decoration: const InputDecoration(
                          border: UnderlineInputBorder(),
                          hintText: 'Enter Your phonenumber',
                        ),
                      ),
                    )
                  : Text('Phone Number : ${phonenum.text}'),
              Center(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      margin: const EdgeInsets.only(right: 10.0),
                      child: ElevatedButton(
                        style: style,
                        onPressed: () {
                          setState(() {
                            fullname.text = widget.fullname;
                            edit = !edit;
                          });
                          print("bell clicked");
                        },
                        child: edit == true
                            ? Icon(Icons.cancel_outlined)
                            : Icon(Icons.edit_outlined),
                      ),
                    ),
                    edit == true
                        ? ElevatedButton(
                            style: style,
                            onPressed: () {
                              updateUserDetails();
                              setState(() {
                                edit = !edit;
                              });
                              print("userdetails updated");
                            },
                            child: Icon(Icons.save_outlined),
                          )
                        : Text(''),
                  ],
                ),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  textStyle: const TextStyle(fontSize: 20),
                  primary: Colors.green,
                ),
                onPressed: sendHiToAll,
                child: const Text('send Hello'),
              ),
              Container(
                margin: EdgeInsets.only(top: 300.0),
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                      textStyle:
                          const TextStyle(fontSize: 25, color: Colors.red),
                      primary: Colors.red.shade100,
                      padding: EdgeInsets.only(
                          left: 40, right: 40, bottom: 10, top: 10)),
                  onPressed: logout,
                  child: const Text(
                    'signout',
                    style: TextStyle(color: Colors.red),
                  ),
                ),
              ),
            ],
          ),
        ));
  }
}
