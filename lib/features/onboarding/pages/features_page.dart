import 'package:chargenet_mobile/core/design_tokens.dart';
import 'package:chargenet_mobile/core/typography.dart';
import 'package:chargenet_mobile/data/constants.dart';
import 'package:chargenet_mobile/widgets/branding_widget.dart';
import 'package:chargenet_mobile/features/onboarding/widgets/step_progress.dart';
import 'package:chargenet_mobile/features/onboarding/widgets/feature_card_widget.dart';
import 'package:flutter/material.dart';

class FeaturesPage extends StatelessWidget {
  final VoidCallback onNext;
  const FeaturesPage({super.key, required this.onNext});

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppDesign.background,
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(22, 22, 22, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const BrandingWidget(),
              const SizedBox(height: 35),
              const StepProgressWidget(numOfSteps: 2, currentStep: 2),
              const SizedBox(height: 20),
              const Text('Discover & Charge', style: AppTypography.pageTitle),
              const SizedBox(height: 10),
              Text(
                'Everything you need for seamless EV charging, right here in one app.',
                style: AppTypography.body.copyWith(
                  color: AppDesign.secondaryText,
                ),
              ),
              const SizedBox(height: 25),
              const Padding(
                padding: EdgeInsets.all(8),
                child: FeatureCardWidget(
                  icon: Icons.pin_drop,
                  title: 'Real-Time Station Discovery',
                  description: 'Find nearby charging stations instantly with interactive map filtering and live availability updates.',
                ),
              ),
              const Padding(
                padding: EdgeInsets.all(8),
                child: FeatureCardWidget(
                  icon: Icons.ev_station,
                  title: 'Session Management',
                  description: 'Start, monitor, and stop charging sessions with real-time stats and cost tracking from your phone.',
                ),
              ),
              const SizedBox(height: 32),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.near_me,
                    color: Theme.of(context).colorScheme.primary,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Enable location access for nearby stations',
                      style: AppTypography.caption.copyWith(
                        color: AppDesign.secondaryText,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 25),
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
                    child: Text('Start My Journey'),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
