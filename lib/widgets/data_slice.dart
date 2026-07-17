import 'package:flutter/material.dart';
import 'package:chargenet_mobile/data/load_state.dart';
import 'package:chargenet_mobile/core/design_tokens.dart';

/// A failed first load never renders the default balance or empty collection.
/// Refresh failures preserve the last successful child and its update time.
class DataSlice extends StatelessWidget {
  const DataSlice({
    super.key,
    required this.state,
    required this.label,
    required this.onRetry,
    required this.child,
    this.expand = false,
  });
  final ValueNotifier<DataLoadState> state;
  final String label;
  final Future<void> Function() onRetry;
  final Widget child;
  final bool expand;

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<DataLoadState>(
    valueListenable: state,
    builder: (context, status, _) {
      final showNotice =
          !status.hasData || status.loading || status.error != null;
      final time = status.updatedAt == null
          ? ''
          : ' Last updated ${TimeOfDay.fromDateTime(status.updatedAt!).format(context)}.';
      final notice = Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Semantics(
              liveRegion: true,
              child: Text(
                status.error != null
                    ? 'Could not load $label. ${status.error}'
                    : '${status.hasData ? 'Updating' : 'Loading'} $label…',
                style: TextStyle(
                  color: status.error == null
                      ? AppDesign.secondaryText
                      : AppDesign.danger,
                ),
              ),
            ),
            if (status.hasData && (status.error != null || status.loading))
              Text(
                'Showing last successful data.$time',
                style: const TextStyle(color: AppDesign.secondaryText),
              ),
            if (status.error != null)
              TextButton(
                onPressed: status.loading
                    ? null
                    : () async {
                        try {
                          await onRetry();
                        } catch (_) {
                          /* Endpoint state supplies persistent feedback. */
                        }
                      },
                child: const Text('Retry'),
              ),
          ],
        ),
      );
      return Column(
        mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (showNotice) notice,
          if (status.hasData)
            if (expand) Expanded(child: child) else child,
        ],
      );
    },
  );
}
