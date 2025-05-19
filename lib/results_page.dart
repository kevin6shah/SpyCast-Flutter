import 'package:flutter/cupertino.dart';
import 'package:spycast/game_lobby.dart';

class ResultsPage extends StatefulWidget {
  const ResultsPage({
    super.key,
    required this.spyWin,
    required this.players,
    required this.numSpies,
    required this.currentRound,
    required this.currWord,
  });
  final bool spyWin;
  final int numSpies;
  final List<dynamic> players;
  final int currentRound;
  final String currWord;

  @override
  State<ResultsPage> createState() => _ResultsPageState();
}

class _ResultsPageState extends State<ResultsPage> {
  bool resultIconShown = true;
  double spiesHeight = 0;
  bool showResults = false;

  String getWinnerText() {
    if (widget.spyWin) {
      return (widget.numSpies == 1) ? 'Spy Wins!' : 'Spies Win!';
    } else {
      return 'Players Win!';
    }
  }

  @override
  void initState() {
    super.initState();
    Duration delay = const Duration(seconds: 1);
    Duration delay2 = const Duration(seconds: 2);
    Future.delayed(delay, () {
      setState(() {
        resultIconShown = false;
      });
    });
    Future.delayed(delay2, () {
      setState(() {
        spiesHeight = 350;
        showResults = true;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    List<String> spies =
        widget.players
            .where((player) => player['isSpy'])
            .map((player) => player['name'])
            .toList()
            .cast<String>();

    List<dynamic> playersSorted = List.from(widget.players);
    playersSorted.sort((b, a) => a['points'].compareTo(b['points']));

    return Center(
      child: Stack(
        fit: StackFit.expand,
        children: [
          AnimatedPositioned(
            duration: const Duration(seconds: 3),
            curve: Curves.easeInOut,
            top: 20,
            left:
                resultIconShown
                    ? MediaQuery.of(context).size.width / 2 - 100
                    : 20,
            right:
                resultIconShown
                    ? MediaQuery.of(context).size.width / 2 - 100
                    : null,
            child: Column(
              children: [
                (widget.spyWin)
                    ? ClipRect(
                      child: Align(
                        alignment: Alignment.center,
                        widthFactor: 0.6,
                        heightFactor: 0.65,
                        child: Image.asset(
                          'assets/logos/spy.png',
                          color: CupertinoColors.white,
                          height: 200,
                        ),
                      ),
                    )
                    : Icon(
                      CupertinoIcons.person_3,
                      color: CupertinoColors.white,
                      size: 100,
                    ),
                const SizedBox(height: 20),
                Text(
                  getWinnerText(),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 25,
                    color: CupertinoColors.white,
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            top: 55,
            right: 0,
            child: AnimatedContainer(
              duration: const Duration(seconds: 7),
              curve: Curves.easeOut,
              height: spiesHeight,
              width: 180,
              child: ClipRect(
                child: Align(
                  alignment: Alignment.topCenter,
                  heightFactor: 1.0,
                  child: Text(
                    'Spies:\n\n${spies.join("\n")}',
                    textAlign: TextAlign.right,
                    style: const TextStyle(
                      fontSize: 20,
                      color: CupertinoColors.white,
                    ),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            top: 270,
            left: 0,
            right: 0,
            child: SizedBox(
              width: 180,
              child: TweenAnimationBuilder<double>(
                tween: Tween<double>(begin: 0, end: showResults ? 1 : 0),
                duration: const Duration(seconds: 7),
                curve: Curves.easeOut,
                builder: (context, value, child) {
                  return ClipRect(
                    child: Align(
                      alignment: Alignment.topCenter,
                      heightFactor: value,
                      child: child,
                    ),
                  );
                },
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      Text(
                        capitalizeWords(widget.currWord),
                        textAlign: TextAlign.left,
                        style: const TextStyle(
                          fontSize: 25,
                          fontWeight: FontWeight.w600,
                          color: CupertinoColors.white,
                        ),
                      ),
                      SizedBox(height: 10),
                      Text(
                        'Round ${widget.currentRound} Results',
                        textAlign: TextAlign.left,
                        style: const TextStyle(
                          fontSize: 20,
                          color: CupertinoColors.white,
                        ),
                      ),
                      SizedBox(height: 5),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Players',
                            textAlign: TextAlign.left,
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w600,
                              color: CupertinoColors.white,
                            ),
                          ),
                          Text(
                            'Points',
                            textAlign: TextAlign.right,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w600,
                              color: CupertinoColors.white,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      SizedBox(
                        height: 200,
                        child: Padding(
                          padding: const EdgeInsets.all(5),
                          child: ListView.builder(
                            shrinkWrap: true,
                            itemCount: playersSorted.length,
                            itemBuilder: (context, index) {
                              return Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      playersSorted[index]['name'],
                                      textAlign: TextAlign.left,
                                      style: const TextStyle(
                                        fontSize: 18,
                                        color: CupertinoColors.white,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    playersSorted[index]['points'].toString(),
                                    textAlign: TextAlign.right,
                                    style: const TextStyle(
                                      fontSize: 18,
                                      color: CupertinoColors.white,
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
