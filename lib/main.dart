import 'dart:io';
import 'dart:convert';

/// -----------------------------------
///          External Packages
/// -----------------------------------

import 'package:flutter/material.dart';

import 'package:http/http.dart' as http;
import 'package:flutter_appauth/flutter_appauth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

final FlutterAppAuth appAuth = FlutterAppAuth();
final FlutterSecureStorage secureStorage = const FlutterSecureStorage();

/// -----------------------------------
///           Auth0 Variables
/// -----------------------------------

String AUTH0_DOMAIN;
String AUTH0_CLIENT_ID;

String AUTH0_REDIRECT_URI;
String AUTH0_ISSUER;

/// -----------------------------------
///           Profile Widget
/// -----------------------------------

class Profile extends StatelessWidget {
  final logoutAction;
  final String name;
  final String picture;

  Profile(this.logoutAction, this.name, this.picture);

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        Container(
          width: 150,
          height: 150,
          decoration: BoxDecoration(
            border: Border.all(color: Colors.blue, width: 4.0),
            shape: BoxShape.circle,
            image: DecorationImage(
              fit: BoxFit.fill,
              image: NetworkImage(picture ?? ''),
            ),
          ),
        ),
        SizedBox(height: 24.0),
        Text('Name: $name'),
        SizedBox(height: 48.0),
        RaisedButton(
          onPressed: () {
            logoutAction();
          },
          child: Text('Logout'),
        ),
      ],
    );
  }
}

/// -----------------------------------
///            Login Widget
/// -----------------------------------

class Login extends StatelessWidget {
  final loginAction;
  final appleLoginAction;
  final String loginError;

  const Login({
    @required this.loginAction,
    @required this.appleLoginAction,
    this.loginError,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        RaisedButton(
          onPressed: () {
            loginAction();
          },
          child: Text('Login'),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 50.0),
          child: SignInWithAppleButton(
            onPressed: () => appleLoginAction(),
          ),
        ),
        Text(loginError ?? ''),
      ],
    );
  }
}

/// -----------------------------------
///                 App
/// -----------------------------------

Future<void> main() async {
  await DotEnv().load('.env');
  AUTH0_DOMAIN = DotEnv().env['AUTH0_DOMAIN'];
  AUTH0_CLIENT_ID = DotEnv().env['AUTH0_CLIENT_ID'];
  AUTH0_REDIRECT_URI = DotEnv().env['AUTH0_REDIRECT_URI'];
  AUTH0_ISSUER = 'https://$AUTH0_DOMAIN';
  print('AUTH0 DOMAIN: $AUTH0_DOMAIN');
  runApp(MyApp());
}

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

/// -----------------------------------
///              App State
/// -----------------------------------

class _MyAppState extends State<MyApp> {
  bool isBusy = false;
  bool isLoggedIn = false;
  String errorMessage;
  String name;
  String picture;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Auth0 Demo',
      home: Scaffold(
        appBar: AppBar(
          title: Text('Auth0 Demo'),
        ),
        body: Center(
          child: isBusy
              ? CircularProgressIndicator()
              : isLoggedIn
                  ? Profile(logoutAction, name, picture)
                  : Login(
                      loginAction: () => loginAction(),
                      appleLoginAction: () => appleLoginAction(),
                      loginError: errorMessage,
                    ),
        ),
      ),
    );
  }

  // handle ID token received from OAuth sign in process
  Map<String, dynamic> parseIdToken(String idToken) {
    final parts = idToken.split(r'.');
    assert(parts.length == 3);

    return jsonDecode(
      utf8.decode(
        base64Url.decode(base64Url.normalize(parts[1])),
      ),
    );
  }

  Future<Map> getUserDetails(String accessToken) async {
    final url = 'https://$AUTH0_DOMAIN/userinfo';
    final response = await http.get(
      url,
      headers: {'Authorization': 'Bearer $accessToken'},
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to get user details');
    }
  }

  Future<void> appleLoginAction() async {
    setState(() {
      isBusy = true;
      errorMessage = '';
    });
    AuthorizationCredentialAppleID credential;
    try {
      print('hiiiii');
      credential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
        webAuthenticationOptions: WebAuthenticationOptions(
          clientId: 'com.wordbud.applesignintest',
          redirectUri: Uri.parse(
            'https://5326590182919246.cn-hangzhou.fc.aliyuncs.com/2016-08-15/proxy/first_api/signInWithAppleCallback/',
          ),
        ),
        nonce: 'example-nonce',
        state: 'example-state',
      );
      print('got credential');
    } catch (e, s) {
      print('login error: $e - stack: $s');

      setState(() {
        isBusy = false;
        isLoggedIn = false;
        errorMessage = e.toString();
      });
    }

    print('Credential: $credential');
    try {
      // This is the endpoint that will convert an authorization code obtained
      // via Sign in with Apple into a session in your system
      print('posting to function compute');
      final url =
          'https://5326590182919246.cn-hangzhou.fc.aliyuncs.com/2016-08-15/proxy/first_api/signInWithApple/';
      // TODO: Improve null safety check for values given after first time signing in with apple
      final firstName = credential.givenName ?? 'first name';
      final lastName = credential.familyName ?? 'family name';
      final params = <String, String>{
        'code': credential.authorizationCode,
        'firstName': firstName,
        'lastName': lastName,
        'useBundleId': Platform.isIOS || Platform.isMacOS ? 'true' : 'false',
        if (credential.state != null) 'state': credential.state,
      };
      // final signInWithAppleEndpoint = Uri(
      //   scheme: 'https',
      //   host: '5326590182919246.cn-hangzhou.fc.aliyuncs.com',
      //   path: '/2016-08-15/proxy/first_api/signInWithApple',
      //   queryParameters: <String, String>{
      //     'code': credential.authorizationCode,
      //     'firstName': credential.givenName,
      //     'lastName': credential.familyName,
      //     'useBundleId': Platform.isIOS || Platform.isMacOS ? 'true' : 'false',
      //     if (credential.state != null) 'state': credential.state,
      //   },
      // );
      // print('Endpoint URI: $signInWithAppleEndpoint');
      print('credential identity token: ${credential.identityToken}');

      final session = await http.Client().post(
        url,
        body: params,
      );

      print('response body: ${session.body}');
      // final sessionDetails = await jsonDecode(session.body);

      await secureStorage.write(key: 'session_details', value: session.body);

      setState(() {
        isBusy = false;
        isLoggedIn = true;
        name = 'Koguma';
        picture =
            'https://png.pngtree.com/element_our/20200610/ourmid/pngtree-cute-potatoes-image_2242564.jpg';
      });
    } catch (e, s) {
      print('login error: $e - stack: $s');

      setState(() {
        isBusy = false;
        isLoggedIn = false;
        errorMessage = e.toString();
      });
    }
    // If we got this far, a session based on the Apple ID credential has been created in your system,
    // and you can now set this as the app's session
    // print(session);
  }

  Future<void> loginAction() async {
    setState(() {
      isBusy = true;
      errorMessage = '';
    });
    print('autho redirect uri in login: $AUTH0_REDIRECT_URI');
    try {
      final AuthorizationTokenResponse result =
          await appAuth.authorizeAndExchangeCode(
        AuthorizationTokenRequest(AUTH0_CLIENT_ID, AUTH0_REDIRECT_URI,
            issuer: 'https://$AUTH0_DOMAIN',
            scopes: [
              'openid',
              'profile',
              'offline_access'
            ],
            promptValues: [
              'login'
            ] // ignore any existing session; force interactive login prompt
            ),
      );

      final idToken = parseIdToken(result.idToken);
      final profile = await getUserDetails(result.accessToken);

      await secureStorage.write(
          key: 'refresh_token', value: result.refreshToken);

      setState(() {
        isBusy = false;
        isLoggedIn = true;
        name = idToken['name'];
        picture = profile['picture'];
      });
    } catch (e, s) {
      print('login error: $e - stack: $s');

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

  // further optimize this code by keeping track of accessTokenExpirationDateTime
  // and request a new accessToken only if the one at hand is expired.
  void initAction() async {
    final storedRefreshToken = await secureStorage.read(key: 'refresh_token');
    if (storedRefreshToken == null) return;

    setState(() {
      isBusy = true;
    });

    try {
      final response = await appAuth.token(
        TokenRequest(
          AUTH0_CLIENT_ID,
          AUTH0_REDIRECT_URI,
          issuer: AUTH0_ISSUER,
          refreshToken: storedRefreshToken,
        ),
      );

      final idToken = parseIdToken(response.idToken);
      final profile = await getUserDetails(response.accessToken);

      secureStorage.write(key: 'refresh_token', value: response.refreshToken);

      setState(() {
        isBusy = false;
        isLoggedIn = true;
        name = idToken['name'];
        picture = profile['picture'];
      });
    } catch (e, s) {
      print('error on refresh token: $e - stack: $s');
      logoutAction();
    }
  }
}
