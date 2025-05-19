import 'dart:async';
import 'dart:math';

import 'package:auto_size_text/auto_size_text.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:spycast/game_lobby.dart';
import 'package:spycast/instructions.dart';
import 'package:spycast/main.dart';
import 'package:spycast/results_page.dart';
import 'package:spycast/show_winner.dart';
import 'package:spycast/voting_content.dart';

class GameView extends StatefulWidget {
  const GameView({
    super.key,
    required this.prefs,
    required this.gameData, // Now expects gameData as a parameter
  });
  final Map<String, dynamic> gameData; // Change type to Map
  final SharedPreferences prefs;

  @override
  State<GameView> createState() => _GameViewState();
}

class _GameViewState extends State<GameView> {
  String gameCode = '';
  String userName = '';

  bool isHost = false;

  int countdown = 5;
  Timer? countdownTimer;

  int wordTimerCountdown = 1;
  Timer? wordTimer;

  int votingTimerCountdown = 0;
  Timer? votingTimer;

  bool revealWord = false;

  String lastWordState = '';

  void initializeGame([bool incrementRound = false]) {
    // assign numbers of spies randomly from the list of players
    FirebaseFirestore.instance.collection('games').doc(gameCode).get().then((
      doc,
    ) {
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        final players = data['players'] as List<dynamic>;
        final numSpies = data['numSpies'] as int;

        if (data['gameStarted'] == false) {
          Navigator.pushReplacement(
            // ignore: use_build_context_synchronously
            context,
            CupertinoPageRoute(
              builder: (context) => GameLobby(prefs: widget.prefs),
            ),
          );
        }

        // Randomly assign spies
        List<int> spyIndices = [];
        final numPlayers = players.length;
        final random = Random();
        while (spyIndices.length < numSpies) {
          int randomIndex = random.nextInt(numPlayers);
          if (!spyIndices.contains(randomIndex)) {
            spyIndices.add(randomIndex);
          }
        }

        List<Map<String, dynamic>> updatedPlayers = [];
        for (int i = 0; i < players.length; i++) {
          final player = Map<String, dynamic>.from(players[i]);
          player['isSpy'] = spyIndices.contains(i);
          updatedPlayers.add(player);
        }
        FirebaseFirestore.instance.collection('games').doc(gameCode).update({
          'players': updatedPlayers,
          'wordState': 'COUNTER',
          'currentRound':
              incrementRound
                  ? (data['currentRound'] as int) + 1
                  : data['currentRound'],
        });
      }
    });
  }

  Future<void> appendUsedWord(String word) async {
    // Append the used word to the list of used words
    await FirebaseFirestore.instance.collection('games').doc(gameCode).update({
      'usedWords': FieldValue.arrayUnion([word]),
    });
  }

  Future<String> getRandomWord(String pack, List<String> usedWords) async {
    // Fetch a random word from the specified pack
    List<String> words = await FirebaseFirestore.instance
        .collection('packs')
        .doc(pack)
        .get()
        .then((doc) {
          if (doc.exists) {
            final data = doc.data() as Map<String, dynamic>;
            return List<String>.from(data['words']);
          } else {
            return [];
          }
        });

    // Filter out used words
    words.removeWhere((word) => usedWords.contains(word));
    if (words.isEmpty) {
      // If no words are available, return a default word or handle the case
      return 'No words available';
    }

    return words[Random().nextInt(words.length)];
  }

  void startCountdown(
    bool isHost,
    String pack,
    List<String> usedWords,
    int timeLimit,
    Duration? votingExpiration,
  ) {
    countdownTimer?.cancel();
    setState(() {
      countdown = 5;
    });
    countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (countdown > 1) {
        setState(() {
          countdown--;
        });
      } else {
        timer.cancel();
        if (isHost) {
          getRandomWord(pack, usedWords).then((word) {
            FirebaseFirestore.instance.collection('games').doc(gameCode).update(
              {
                'wordState': word,
                'usedWords': FieldValue.arrayUnion([word]),
              },
            );
          });
        }
        startWordTimerCountdown();
        if (isHost && votingExpiration == null) {
          updateFSVotingExpiration(timeLimit);
        }
      }
    });
  }

  void startWordTimerCountdown() {
    wordTimer?.cancel();
    setState(() {
      wordTimerCountdown = 5;
    });
    wordTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (wordTimerCountdown > 1) {
        setState(() {
          wordTimerCountdown--;
        });
      } else {
        timer.cancel();
      }
    });
  }

  void updateFSVotingExpiration(int timeLimit) {
    FirebaseFirestore.instance.collection('games').doc(gameCode).update({
      'votingExpiration': DateTime.now().add(Duration(minutes: timeLimit)),
    });
  }

  void startVotingCountdown(bool isHost, int timeLimit) {
    votingTimer?.cancel();
    setState(() {
      votingTimerCountdown = timeLimit; // store as seconds
    });
    votingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (votingTimerCountdown > 0) {
        setState(() {
          votingTimerCountdown--;
        });
      } else {
        timer.cancel();
        if (isHost) {
          startVoting();
        }
      }
    });
  }

  void resetVotingTimer() {
    votingTimer?.cancel();
    setState(() {
      votingTimerCountdown = 0;
    });
  }

  String get votingTimerDisplay {
    final minutes = votingTimerCountdown ~/ 60;
    final seconds = votingTimerCountdown % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  void startVoting() {
    FirebaseFirestore.instance.collection('games').doc(gameCode).update({
      'votes': [],
      'wordState': 'VOTING',
      'votingExpiration': FieldValue.delete(),
    });
  }

  bool didSpyWin(List<dynamic> players, List<dynamic> votes) {
    // Find the index of the spy
    int spyIndex = players.indexWhere((p) => p['isSpy'] == true);
    if (spyIndex == -1) return false; // No spy found, default to players win

    // Count votes for the spy
    int votesForSpy = 0;
    for (var vote in votes) {
      if (vote['votedFor'] is List) {
        votesForSpy +=
            (vote['votedFor'] as List).where((i) => i == spyIndex).length;
      }
    }

    int numPlayers = players.length;
    // Majority: more than half
    return votesForSpy <= numPlayers ~/ 2;
  }

  void calculateResult(
    List<dynamic> players,
    List<dynamic> votes,
    bool spyWin,
  ) {
    // Find spy indices
    List<int> spyIndices = [];
    for (int i = 0; i < players.length; i++) {
      if (players[i]['isSpy'] == true) spyIndices.add(i);
    }

    // Map: player index -> who they voted for
    Map<int, List<int>> playerVotes = {};
    for (var vote in votes) {
      playerVotes[vote['votedBy']] = List<int>.from(vote['votedFor']);
    }

    // Assign points
    for (int i = 0; i < players.length; i++) {
      int points = 0;
      bool isSpy = players[i]['isSpy'] == true;
      List<int> votedFor = playerVotes[i] ?? [];

      if (spyWin) {
        if (isSpy) {
          points = 3;
        } else {
          // Non-spy gets 1 point if they did NOT vote for any spy
          bool votedForSpy = votedFor.any((idx) => spyIndices.contains(idx));
          points = votedForSpy ? 1 : 0;
        }
      } else {
        if (isSpy) {
          points = 0;
        } else {
          // Non-spy gets 2 points if they voted for any spy, else 1
          bool votedForSpy = votedFor.any((idx) => spyIndices.contains(idx));
          points = votedForSpy ? 2 : 1;
        }
      }
      players[i]['points'] = (players[i]['points'] ?? 0) + points;
    }
    // Update Firestore
    FirebaseFirestore.instance.collection('games').doc(gameCode).update({
      'wordState': 'RESULTS',
      'players': players,
      'spyWin': spyWin,
    });
  }

  void showResults() {
    FirebaseFirestore.instance.collection('games').doc(gameCode).update({
      'wordState': 'FINAL_RESULTS',
    });
  }

  @override
  void initState() {
    super.initState();
    // Initialize any necessary data or state here

    gameCode = widget.prefs.getString('gameCode') ?? '';
    userName = widget.prefs.getString('userName') ?? '';

    if (gameCode.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.pushReplacement(
          context,
          CupertinoPageRoute(builder: (context) => const MyApp()),
        );
      });
    }
  }

  @override
  void dispose() {
    countdownTimer?.cancel();
    wordTimer?.cancel();
    votingTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final gameData = widget.gameData;

    if (gameData.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        widget.prefs.remove('gameCode');
        Navigator.pushReplacement(
          context,
          CupertinoPageRoute(builder: (context) => const MyApp()),
        );
      });
      return const SizedBox.shrink();
    }

    String wordState = gameData['wordState']?.toString() ?? '';
    isHost = (gameData['host']?.toString() ?? '') == userName;
    String pack = gameData['pack']?.toString() ?? '';
    List<String> usedWords = List<String>.from(gameData['usedWords'] ?? []);
    Duration? votingExpiration =
        gameData['votingExpiration'] != null
            ? (gameData['votingExpiration'] as Timestamp).toDate().difference(
              DateTime.now(),
            )
            : null;

    if (votingExpiration?.isNegative == true) {
      votingExpiration = null; // If the expiration is in the past, set to null
      if (isHost) {
        startVoting();
      }
    }

    int votingPlayersLeft =
        gameData['players'].length - (gameData['votes']?.length ?? 0);

    if (wordState == 'COUNTER' && lastWordState != 'COUNTER') {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        startCountdown(
          isHost,
          pack,
          usedWords,
          gameData['timeLimit'],
          votingExpiration,
        );
      });
    }
    lastWordState = wordState;

    if (votingExpiration != null) {
      startVotingCountdown(isHost, votingExpiration.inSeconds);
    }

    if (wordState == 'INIT') {
      initializeGame();
    } else if (wordState == 'COUNTER') {
      return Center(
        child: Text(
          countdown.toString(),
          style: const TextStyle(fontSize: 100, color: CupertinoColors.white),
        ),
      );
    } else if (wordState == 'VOTING') {
      if (votingTimer?.isActive == true) {
        resetVotingTimer();
      }

      if (votingPlayersLeft == 0 && isHost) {
        bool spyWin = didSpyWin(gameData['players'], gameData['votes']);
        calculateResult(gameData['players'], gameData['votes'], spyWin);
      }
    }

    bool isSpy = gameData['players'].any(
      (player) => player['name'] == userName && player['isSpy'],
    );

    Widget getContent() {
      return (wordTimerCountdown > 1 || revealWord == true)
          ? isSpy
              ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Image.asset(
                      'assets/logos/spy.png',
                      color: CupertinoColors.white,
                      width: 200,
                    ),
                    Text(
                      'Shh... You are a spy!\n\nTry to guess the word\nand blend in...${(wordTimerCountdown > 1) ? '\n\nHiding in $wordTimerCountdown seconds' : ''}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 24,
                        color: CupertinoColors.white,
                      ),
                    ),
                  ],
                ),
              )
              : Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 25),
                      child: AutoSizeText(
                        wordState.toUpperCase().split(' ').join('\n'),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 75,
                          color: CupertinoColors.white,
                        ),
                        maxLines: wordState.trim().split(' ').length,
                        minFontSize: 24,
                      ),
                    ),
                    SizedBox(height: 20),
                    Text(
                      'Keep this word a secret!${(wordTimerCountdown > 1) ? ' Hiding in $wordTimerCountdown seconds' : ''}',
                      style: const TextStyle(
                        fontSize: 15,
                        color: CupertinoColors.systemGrey,
                      ),
                    ),
                  ],
                ),
              )
          : Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  CupertinoIcons.eye_slash,
                  color: CupertinoColors.systemGrey,
                  size: 80,
                ),
                SizedBox(height: 20),
                Text(
                  'Tap and hold anywhere to reveal the word',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 15,
                    color: CupertinoColors.systemGrey,
                  ),
                ),
              ],
            ),
          );
    }

    Widget getContentByWordState() {
      return Expanded(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 500),
          transitionBuilder: (child, animation) {
            final offsetAnimation = Tween<Offset>(
              begin: const Offset(0, 1), // Start from below the screen
              end: Offset.zero, // End at the original position
            ).animate(animation);

            return SlideTransition(position: offsetAnimation, child: child);
          },
          child: Builder(
            key: ValueKey<String>(wordState),
            builder: (context) {
              switch (wordState) {
                case 'VOTING':
                  return VotingContent(
                    players: gameData['players'],
                    waitingOnNumPlayers: votingPlayersLeft,
                    userName: userName,
                    numSpies: gameData['numSpies'],
                    votedFor:
                        gameData['votes']?.firstWhere(
                          (vote) =>
                              gameData['players'][vote['votedBy']]['name'] ==
                              userName,
                          orElse: () => null,
                        )?['votedFor'],
                    onVote: (votedForList) {
                      if (!mounted) {
                        return;
                      }

                      List<dynamic> players =
                          gameData['players'] as List<dynamic>;

                      // Map the votedForList (names) to their indices
                      List<int> votedForIndices =
                          votedForList
                              .map<int>(
                                (name) => players.indexWhere(
                                  (player) => player['name'] == name,
                                ),
                              )
                              .where((index) => index != -1)
                              .toList();

                      int votedByIndex = players.indexWhere(
                        (player) => player['name'] == userName,
                      );

                      var addItem = {
                        'votedBy': votedByIndex,
                        'votedFor': votedForIndices,
                      };

                      FirebaseFirestore.instance
                          .collection('games')
                          .doc(gameCode)
                          .update({
                            'votes': FieldValue.arrayUnion([addItem]),
                          });
                    },
                  );
                case 'RESULTS':
                  return ResultsPage(
                    spyWin: gameData['spyWin'] == true,
                    players: gameData['players'],
                    numSpies: gameData['numSpies'] as int,
                    currentRound: gameData['currentRound'] as int,
                    currWord: gameData['usedWords'].last as String,
                  );

                case 'FINAL_RESULTS':
                  return ShowWinner(players: gameData['players']);

                default:
                  return (wordTimerCountdown == 1)
                      ? SizedBox(
                        width: double.infinity,
                        height: double.infinity,
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTapDown: (_) {
                            setState(() {
                              revealWord = true;
                            });
                          },
                          onTapUp: (_) {
                            setState(() {
                              revealWord = false;
                            });
                          },
                          onTapCancel: () {
                            setState(() {
                              revealWord = false;
                            });
                          },
                          child: getContent(),
                        ),
                      )
                      : getContent();
              }
            },
          ),
        ),
      );
    }

    Widget getNextButtonByWordState() {
      Widget buildButton(String text, VoidCallback onPressed) {
        return CupertinoButton.tinted(
          color: CupertinoColors.white,
          onPressed: onPressed,
          child: Text(
            text,
            style: const TextStyle(color: CupertinoColors.white),
          ),
        );
      }

      switch (wordState) {
        case 'VOTING':
          return buildButton('Skip Voting', () {
            if (!mounted) return;
            initializeGame();
          });
        case 'RESULTS':
          if (gameData['currentRound'] < gameData['numRounds']) {
            return buildButton('Next Round', () {
              if (!mounted) return;
              initializeGame(true);
            });
          } else {
            return buildButton('Show Results', () {
              if (!mounted) return;
              showResults();
            });
          }
        case 'FINAL_RESULTS':
          return SizedBox.shrink();

        default:
          return buildButton('Start Voting', () {
            if (!mounted) return;
            startVoting();
          });
      }
    }

    return CupertinoPageScaffold(
      backgroundColor: CupertinoColors.black,
      child: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      children: [
                        Row(
                          children: [
                            Icon(
                              CupertinoIcons.repeat,
                              color: CupertinoColors.white,
                            ),
                            SizedBox(width: 5),
                            Text(
                              '${gameData['currentRound']}/${gameData['numRounds']}',
                              style: const TextStyle(
                                fontSize: 18,
                                color: CupertinoColors.white,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    Column(
                      children: [
                        Text(
                          gameCode,
                          style: const TextStyle(
                            fontSize: 16,
                            color: CupertinoColors.white,
                          ),
                        ),
                        SizedBox(height: 3),
                        Text(
                          'Pack: ${capitalizeWords(pack)}',
                          style: const TextStyle(
                            fontSize: 18,
                            color: CupertinoColors.white,
                          ),
                        ),
                      ],
                    ),
                    (votingTimerDisplay != '0:00')
                        ? Text(
                          votingTimerDisplay,
                          style: const TextStyle(
                            fontSize: 18,
                            color: CupertinoColors.white,
                          ),
                        )
                        : IconButton(
                          icon: Icon(CupertinoIcons.info),
                          color: CupertinoColors.white,
                          onPressed: () {
                            if (!mounted) return;
                            Navigator.push(
                              context,
                              CupertinoPageRoute(
                                builder: (context) {
                                  return Instructions(isDark: true);
                                },
                                fullscreenDialog: true,
                              ),
                            );
                          },
                        ),
                  ],
                ),
              ),

              getContentByWordState(),

              isHost
                  ? Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CupertinoButton.tinted(
                        color: CupertinoColors.white,
                        child: Text(
                          'Back to Lobby',
                          style: TextStyle(color: CupertinoColors.white),
                        ),
                        onPressed: () {
                          if (!mounted) {
                            return;
                          }

                          // Reset points for all players to 0
                          List<dynamic> players = List<dynamic>.from(
                            gameData['players'],
                          );
                          for (var player in players) {
                            player['points'] = 0;
                          }
                          FirebaseFirestore.instance
                              .collection('games')
                              .doc(gameCode)
                              .update({
                                'wordState': 'INIT',
                                'gameStarted': false,
                                'votes': [],
                                'usedWords': [],
                                'currentRound': 0,
                                'players': players,
                                'votingExpiration': FieldValue.delete(),
                              });
                        },
                      ),
                      SizedBox(width: 10),
                      CupertinoButton.tinted(
                        color: CupertinoColors.white,
                        child: Icon(
                          CupertinoIcons.xmark_circle_fill,
                          color: CupertinoColors.destructiveRed,
                        ),
                        onPressed: () {
                          if (!mounted) {
                            return;
                          }

                          // Prompt for confirmation
                          showCupertinoDialog(
                            context: context,
                            builder: (context) {
                              return CupertinoAlertDialog(
                                title: const Text('Stop Game'),
                                content: const Text(
                                  'Are you sure you want to stop the game?',
                                ),
                                actions: [
                                  CupertinoDialogAction(
                                    child: const Text('Cancel'),
                                    onPressed: () {
                                      Navigator.pop(context);
                                    },
                                  ),
                                  CupertinoDialogAction(
                                    child: const Text('Stop'),
                                    onPressed: () {
                                      Navigator.pop(context);
                                      GameLobby.exitGame(
                                        context,
                                        gameCode,
                                        widget.prefs,
                                      );
                                    },
                                  ),
                                ],
                              );
                            },
                          );
                        },
                      ),
                      SizedBox(width: 10),
                      getNextButtonByWordState(),
                    ],
                  )
                  : CupertinoButton.tinted(
                    color: CupertinoColors.white,
                    child: Text(
                      'Leave Game',
                      style: TextStyle(color: CupertinoColors.white),
                    ),
                    onPressed: () async {
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
        ),
      ),
    );
  }
}
