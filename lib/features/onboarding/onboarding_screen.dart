import 'package:chargenet_mobile/data/notifiers.dart';
import 'package:chargenet_mobile/features/onboarding/pages/features_page.dart';
import 'package:chargenet_mobile/features/onboarding/pages/welcome_page.dart';
import 'package:flutter/material.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  int _currentIndex = 0;

  void nextPage() {
    if (_currentIndex < 1) {
      setState(() {
        _currentIndex++;
      });
    } else {
      isUserOnboardedNotifier.value = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget pageContent;

    switch (_currentIndex) {
      case 0:
        pageContent = WelcomePage(onNext: nextPage);

      case 1:
        pageContent = FeaturesPage(onNext: nextPage);

      default:
        pageContent = const Center(
          child: Text("Redirecting to Home Screen..."),
        );
    }

    return Scaffold(body: SafeArea(child: pageContent));
  }
}
