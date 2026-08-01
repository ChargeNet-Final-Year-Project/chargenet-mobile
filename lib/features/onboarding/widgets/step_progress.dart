import 'package:chargenet_mobile/data/constants.dart';
import 'package:flutter/material.dart';

class StepProgressWidget extends StatelessWidget {
  final int numOfSteps;
  final int currentStep;

  const StepProgressWidget({
    super.key,
    required this.numOfSteps,
    required this.currentStep,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Step $currentStep of $numOfSteps',
      child: ExcludeSemantics(
        child: Align(
          alignment: Alignment.centerLeft,
          child: SizedBox(
            width: 150,
            child: Row(
              children: List.generate(numOfSteps, (index) {
                return Expanded(
                  child: Container(
                    height: 7,
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    decoration: BoxDecoration(
                      color: index < currentStep
                          ? Theme.of(context).colorScheme.primary
                          : Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(
                        KConstants.circularBorderRadius,
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
        ),
      ),
    );
  }
}
