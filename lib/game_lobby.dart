import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:spycast/game_view.dart';
import 'package:spycast/main.dart';

class GameLobby extends StatefulWidget {
  const GameLobby({super.key, required this.prefs, this.createdGame = false});
  final SharedPreferences prefs;
  final bool createdGame;

  @override
  State<GameLobby> createState() => _GameLobbyState();

  static void exitGame(
    BuildContext context,
    String gameCode,
    SharedPreferences prefs,
  ) {
    FirebaseFirestore.instance.collection('games').doc(gameCode).delete();
  }

  static void leaveGame(
    BuildContext context,
    String gameCode,
    String userName,
    SharedPreferences prefs,
  ) {
    FirebaseFirestore.instance.collection('games').doc(gameCode).get().then((
      doc,
    ) {
      if (doc.exists) {
        final players =
            (doc.data()?['players'] as List<dynamic>? ?? [])
                .where((player) => player['name'] != userName)
                .toList();
        FirebaseFirestore.instance.collection('games').doc(gameCode).update({
          'players': players,
        });
      }
    });

    prefs.remove('gameCode');

    Navigator.pushReplacement(
      context,
      CupertinoPageRoute(builder: (context) => const MyApp()),
    );
  }
}

class _GameLobbyState extends State<GameLobby> with WidgetsBindingObserver {
  String gameCode = '';
  String userName = '';

  List<String>? packs;
  bool packsLoaded = false;

  bool isHost = false;

  Future<bool> userExists(String gameCode, String userName) async {
    final doc =
        await FirebaseFirestore.instance
            .collection('games')
            .doc(gameCode)
            .get();

    if (doc.exists) {
      final players = doc.data()?['players'] as List<dynamic>;
      return players.any((player) => player['name'] == userName);
    }
    return false;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    gameCode = widget.prefs.getString('gameCode') ?? '';
    userName = widget.prefs.getString('userName') ?? '';

    if (gameCode.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.pushReplacement(
          context,
          CupertinoPageRoute(builder: (context) => const MyApp()),
        );
      });
    } else {
      userExists(gameCode, userName).then((exists) {
        if (!exists) {
          FirebaseFirestore.instance.collection('games').doc(gameCode).update({
            'players': FieldValue.arrayUnion([
              {'name': userName, 'isHost': false, 'isSpy': false, 'points': 0},
            ]),
          });
        }
      });

      // Only fetch packs if not already loaded
      if (!packsLoaded) {
        FirebaseFirestore.instance.collection('packs').get().then((
          querySnapshot,
        ) {
          if (querySnapshot.docs.isNotEmpty) {
            setState(() {
              packs = querySnapshot.docs.map((doc) => doc.id).toList();
              packsLoaded = true;
            });
          }
        });
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) async {
    super.didChangeAppLifecycleState(state);
    // Only update if this user is the host
    if (isHost) {
      // Get gameCode from SharedPreferences
      final prefs = widget.prefs;
      final gameCode = prefs.getString('gameCode');
      if (gameCode != null && gameCode.isNotEmpty) {
        if (state == AppLifecycleState.paused ||
            state == AppLifecycleState.inactive ||
            state == AppLifecycleState.resumed) {
          await FirebaseFirestore.instance
              .collection('games')
              .doc(gameCode)
              .update({'lastActive': FieldValue.serverTimestamp()});
        }
      }
    }
  }

  void _showDialog(Widget child) {
    showCupertinoModalPopup<void>(
      context: context,
      builder:
          (BuildContext context) => Container(
            height: 216,
            padding: const EdgeInsets.only(top: 6.0),
            // The Bottom margin is provided to align the popup above the system navigation bar.
            margin: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
            ),
            // Provide a background color for the popup.
            color: CupertinoColors.systemBackground.resolveFrom(context),
            // Use a SafeArea widget to avoid system overlaps.
            child: SafeArea(top: false, child: child),
          ),
    );
  }

  Widget profileCard(String playerName, bool isHost, bool isPlayerHost) {
    return CupertinoButton(
      onPressed: () {
        if (isPlayerHost && !isHost) {
          _showDialog(
            SizedBox(
              width: double.infinity,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Text(
                    'Transfer host to $playerName?',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w500),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CupertinoButton(
                        child: const Text('Cancel'),
                        onPressed: () {
                          Navigator.of(context, rootNavigator: true).pop();
                        },
                      ),
                      SizedBox(width: 10),
                      CupertinoButton.filled(
                        child: Text(
                          'Transfer',
                          style: TextStyle(
                            color:
                                ThemeUtils.isLightMode(context)
                                    ? CupertinoColors.white
                                    : CupertinoColors.black,
                          ),
                        ),
                        onPressed: () async {
                          // Get current players list
                          final doc =
                              await FirebaseFirestore.instance
                                  .collection('games')
                                  .doc(gameCode)
                                  .get();
                          final players =
                              (doc.data()?['players'] as List<dynamic>?)
                                  ?.map((e) => Map<String, dynamic>.from(e))
                                  .toList() ??
                              [];

                          // Update isHost for target and current user
                          final updatedPlayers =
                              players.map((player) {
                                if (player['name'] == playerName) {
                                  return {...player, 'isHost': true};
                                } else if (player['name'] == userName) {
                                  return {...player, 'isHost': false};
                                }
                                return player;
                              }).toList();

                          await FirebaseFirestore.instance
                              .collection('games')
                              .doc(gameCode)
                              .update({
                                'host': playerName,
                                'players': updatedPlayers,
                              });

                          if (mounted) {
                            Navigator.of(context, rootNavigator: true).pop();
                          }
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        }
      },
      child: Column(
        children: [
          Icon(CupertinoIcons.person, size: 40),
          Text(playerName),
          if (isHost)
            Text(
              '(host)',
              style: TextStyle(fontSize: 12, color: CupertinoColors.systemGrey),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream:
          FirebaseFirestore.instance
              .collection('games')
              .doc(gameCode)
              .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const CupertinoActivityIndicator();
        }
        final docSnapshot = snapshot.data!;
        final gameData = docSnapshot.data() as Map<String, dynamic>? ?? {};

        // If the game has started, show GameView with the latest gameData
        if (gameData['gameStarted'] == true) {
          return GameView(prefs: widget.prefs, gameData: gameData);
        }

        return CupertinoPageScaffold(
          navigationBar: CupertinoNavigationBar(
            middle: const Text('Game Lobby'),
          ),
          child: StreamBuilder<Object>(
            stream:
                FirebaseFirestore.instance
                    .collection('games')
                    .doc(gameCode)
                    .snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return Center(child: CupertinoActivityIndicator());
              }
              final docSnapshot = snapshot.data as DocumentSnapshot;
              final docExists =
                  docSnapshot.exists && docSnapshot.data() != null;
              final Map<String, dynamic> gameData =
                  docExists ? docSnapshot.data() as Map<String, dynamic> : {};

              if (!docExists || gameData.isEmpty) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  widget.prefs.remove('gameCode');
                  Navigator.pushReplacement(
                    context,
                    CupertinoPageRoute(builder: (context) => const MyApp()),
                  );
                });
                return const SizedBox.shrink();
              }

              // Check if the user is the host
              isHost = gameData['host'] == userName;

              List<Map<String, dynamic>> allPlayers =
                  (gameData['players'] as List<dynamic>? ?? [])
                      .map((e) => e as Map<String, dynamic>)
                      .toList();

              // Aggregate the players into rows of 3
              List<List<Map<String, dynamic>>> rows = [];
              for (int i = 0; i < allPlayers.length; i += 3) {
                rows.add(
                  allPlayers.sublist(
                    i,
                    i + 3 > allPlayers.length ? allPlayers.length : i + 3,
                  ),
                );
              }

              return SafeArea(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      Column(
                        children: [
                          CupertinoButton.tinted(
                            child: Text(
                              'Game Code: $gameCode',
                              style: const TextStyle(fontSize: 24),
                            ),
                            onPressed: () {
                              // Copy game code to clipboard
                              Clipboard.setData(ClipboardData(text: gameCode));
                              // Show a snackbar or toast to indicate success
                              showCupertinoDialog(
                                context: context,
                                builder:
                                    (context) => CupertinoAlertDialog(
                                      title: const Text('Copied!'),
                                      content: const Text(
                                        'Game code copied to clipboard',
                                      ),
                                      actions: [
                                        CupertinoDialogAction(
                                          child: const Text('OK'),
                                          onPressed:
                                              () =>
                                                  Navigator.of(
                                                    context,
                                                    rootNavigator: true,
                                                  ).pop(),
                                        ),
                                      ],
                                    ),
                              );
                            },
                          ),
                          SizedBox(height: 20),

                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              CupertinoButton.tinted(
                                onPressed:
                                    (!isHost)
                                        ? null
                                        : () {
                                          _showDialog(
                                            CupertinoPicker(
                                              magnification: 1.22,
                                              squeeze: 1.2,
                                              useMagnifier: true,
                                              itemExtent: 32.0,
                                              onSelectedItemChanged: (
                                                int selectedItem,
                                              ) {
                                                int newNumPlayers =
                                                    selectedItem + 3;
                                                if (gameData['numPlayers'] !=
                                                    newNumPlayers) {
                                                  FirebaseFirestore.instance
                                                      .collection('games')
                                                      .doc(gameCode)
                                                      .update({
                                                        'numPlayers':
                                                            newNumPlayers,
                                                      });
                                                }
                                              },
                                              scrollController:
                                                  FixedExtentScrollController(
                                                    initialItem:
                                                        gameData['numPlayers'] -
                                                        3,
                                                  ),
                                              children: List<Widget>.generate(
                                                18,
                                                (int index) {
                                                  index = index + 3;
                                                  return Center(
                                                    child: Text('$index'),
                                                  );
                                                },
                                              ),
                                            ),
                                          );
                                        },
                                child: Row(
                                  children: [
                                    Icon(CupertinoIcons.person_fill, size: 30),
                                    SizedBox(width: 10),
                                    Text('${gameData['numPlayers']}'),
                                  ],
                                ),
                              ),
                              SizedBox(width: 10),
                              (!isHost)
                                  ? SizedBox()
                                  : packs == null
                                  ? CupertinoActivityIndicator()
                                  : CupertinoButton.tinted(
                                    child: Icon(
                                      CupertinoIcons.square_list,
                                      size: 30,
                                    ),
                                    onPressed: () {
                                      _showDialog(
                                        CupertinoPicker(
                                          magnification: 1.22,
                                          squeeze: 1.2,
                                          useMagnifier: true,
                                          itemExtent: 32.0,
                                          onSelectedItemChanged: (
                                            int selectedItem,
                                          ) {
                                            FirebaseFirestore.instance
                                                .collection('games')
                                                .doc(gameCode)
                                                .update({
                                                  'pack': packs![selectedItem],
                                                });
                                          },
                                          scrollController:
                                              rows
                                                  .map(
                                                    (row) =>
                                                        FixedExtentScrollController(
                                                          initialItem: packs!
                                                              .indexOf(
                                                                gameData['pack'],
                                                              ),
                                                        ),
                                                  )
                                                  .toList()[0],
                                          children: [
                                            for (
                                              int i = 0;
                                              i < packs!.length;
                                              i++
                                            )
                                              Center(
                                                child: Text(
                                                  capitalizeWords(packs![i]),
                                                ),
                                              ),
                                          ],
                                        ),
                                      );
                                    },
                                  ),
                              SizedBox(width: 10),
                              CupertinoButton.tinted(
                                onPressed:
                                    (!isHost)
                                        ? null
                                        : () {
                                          _showDialog(
                                            CupertinoPicker(
                                              magnification: 1.22,
                                              squeeze: 1.2,
                                              useMagnifier: true,
                                              itemExtent: 32.0,
                                              scrollController:
                                                  FixedExtentScrollController(
                                                    initialItem:
                                                        gameData['numSpies'] -
                                                        1,
                                                  ),
                                              onSelectedItemChanged: (
                                                int selectedItem,
                                              ) {
                                                FirebaseFirestore.instance
                                                    .collection('games')
                                                    .doc(gameCode)
                                                    .update({
                                                      'numSpies':
                                                          selectedItem + 1,
                                                    });
                                              },
                                              children: List<Widget>.generate(
                                                gameData['numPlayers'] - 1,
                                                (int index) {
                                                  index = index + 1;
                                                  return Center(
                                                    child: Text('$index'),
                                                  );
                                                },
                                              ),
                                            ),
                                          );
                                        },
                                child: Row(
                                  children: [
                                    Text('${gameData['numSpies']}'),
                                    SizedBox(width: 10),
                                    Icon(CupertinoIcons.eye_slash, size: 30),
                                  ],
                                ),
                              ),
                            ],
                          ),

                          SizedBox(height: 20),

                          Column(
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    '${gameData['numRounds']} Rounds: ',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  Text(
                                    '${gameData['timeLimit']} mins',
                                    style: const TextStyle(fontSize: 15),
                                  ),
                                ],
                              ),
                              SizedBox(height: 3),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    'Pack: ',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  Text(
                                    capitalizeWords(
                                      (gameData['pack'] ?? '') as String,
                                    ),
                                    style: const TextStyle(fontSize: 16),
                                  ),
                                ],
                              ),
                            ],
                          ),

                          SizedBox(height: 30),

                          SizedBox(
                            height: 300,
                            child: ListView.builder(
                              padding: EdgeInsets.zero,
                              physics: const BouncingScrollPhysics(),
                              itemCount: rows.length,
                              itemBuilder: (context, index) {
                                return Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children:
                                      rows[index]
                                          .map(
                                            (player) => profileCard(
                                              player['name'],
                                              player['isHost'],
                                              isHost,
                                            ),
                                          )
                                          .toList(),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                      isHost
                          ? Column(
                            children: [
                              CupertinoButton.tinted(
                                color: CupertinoColors.systemFill,
                                child: Text(
                                  'Start Game',
                                  style: TextStyle(
                                    color:
                                        ThemeUtils.isLightMode(context)
                                            ? (allPlayers.length <
                                                    gameData['numPlayers'])
                                                ? CupertinoColors.inactiveGray
                                                : CupertinoColors.label
                                            : (allPlayers.length <
                                                gameData['numPlayers'])
                                            ? CupertinoColors.inactiveGray
                                            : CupertinoColors.white,
                                  ),
                                ),
                                onPressed: () {
                                  if (allPlayers.length <
                                      gameData['numPlayers']) {
                                    showCupertinoDialog(
                                      context: context,
                                      builder:
                                          (context) => CupertinoAlertDialog(
                                            title: const Text(
                                              'Not enough players',
                                            ),
                                            content: const Text(
                                              'Please wait for more players to join.',
                                            ),
                                            actions: [
                                              CupertinoDialogAction(
                                                child: const Text('OK'),
                                                onPressed: () {
                                                  Navigator.of(
                                                    context,
                                                    rootNavigator: true,
                                                  ).pop();
                                                },
                                              ),
                                            ],
                                          ),
                                    );
                                  } else {
                                    FirebaseFirestore.instance
                                        .collection('games')
                                        .doc(gameCode)
                                        .update({
                                          'gameStarted': true,
                                          'currentRound': 1,
                                        });
                                  }
                                },
                              ),
                              SizedBox(height: 15),
                              CupertinoButton.filled(
                                child: Text(
                                  'Exit Game',
                                  style: TextStyle(
                                    color:
                                        ThemeUtils.isLightMode(context)
                                            ? CupertinoColors.white
                                            : CupertinoColors.black,
                                  ),
                                ),
                                onPressed: () {
                                  if (!mounted) {
                                    return;
                                  }

                                  GameLobby.exitGame(
                                    context,
                                    gameCode,
                                    widget.prefs,
                                  );
                                },
                              ),
                            ],
                          )
                          : Column(
                            children: [
                              WaitingDots(
                                waitingText:
                                    'waiting for host to start the game',
                              ),
                              SizedBox(height: 15),
                              CupertinoButton.filled(
                                child: Text(
                                  'Leave Game',
                                  style: TextStyle(
                                    color:
                                        ThemeUtils.isLightMode(context)
                                            ? CupertinoColors.white
                                            : CupertinoColors.black,
                                  ),
                                ),
                                onPressed: () {
                                  if (!mounted) {
                                    return;
                                  }

                                  GameLobby.leaveGame(
                                    context,
                                    gameCode,
                                    userName,
                                    widget.prefs,
                                  );
                                },
                              ),
                            ],
                          ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}

String capitalizeWords(String input) {
  return input
      .split(' ')
      .map(
        (word) =>
            word.isNotEmpty
                ? word[0].toUpperCase() + word.substring(1).toLowerCase()
                : '',
      )
      .join(' ');
}

class WaitingDots extends StatefulWidget {
  const WaitingDots({super.key, required this.waitingText, this.style});
  final String waitingText;
  final TextStyle? style;

  @override
  State<WaitingDots> createState() => _WaitingDotsState();
}

class _WaitingDotsState extends State<WaitingDots> {
  int dotCount = 0;
  bool _disposed = false; // Add this flag

  @override
  void initState() {
    super.initState();
    _loopDots();
  }

  @override
  void dispose() {
    _disposed = true; // Set flag to true
    super.dispose();
  }

  void _loopDots() async {
    while (mounted && !_disposed) {
      await Future.delayed(const Duration(milliseconds: 500));
      if (mounted && !_disposed) {
        setState(() => dotCount = (dotCount + 1) % 4);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Text(
      '${widget.waitingText}${'.' * dotCount}',
      style: widget.style ?? const TextStyle(fontSize: 16),
    );
  }
}
