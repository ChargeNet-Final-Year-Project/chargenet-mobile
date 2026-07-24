import 'package:chargenet_mobile/data/constants.dart';
import 'package:chargenet_mobile/data/models.dart';
import 'package:chargenet_mobile/data/notifiers.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class UserInfoCardWidget extends StatelessWidget {
  const UserInfoCardWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AppUser?>(
      valueListenable: currentUserNotifier,
      builder: (context, user, child) {
        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(
              KConstants.circularBorderRadius,
            ),
            color: Theme.of(context).cardColor,
            boxShadow: [
              BoxShadow(
                color: Colors.black12,
                blurRadius: 9,
                blurStyle: BlurStyle.outer,
                offset: Offset.zero,
                spreadRadius: 1,
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                CircleAvatar(radius: 35, child: Text(_initialsFor(user?.name))),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user?.name ?? 'ChargeNet driver',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 20,
                        ),
                      ),
                      Text(user?.email ?? 'Not signed in'),
                      if (user != null)
                        Text(
                          'Member since '
                          '${DateFormat('MMM yyyy').format(user.createdAt)}',
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// `Aisyah Rahman` → `AR`, falling back to `?` before the user is known.
  static String _initialsFor(String? name) {
    final words = (name ?? '')
        .trim()
        .split(RegExp(r'\s+'))
        .where((word) => word.isNotEmpty)
        .toList();
    if (words.isEmpty) return '?';
    if (words.length == 1) return words.first.substring(0, 1).toUpperCase();

    final first = words.first.substring(0, 1);
    final second = words[1].substring(0, 1);
    return '$first$second'.toUpperCase();
  }
}
