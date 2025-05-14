// ignore_for_file: use_build_context_synchronously

import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/cupertino.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:spycast/game_lobby.dart';
import 'package:spycast/main.dart';

class CreateGame extends StatefulWidget {
  final String userName;
  final SharedPreferences prefs;
  const CreateGame({super.key, required this.userName, required this.prefs});

  @override
  State<CreateGame> createState() => _CreateGameState();
}

class _CreateGameState extends State<CreateGame> {
  int numberOfPlayers = 3;
  int numberOfRounds = 3;
  int numberOfSpies = 1;
  List<String>? packs;
  int packIdx = 0;
  int timeLimit = 3;

  @override
  void initState() {
    super.initState();
    FirebaseFirestore.instance.collection('packs').get().then((
      QuerySnapshot querySnapshot,
    ) {
      if (querySnapshot.docs.isNotEmpty) {
        setState(() {
          packs =
              querySnapshot.docs.map((DocumentSnapshot doc) => doc.id).toList();
        });
      }
    });
    // print(packs);
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

  Future<String> createGame() async {
    String gameCode = getRandom(6);
    await FirebaseFirestore.instance
        .collection('games')
        .doc(gameCode)
        .set({
          'host': widget.userName,
          'pack': packs![packIdx],
          'numPlayers': numberOfPlayers,
          'numSpies': numberOfSpies,
          'numRounds': numberOfRounds,
          'timeLimit': timeLimit,
          'players': [
            {'name': widget.userName, 'isHost': true, 'isSpy': false},
          ],
          'wordState': 'INIT',
          'gameStarted': false,
          'lastActive': FieldValue.serverTimestamp(),
        })
        .catchError((error) {
          gameCode = 'ERROR';
        });

    return gameCode;
  }

  String getRandom(int length) {
    const ch = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
    Random r = Random();
    return String.fromCharCodes(
      Iterable.generate(length, (_) => ch.codeUnitAt(r.nextInt(ch.length))),
    );
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(middle: Text('Create Game')),

      // Form that can be used to create a game
      // choose number of players
      // choose number of spies
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: <Widget>[
            Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    GestureDetector(
                      onTap:
                          () => _showDialog(
                            CupertinoPicker(
                              magnification: 1.22,
                              squeeze: 1.2,
                              useMagnifier: true,
                              itemExtent: 32.0,
                              scrollController: FixedExtentScrollController(
                                initialItem: numberOfPlayers - 3,
                              ),
                              onSelectedItemChanged: (int selectedItem) {
                                setState(() {
                                  numberOfPlayers = selectedItem + 3;
                                  numberOfSpies = min(
                                    numberOfSpies,
                                    numberOfPlayers,
                                  );
                                });
                              },
                              children: List<Widget>.generate(18, (int index) {
                                index = index + 3;
                                return Center(child: Text('$index'));
                              }),
                            ),
                          ),
                      child: Column(
                        children: [
                          Icon(CupertinoIcons.person_3, size: 100),
                          Text('Players: $numberOfPlayers'),
                        ],
                      ),
                    ),
                    GestureDetector(
                      onTap:
                          () => _showDialog(
                            CupertinoPicker(
                              magnification: 1.22,
                              squeeze: 1.2,
                              useMagnifier: true,
                              itemExtent: 32.0,
                              scrollController: FixedExtentScrollController(
                                initialItem: numberOfSpies - 1,
                              ),
                              onSelectedItemChanged: (int selectedItem) {
                                setState(() {
                                  numberOfSpies = selectedItem + 1;
                                });
                              },
                              children: List<Widget>.generate(numberOfPlayers, (
                                int index,
                              ) {
                                index = index + 1;
                                return Center(child: Text('$index'));
                              }),
                            ),
                          ),
                      child: Column(
                        children: [
                          Icon(CupertinoIcons.eye_slash, size: 100),
                          Text('Spies: $numberOfSpies'),
                        ],
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 30),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    packs != null
                        ? GestureDetector(
                          onTap:
                              () => _showDialog(
                                CupertinoPicker(
                                  magnification: 1.22,
                                  squeeze: 1.2,
                                  useMagnifier: true,
                                  itemExtent: 32.0,
                                  scrollController: FixedExtentScrollController(
                                    initialItem: packIdx,
                                  ),
                                  onSelectedItemChanged: (int selectedItem) {
                                    setState(() {
                                      packIdx = selectedItem;
                                    });
                                  },
                                  children: [
                                    for (int i = 0; i < packs!.length; i++)
                                      Center(
                                        child: Text(capitalizeWords(packs![i])),
                                      ),
                                  ],
                                ),
                              ),
                          child: Column(
                            children: [
                              Icon(CupertinoIcons.square_list, size: 100),
                              Text('Pack: ${capitalizeWords(packs![packIdx])}'),
                            ],
                          ),
                        )
                        : CupertinoActivityIndicator(),
                    GestureDetector(
                      onTap:
                          () => _showDialog(
                            CupertinoPicker(
                              magnification: 1.22,
                              squeeze: 1.2,
                              useMagnifier: true,
                              itemExtent: 32.0,
                              scrollController: FixedExtentScrollController(
                                initialItem: 0,
                              ),
                              onSelectedItemChanged: (int selectedItem) {
                                setState(() {
                                  numberOfRounds = [3, 5, 10][selectedItem];
                                });
                              },
                              children:
                                  [3, 5, 10]
                                      .map(
                                        (rounds) =>
                                            Center(child: Text('$rounds')),
                                      )
                                      .toList(),
                            ),
                          ),
                      child: Column(
                        children: [
                          Icon(CupertinoIcons.repeat, size: 100),
                          Text('Rounds: $numberOfRounds'),
                        ],
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 50),
                GestureDetector(
                  onTap:
                      () => _showDialog(
                        CupertinoPicker(
                          magnification: 1.22,
                          squeeze: 1.2,
                          useMagnifier: true,
                          itemExtent: 32.0,
                          scrollController: FixedExtentScrollController(
                            initialItem: 0,
                          ),
                          onSelectedItemChanged: (int selectedItem) {
                            setState(() {
                              timeLimit = [3, 5, 7, 10][selectedItem];
                            });
                          },
                          children:
                              [3, 5, 7, 10]
                                  .map(
                                    (time) => Center(child: Text('$time min')),
                                  )
                                  .toList(),
                        ),
                      ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(CupertinoIcons.timer, size: 30),
                      SizedBox(width: 10),
                      Text('Discussion Time Limit: $timeLimit min'),
                    ],
                  ),
                ),
              ],
            ),
            CupertinoButton.filled(
              child: Text(
                'Create Game',
                style: TextStyle(
                  color:
                      ThemeUtils.isLightMode(context)
                          ? CupertinoColors.white
                          : CupertinoColors.black,
                ),
              ),
              onPressed: () async {
                if (!mounted) return;
                String gameCode = await createGame();
                await widget.prefs.setString('gameCode', gameCode);

                if (gameCode != 'ERROR') {
                  Navigator.pop(context);
                  Navigator.pushReplacement(
                    context,
                    CupertinoPageRoute(
                      builder:
                          (context) =>
                              GameLobby(prefs: widget.prefs, createdGame: true),
                    ),
                  );
                } else {
                  // Handle error
                  showCupertinoDialog(
                    context: context,
                    builder:
                        (context) => CupertinoAlertDialog(
                          title: const Text('Error'),
                          content: const Text('Failed to create game.'),
                          actions: <Widget>[
                            CupertinoDialogAction(
                              child: const Text('OK'),
                              onPressed: () {
                                Navigator.of(context).pop();
                              },
                            ),
                          ],
                        ),
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}
