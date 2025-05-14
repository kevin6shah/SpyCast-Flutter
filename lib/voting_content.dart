import 'package:flutter/cupertino.dart';
import 'package:spycast/game_lobby.dart';

class VotingContent extends StatefulWidget {
  final List<dynamic> players;
  final int waitingOnNumPlayers;
  final int numSpies;
  final String userName;
  final void Function(List<String> votedFor) onVote;
  final List<dynamic>? votedFor;

  const VotingContent({
    super.key,
    required this.players,
    required this.waitingOnNumPlayers,
    required this.userName,
    required this.onVote,
    required this.votedFor,
    required this.numSpies,
  });

  @override
  State<VotingContent> createState() => _VotingContentState();
}

class _VotingContentState extends State<VotingContent> {
  final Set<String> _selectedVotes = {};
  bool _hasVoted = false;

  @override
  void initState() {
    super.initState();
    if (widget.votedFor != null) {
      _selectedVotes.addAll(
        widget.votedFor!.map((e) => widget.players[e]['name']),
      );

      _hasVoted = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: 20),
          Icon(
            CupertinoIcons.person_3_fill,
            color: CupertinoColors.white,
            size: 80,
          ),
          const SizedBox(height: 20),
          Text(
            'Tap ${widget.numSpies} player${widget.numSpies > 1 ? "s" : ""} to vote for the spy\nYou can only vote once!',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 16, color: CupertinoColors.white),
          ),
          const SizedBox(height: 30),
          Expanded(
            child: ListView.builder(
              itemCount: widget.players.length,
              itemBuilder: (context, index) {
                final player = widget.players[index];
                final name = player['name'];
                final isSelf = name == widget.userName;
                final isSelected = _selectedVotes.contains(name);

                return Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 30,
                    vertical: 6,
                  ),
                  child: CupertinoButton(
                    color:
                        isSelected
                            ? CupertinoColors.systemIndigo
                            : CupertinoColors.darkBackgroundGray,
                    disabledColor: CupertinoColors.systemGrey,
                    onPressed:
                        (_hasVoted ||
                                isSelf ||
                                isSelected ||
                                _selectedVotes.length >= widget.numSpies)
                            ? null
                            : () {
                              setState(() {
                                _selectedVotes.add(name);
                                if (_selectedVotes.length == widget.numSpies) {
                                  _hasVoted = true;
                                  widget.onVote(_selectedVotes.toList());
                                }
                              });
                            },
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          name + (isSelf ? " (You)" : ""),
                          style: const TextStyle(
                            color: CupertinoColors.white,
                            fontSize: 18,
                          ),
                        ),
                        if (isSelected)
                          const Icon(
                            CupertinoIcons.check_mark_circled_solid,
                            color: CupertinoColors.white,
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 15),
            child: WaitingDots(
              waitingText:
                  'Waiting for ${widget.waitingOnNumPlayers} players to vote',
              style: const TextStyle(
                color: CupertinoColors.white,
                fontSize: 16,
              ),
            ),
          ),
        ],
      
    );
  }
}
