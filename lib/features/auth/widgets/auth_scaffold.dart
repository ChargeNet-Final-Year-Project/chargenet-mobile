import 'package:chargenet_mobile/core/design_tokens.dart';
import 'package:chargenet_mobile/core/typography.dart';
import 'package:chargenet_mobile/data/constants.dart';
import 'package:chargenet_mobile/widgets/branding_widget.dart';
import 'package:flutter/material.dart';

/// Shared shell for the sign-in and sign-up forms.
///
/// Both screens show the same branding header and raised card, so only the
/// fields and the primary action differ; the layout lives here instead of being
/// duplicated per screen. The body scrolls, which keeps the forms usable when
/// the keyboard covers the lower half of a small phone.
class AuthScaffold extends StatelessWidget {
  final String title;
  final String subtitle;

  /// The form fields, stacked with [childGap] between them.
  final List<Widget> children;

  /// Inline failure text, e.g. `ApiException.message` from a rejected login.
  final String? error;

  /// Rendered under the card: the link to the other auth screen.
  final Widget? footer;

  static const double childGap = 16;

  const AuthScaffold({
    super.key,
    required this.title,
    required this.subtitle,
    required this.children,
    this.error,
    this.footer,
  });

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    return Scaffold(
      body: Stack(
        children: [
          // The same tinted band as the profile tab, so the auth screens look
          // like the rest of the app.
          SizedBox(
            width: double.infinity,
            height: 190,
            child: ColoredBox(color: primary.withValues(alpha: 0.15)),
          ),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(18, 26, 18, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const BrandingWidget(),
                  const SizedBox(height: 18),
                  Text(title, style: AppTypography.pageTitle),
                  const SizedBox(height: 6),
                  Text(
                    subtitle,
                    style: AppTypography.body.copyWith(
                      color: AppDesign.secondaryText,
                    ),
                  ),
                  const SizedBox(height: 22),
                  Container(
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardColor,
                      borderRadius: BorderRadius.circular(
                        KConstants.circularBorderRadius,
                      ),
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
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (error != null) ...[
                            _ErrorBanner(message: error!),
                            const SizedBox(height: childGap),
                          ],
                          for (final (index, child) in children.indexed) ...[
                            if (index > 0) const SizedBox(height: childGap),
                            child,
                          ],
                        ],
                      ),
                    ),
                  ),
                  if (footer != null) ...[
                    const SizedBox(height: 6),
                    Center(child: footer),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Inline rejection banner: wrong credentials, taken email, validation errors.
class _ErrorBanner extends StatelessWidget {
  final String message;

  const _ErrorBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: scheme.errorContainer.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.error_outline, size: 18, color: scheme.error),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(fontSize: 13, color: scheme.error),
            ),
          ),
        ],
      ),
    );
  }
}
