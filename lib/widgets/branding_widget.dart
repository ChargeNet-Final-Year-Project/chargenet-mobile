import 'package:chargenet_mobile/core/design_tokens.dart';
import 'package:flutter/material.dart';

class BrandingWidget extends StatelessWidget {
  const BrandingWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(Icons.electric_bolt, size: 14, color: AppDesign.primary),
        SizedBox(width: 3),
        Text(
          'ChargeNet',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            letterSpacing: -0.4,
          ),
        ),
      ],
    );
  }
}
