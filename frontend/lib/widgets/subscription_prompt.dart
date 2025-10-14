import 'package:flutter/material.dart';
import '../user/subscriptions_page.dart';

void showSubscriptionPrompt(BuildContext context) {
  showDialog(
    context: context,
    builder: (BuildContext context) {
      return AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(
            width: 3,
            color: Colors.orange,
          ),
        ),
        title: const Text(
          'Go Premium!',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Color(0xFF00B4D8),
          ),
        ),
        content: const Text(
          'You have reached your limit. Subscribe to enjoy unlimited access to all features.',
        ),
        actions: [
          TextButton(
            child: const Text('Cancel'),
            onPressed: () {
              Navigator.of(context).pop();
            },
          ),
          ElevatedButton(
            child: const Text('Subscribe'),
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const SubscriptionsPage(),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00B4D8),
            ),
          ),
        ],
      );
    },
  );
}
