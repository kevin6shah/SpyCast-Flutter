import 'package:flutter/cupertino.dart';
import 'package:url_launcher/url_launcher.dart';

class UpdateRequiredApp extends StatelessWidget {
  const UpdateRequiredApp({super.key});

  @override
  Widget build(BuildContext context) {
    return CupertinoApp(
      home: CupertinoPageScaffold(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'A new version of the app is required.',
                style: TextStyle(fontSize: 18),
              ),
              const SizedBox(height: 20),
              CupertinoButton.filled(
                child: const Text('Update Now'),
                onPressed: () async {
                  // TODO: Update the URL to your app's App Store link
                  const appStoreUrl =
                      'https://apps.apple.com/app/idYOUR_APP_ID'; // Replace YOUR_APP_ID with your app's App Store ID
                  if (await canLaunchUrl(Uri.parse(appStoreUrl))) {
                    await launchUrl(
                      Uri.parse(appStoreUrl),
                      mode: LaunchMode.externalApplication,
                    );
                  } else {
                    if (context.mounted) {
                      showCupertinoDialog(
                        context: context,
                        builder:
                            (context) => CupertinoAlertDialog(
                              title: const Text('Error'),
                              content: const Text(
                                'Could not open the App Store.',
                              ),
                              actions: [
                                CupertinoDialogAction(
                                  child: const Text('OK'),
                                  onPressed: () => Navigator.of(context).pop(),
                                ),
                              ],
                            ),
                      );
                    }
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
