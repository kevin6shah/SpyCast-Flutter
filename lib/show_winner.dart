import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class ShowWinner extends StatefulWidget {
  const ShowWinner({super.key, required this.players});
  final List<dynamic> players;

  @override
  State<ShowWinner> createState() => _ShowWinnerState();
}

class _ShowWinnerState extends State<ShowWinner> {
  bool showResults = false;

  @override
  void initState() {
    super.initState();
    Duration delay = const Duration(seconds: 3);
    Future.delayed(delay, () {
      setState(() {
        showResults = true;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    List<dynamic> playersSorted = List.from(widget.players);
    playersSorted.sort((b, a) => a['points'].compareTo(b['points']));

    String winner = playersSorted[0]['name'];
    String winnerPoints = playersSorted[0]['points'].toString();

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Image.asset('assets/logos/spy.png', height: 200, color: Colors.white),
        const SizedBox(height: 20),
        Text(
          'Game Winner: $winner',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 25, color: Colors.white),
        ),
        const SizedBox(height: 10),
        Text(
          '$winnerPoints points',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 20, color: Colors.white),
        ),
        const SizedBox(height: 40),
        SizedBox(
          width: 200,
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
                    'Final Results',
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
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
