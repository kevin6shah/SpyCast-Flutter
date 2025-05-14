import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:spycast/create_game.dart';
import 'package:spycast/firebase_options.dart';
import 'package:spycast/game_lobby.dart';
import 'package:spycast/instructions.dart';
import 'package:spycast/update_app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  final remoteConfig = FirebaseRemoteConfig.instance;
  await remoteConfig.setConfigSettings(
    RemoteConfigSettings(
      fetchTimeout: const Duration(seconds: 10),
      minimumFetchInterval: const Duration(hours: 1),
    ),
  );

  try {
    await remoteConfig.fetchAndActivate();
  } catch (e) {
    debugPrint('Failed to fetch and activate remote config: $e');
    // Optionally, you can set default values or handle the error gracefully
    remoteConfig.setDefaults(<String, dynamic>{
      'min_required_app_version': '1.0.0', // Example default value
    });
  }

  final minRequiredVersion = remoteConfig.getString('min_required_app_version');

  // Fetch the current app version
  final packageInfo = await PackageInfo.fromPlatform();
  final currentVersion = packageInfo.version;

  if (_isVersionOlder(currentVersion, minRequiredVersion)) {
    runApp(const UpdateRequiredApp());
  } else {
    runApp(const MyApp());
  }
}

bool _isVersionOlder(String current, String required) {
  final currentParts = current.split('.').map(int.parse).toList();
  final requiredParts = required.split('.').map(int.parse).toList();

  for (int i = 0; i < requiredParts.length; i++) {
    if (i >= currentParts.length || currentParts[i] < requiredParts[i]) {
      return true;
    } else if (currentParts[i] > requiredParts[i]) {
      return false;
    }
  }
  return false;
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MyHomePage(title: 'SpyCast');
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});
  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  Brightness _brightness = Brightness.light;
  Future<SharedPreferences>? _prefsFuture;
  SharedPreferences? _prefs;
  String? userName;
  bool _hasPromptedForUserName = false;

  @override
  void initState() {
    super.initState();
    _prefsFuture = SharedPreferences.getInstance().then((prefs) {
      _prefs = prefs;
      if (_prefs!.containsKey('userName')) {
        userName = _prefs!.getString('userName');
      }
      if (_prefs!.containsKey('brightness')) {
        setState(() {
          _brightness =
              _prefs!.getString('brightness') == 'dark'
                  ? Brightness.dark
                  : Brightness.light;
        });
      }
      return prefs;
    });
  }

  void _toggleBrightness() {
    setState(() {
      _brightness =
          _brightness == Brightness.light ? Brightness.dark : Brightness.light;
      _prefs!.setString(
        'brightness',
        _brightness == Brightness.light ? 'light' : 'dark',
      );
    });
  }

  bool isLight() {
    return _brightness == Brightness.light;
  }

  Future<bool> checkGameCode(String gameCode) async {
    DocumentSnapshot documentSnapshot =
        await FirebaseFirestore.instance
            .collection('games')
            .doc(gameCode)
            .get();
    if (documentSnapshot.exists) {
      return true;
    } else {
      return false;
    }
  }

  void showErrorDialog(BuildContext context, String invalidMessage) {
    showCupertinoDialog(
      context: context,
      builder: (context) {
        return CupertinoAlertDialog(
          title: const Text('Error'),
          content: Text('$invalidMessage. Please try again.'),
          actions: <Widget>[
            CupertinoDialogAction(
              child: const Text('OK'),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        );
      },
    );
  }

  bool validateGameCode(String gameCode) {
    if (gameCode.isEmpty ||
        gameCode.length != 6 ||
        !RegExp(r'^[A-Z]+$').hasMatch(gameCode)) {
      return false;
    }
    // Add any other validation logic here if needed
    return true;
  }

  Future<(int, int)> checkUserName(String userName, String gameCode) async {
    DocumentSnapshot documentSnapshot =
        await FirebaseFirestore.instance
            .collection('games')
            .doc(gameCode)
            .get();
    if (documentSnapshot.exists) {
      Map<String, dynamic> data =
          documentSnapshot.data() as Map<String, dynamic>;
      List<dynamic> players = data['players'] ?? [];
      List<String> playerNames =
          players.map((e) => e['name'].toString()).toList();
      if (!playerNames.contains(userName)) {
        return (playerNames.length, data['numPlayers'] as int);
      }
    }
    return (0, 0);
  }

  void joinGameLobby(BuildContext context, String value) async {
    if (value.isEmpty || !mounted) {
      return;
    }

    if (validateGameCode(value) && await checkGameCode(value)) {
      (int, int) players = await checkUserName(userName!, value);
      if (players.$1 < players.$2) {
        await _prefs!.setString('gameCode', value);
        // ignore: use_build_context_synchronously
        Navigator.pop(context);
        Navigator.pushReplacement(
          // ignore: use_build_context_synchronously
          context,
          CupertinoPageRoute(builder: (context) => GameLobby(prefs: _prefs!)),
        );
      } else {
        if (players == (0, 0)) {
          // ignore: use_build_context_synchronously
          showErrorDialog(context, 'Username is already taken');
        } else {
          showErrorDialog(
            // ignore: use_build_context_synchronously
            context,
            'Game is full. Ask the host to increase the number of players.',
          );
        }
      }
    } else {
      // ignore: use_build_context_synchronously
      showErrorDialog(context, 'Invalid game code');
    }
  }

  void joinGame(BuildContext context) {
    TextEditingController controller = TextEditingController();

    showCupertinoDialog(
      context: context,
      builder: (context) {
        return CupertinoAlertDialog(
          title: Padding(
            padding: const EdgeInsets.only(bottom: 15),
            child: const Text('Join Game'),
          ),
          content: CupertinoTextField(
            placeholder: 'Enter game code',
            textCapitalization: TextCapitalization.characters,
            controller: controller,
            onChanged: (value) => controller.text = value,
            onSubmitted: (value) => joinGameLobby(context, value),
          ),
          actions: <Widget>[
            CupertinoDialogAction(
              child: const Text('Cancel'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            CupertinoDialogAction(
              child: const Text('Join'),
              onPressed: () => joinGameLobby(context, controller.text),
            ),
          ],
        );
      },
    );
  }

  Future<BuildContext> _setUserName(context) async {
    final TextEditingController controller = TextEditingController(
      text: userName ?? '',
    );

    await showCupertinoDialog(
      context: context,
      builder: (context) {
        return CupertinoAlertDialog(
          title: Padding(
            padding: const EdgeInsets.only(bottom: 10.0),
            child: const Text('Set User Name'),
          ),
          content: CupertinoTextField(
            placeholder: 'Enter your name',
            controller: controller,
          ),
          actions: <Widget>[
            CupertinoDialogAction(
              child: const Text('OK'),
              onPressed: () async {
                if (controller.text.isEmpty) {
                  return;
                }

                setState(() {
                  userName = controller.text;
                });

                if (_prefs != null) {
                  _prefs!.setString('userName', userName!);
                }

                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );

    return context;
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoApp(
      title: 'SpyCast',
      theme: CupertinoThemeData(
        brightness: _brightness,
        primaryColor:
            isLight()
                ? CupertinoColors.black
                : CupertinoColors.lightBackgroundGray,
        textTheme: CupertinoTextThemeData(
          primaryColor:
              isLight() ? CupertinoColors.black : CupertinoColors.white,
        ),
      ),
      home: FutureBuilder(
        future: _prefsFuture,
        builder: (context2, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CupertinoActivityIndicator());
          }

          _prefs = snapshot.data;

          if (_prefs!.containsKey('userName')) {
            userName = _prefs!.getString('userName');
          } else if (!_hasPromptedForUserName) {
            _hasPromptedForUserName =
                true; // <-- Set flag so dialog only shows once
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _setUserName(context2);
            });
          }

          if (_prefs!.containsKey('gameCode')) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              Navigator.pushReplacement(
                context2,
                CupertinoPageRoute(
                  builder: (context) => GameLobby(prefs: _prefs!),
                ),
              );
            });
          }

          return CupertinoPageScaffold(
            navigationBar: CupertinoNavigationBar(
              middle: Text(widget.title),
              leading: CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: () => _setUserName(context2),
                child: Icon(
                  CupertinoIcons.person,
                  color:
                      isLight() ? CupertinoColors.black : CupertinoColors.white,
                ),
              ),
              trailing: CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: _toggleBrightness,
                child: Icon(
                  _brightness == Brightness.light
                      ? CupertinoIcons.moon
                      : CupertinoIcons.sun_max,
                  color:
                      isLight() ? CupertinoColors.black : CupertinoColors.white,
                ),
              ),
            ),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Image.asset(
                    'assets/logos/spy.png',
                    color:
                        isLight()
                            ? CupertinoColors.black
                            : CupertinoColors.white,
                  ),
                  CupertinoButton.filled(
                    child: Text(
                      'Join Game',
                      style: TextStyle(
                        color:
                            isLight()
                                ? CupertinoColors.white
                                : CupertinoColors.black,
                      ),
                    ),
                    onPressed: () => joinGame(context2),
                  ),
                  const SizedBox(height: 20),
                  CupertinoButton.filled(
                    child: Text(
                      'Create Game',
                      style: TextStyle(
                        color:
                            isLight()
                                ? CupertinoColors.white
                                : CupertinoColors.black,
                      ),
                    ),
                    onPressed: () {
                      Navigator.push(
                        context2,
                        CupertinoPageRoute(
                          builder:
                              (context) => CreateGame(
                                userName: userName!,
                                prefs: _prefs!,
                              ),
                        ),
                      );
                    },
                  ),
                  CupertinoButton(
                    child: Text('How to play?', style: TextStyle(fontSize: 14)),
                    onPressed:
                        () => Navigator.push(
                          context2,
                          CupertinoPageRoute(
                            builder: (context) => const Instructions(),
                            fullscreenDialog: true,
                          ),
                        ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class ThemeUtils {
  static bool isLightMode(BuildContext context) {
    final brightness = CupertinoTheme.of(context).brightness;
    return brightness == Brightness.light;
  }
}
