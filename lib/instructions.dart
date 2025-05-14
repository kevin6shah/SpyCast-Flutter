import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:spycast/main.dart';

class Instructions extends StatelessWidget {
  final bool? isDark;
  const Instructions({super.key, this.isDark});

  @override
  Widget build(BuildContext context) {
    final isDark = this.isDark ?? !ThemeUtils.isLightMode(context);
    final primaryText = isDark ? CupertinoColors.white : CupertinoColors.black;
    final secondaryText =
        isDark ? CupertinoColors.systemGrey2 : CupertinoColors.secondaryLabel;
    final accent = CupertinoColors.systemBrown;

    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(middle: Text('Instructions')),
      backgroundColor: isDark ? CupertinoColors.black : CupertinoColors.white,
      child: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Text(
                  'How to Play SpyCast',
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                    color: primaryText,
                  ),
                ),
              ),
              SizedBox(height: 28),
              _buildStep(
                number: 1,
                text: 'Create a game and wait for everyone to join.',
                color: accent,
                textColor: primaryText,
              ),
              _buildStep(
                number: 2,
                text:
                    'When the game starts, everyone except the spies will receive a secret word.',
                color: accent,
                textColor: primaryText,
              ),
              _buildStep(
                number: 3,
                text:
                    'Players take turns asking each other questions about the word, trying to figure out who the spy is.',
                color: accent,
                textColor: primaryText,
              ),
              _buildStep(
                number: 4,
                text:
                    'If you are a spy, you do not know the word. Listen carefully to the questions and answers to guess the word and blend in.',
                color: accent,
                textColor: primaryText,
              ),
              _buildStep(
                number: 5,
                text:
                    'At any time, players can try to identify the spy. If the spy is caught, everyone else wins. If the spy guesses the word, the spy wins!',
                color: accent,
                textColor: primaryText,
              ),
              SizedBox(height: 32),
              Text(
                'Tips',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.2,
                  color: accent,
                ),
              ),
              SizedBox(height: 10),
              _buildBullet(
                'Ask creative questions to avoid giving away the word.',
                bulletColor: accent,
                textColor: secondaryText,
              ),
              _buildBullet(
                'As a spy, pay close attention and try to deduce the word from context.',
                bulletColor: accent,
                textColor: secondaryText,
              ),
              _buildBullet(
                'Have fun and don\'t be afraid to bluff!',
                bulletColor: accent,
                textColor: secondaryText,
              ),
              SizedBox(height: 40),
              // Add new section for Point System
              Text(
                'Point System',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.2,
                  color: accent,
                ),
              ),
              SizedBox(height: 10),
              _buildBullet(
                'If the spy wins: Each spy gets 3 points. Non-spies get 1 point if they voted for a spy, otherwise 0.',
                bulletColor: accent,
                textColor: secondaryText,
              ),
              _buildBullet(
                'If the spy loses: Each spy gets 0 points. Non-spies get 2 points if they voted for a spy, otherwise 1.',
                bulletColor: accent,
                textColor: secondaryText,
              ),
              _buildBullet(
                'Points are added up individually after each round.',
                bulletColor: accent,
                textColor: secondaryText,
              ),
              SizedBox(height: 40),
              Divider(
                thickness: 1.2,
                color:
                    isDark
                        ? CupertinoColors.systemGrey
                        : CupertinoColors.systemGrey4,
              ),
              SizedBox(height: 12),
              Center(
                child: Column(
                  children: [
                    Text(
                      'App created by',
                      style: TextStyle(fontSize: 14, color: secondaryText),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Kevin Shah',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: accent,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStep({
    required int number,
    required String text,
    required Color color,
    required Color textColor,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$number.',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(fontSize: 16, height: 1.35, color: textColor),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBullet(
    String text, {
    required Color bulletColor,
    required Color textColor,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('•', style: TextStyle(fontSize: 18, color: bulletColor)),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(fontSize: 15, height: 1.3, color: textColor),
            ),
          ),
        ],
      ),
    );
  }
}
