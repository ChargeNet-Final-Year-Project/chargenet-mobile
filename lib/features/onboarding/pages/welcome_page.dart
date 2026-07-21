import 'package:chargenet_mobile/core/design_tokens.dart';
import 'package:chargenet_mobile/core/typography.dart';
import 'package:chargenet_mobile/data/constants.dart';
import 'package:chargenet_mobile/widgets/branding_widget.dart';
import 'package:chargenet_mobile/features/onboarding/widgets/step_progress.dart';
import 'package:flutter/material.dart';

class WelcomePage extends StatelessWidget {
  final VoidCallback onNext;
  const WelcomePage({super.key, required this.onNext});

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppDesign.background,
      child: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      children: [
                        const BrandingWidget(),
                        const SizedBox(height: 20),
                        const StepProgressWidget(numOfSteps: 2, currentStep: 1),
                        const SizedBox(height: 25),
                        const Text(
                          'One app, Charge Anywhere.',
                          textAlign: TextAlign.center,
                          style: AppTypography.welcomeTitle,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Find nearby chargers, compare tariffs, check charging bay availability, and manage all your charging sessions — in one place.',
                          textAlign: TextAlign.center,
                          style: AppTypography.bodyLarge.copyWith(
                            color: AppDesign.secondaryText,
                          ),
                        ),
                        const SizedBox(height: 30),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton(
                            onPressed: onNext,
                            style: FilledButton.styleFrom(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(
                                  KConstants.circularBorderRadius,
                                ),
                              ),
                            ),
                            child: const Padding(
                              padding: EdgeInsets.symmetric(vertical: 15),
                              child: Text('Get Started'),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
