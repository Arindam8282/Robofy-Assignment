import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_appauth/flutter_appauth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:robofy/Pages/Home.dart';
import 'package:overlay_support/overlay_support.dart';

final FlutterAppAuth appAuth = FlutterAppAuth();
final FlutterSecureStorage secureStorage = const FlutterSecureStorage();

///  ------------------------------
///     Auth Variables
///  ------------------------------
const AUTH0_DOMAIN = 'dev-flutterauth.us.auth0.com';
const AUTH0_CLIENT_ID = '5Mpbn48HeqCAAS1UMNRiVf4zMkb1D82O';

const AUTH0_REDIRECT_URI = 'com.adi.notify://login-callback';
const AUTH0_ISSUER = 'https://$AUTH0_DOMAIN';
void main() async {
  runApp(RobofyApp());
}

class RobofyApp extends StatefulWidget {
  @override
  _InitApp createState() => _InitApp();
}

// class RobofyApp extends StatelessWidget {
//   @override
//   Widget build(BuildContext context) {
//     return OverlaySupport(
//         child: MaterialApp(
//       debugShowCheckedModeBanner: false,
//       title: 'Robofy Assignment',
//       theme: ThemeData(
//         primarySwatch: Colors.red,
//       ),
//       home: HomePage(),
//     ));
//   }
// }

class Login extends StatelessWidget {
  final loginAction;
  final String? loginError;

  const Login(this.loginAction, this.loginError);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        Container(
          margin: EdgeInsets.only(top: 100.0),
        ),
        Text('Robofy Assignment', style: TextStyle(fontSize: 30)),
        Container(
            margin: EdgeInsets.only(top: 400.0),
            child: Center(
                child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Padding(
                    padding: EdgeInsets.only(left: 20, right: 20),
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                          textStyle: const TextStyle(fontSize: 25),
                          primary: Colors.green,
                          padding: EdgeInsets.only(
                              left: 40, right: 40, bottom: 10, top: 10)),
                      onPressed: () {
                        loginAction();
                      },
                      child: const Text('Login'),
                    )),
              ],
            ))),
        Text(loginError ?? ''),
      ],
    );
  }
}

class _InitApp extends State<RobofyApp> {
  bool isBusy = false;
  bool isLoggedIn = false;
  String? errorMessage;
  String? name;
  String? picture;
  String? nickname;

  @override
  Widget build(BuildContext context) {
    return OverlaySupport(
        child: MaterialApp(
            debugShowCheckedModeBanner: false,
            // title: 'Robofy Assignment',
            // theme: ThemeData(
            //   primarySwatch: Colors.red,
            // ),
            home: Scaffold(
                // appBar: AppBar(
                //   title: Text('Robofy Assignment'),
                // ),
                body: Center(
              child: isBusy
                  ? CircularProgressIndicator()
                  : isLoggedIn
                      ? HomePage(
                          title: 'Robofy App',
                          logoutAction: logoutAction,
                          picture: picture,
                          fullname: name.toString(),
                          nickname: nickname.toString(),
                        )
                      // Profile(
                      //     logoutAction: logoutAction,
                      //     name: name,
                      //     picture: picture)
                      : Login(loginAction, errorMessage),
            ))));
  }

  Map<String, dynamic> parseIdToken(String idToken) {
    final parts = idToken.split(r'.');
    assert(parts.length == 3);

    return jsonDecode(
        utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))));
  }

  Future<Map> getUserDetails(String accessToken) async {
    const url = 'https://$AUTH0_DOMAIN/userinfo';
    final response = await http.get(
      Uri.parse(url),
      headers: {'Authorization': 'Bearer $accessToken'},
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to get user details.');
    }
  }

  Future<void> loginAction() async {
    setState(() {
      isBusy = true;
      errorMessage = '';
    });

    try {
      final AuthorizationTokenResponse? result =
          await appAuth.authorizeAndExchangeCode(
        AuthorizationTokenRequest(
          AUTH0_CLIENT_ID,
          AUTH0_REDIRECT_URI,
          issuer: 'https://$AUTH0_DOMAIN',
          scopes: ['openid', 'profile', 'offline_access'],
          promptValues: ['login'],
        ),
      );

      final idToken = parseIdToken(result!.idToken.toString());
      final profile = await getUserDetails(result.accessToken.toString());

      await secureStorage.write(
          key: 'refresh_token', value: result.refreshToken);
      print("profile ${profile} ${idToken} ${result}");
      setState(() {
        isBusy = false;
        isLoggedIn = true;
        name = idToken['name'];
        picture = profile['picture'];
        nickname = profile['nickname'];
      });
    } catch (e, s) {
      print('Login error $e-stack:$s');
      setState(() {
        isBusy = false;
        isLoggedIn = false;
        errorMessage = e.toString();
      });
    }
  }

  void logoutAction() async {
    await secureStorage.delete(key: 'refresh_token');
    setState(() {
      isLoggedIn = false;
      isBusy = false;
    });
  }

  @override
  void initState() {
    initAction();
    super.initState();
  }

  void initAction() async {
    final storedRefreshToken = await secureStorage.read(key: 'refresh_token');
    if (storedRefreshToken == null) return;

    setState(() {
      isBusy = true;
    });

    try {
      final response = await appAuth.token(TokenRequest(
        AUTH0_CLIENT_ID,
        AUTH0_REDIRECT_URI,
        issuer: AUTH0_ISSUER,
        refreshToken: storedRefreshToken,
      ));

      final idToken = parseIdToken(response!.idToken.toString());
      final profile = await getUserDetails(response!.accessToken.toString());

      secureStorage.write(key: 'refresh_token', value: response.refreshToken);

      setState(() {
        isBusy = false;
        isLoggedIn = false;
        name = idToken['name'];
        picture = profile['picture'];
      });
    } catch (e, s) {
      print('error on refreseh token: $e - stack $s');
      logoutAction();
    }
  }
}
