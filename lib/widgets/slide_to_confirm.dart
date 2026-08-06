import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// The thumb must be dragged across [threshold] of the available travel; any
/// shorter drag springs back untouched. Used for "Slide to start charging"
/// and "Slide to stop".
class SlideToConfirm extends StatefulWidget {
  const SlideToConfirm({
    super.key,
    required this.label,
    required this.onConfirmed,
    this.enabled = true,
    this.loading = false,
    this.color,
    this.icon = Icons.bolt,
    this.hint,
    this.confirmationTitle = 'Confirm action',
    this.confirmationMessage = 'Confirm this action?',
  });

  final String label;

  /// Runs once per armed drag. May be async; the caller owns the busy state
  /// through [loading].
  final FutureOr<void> Function() onConfirmed;

  final bool enabled;

  final bool loading;

  final Color? color;

  final IconData icon;

  final String? hint;

  final String confirmationTitle;
  final String confirmationMessage;

  static const double threshold = 0.9;

  static const double height = 58;

  static const double thumbInset = 5;

  static const Duration _springBack = Duration(milliseconds: 220);

  static double thumbSize(double trackHeight) => trackHeight - 2 * thumbInset;

  static double travel(double trackWidth, double trackHeight) =>
      (trackWidth - trackHeight).clamp(0.0, double.infinity);

  static bool isArmed(double dragX, double travel) =>
      travel > 0 && dragX >= travel * threshold;

  @override
  State<SlideToConfirm> createState() => _SlideToConfirmState();
}

class _SlideToConfirmState extends State<SlideToConfirm> {
  double _dragX = 0;
  bool _dragging = false;
  bool _fired = false;
  bool _confirming = false;
  bool _committing = false;
  ModalRoute<bool>? _confirmationRoute;
  NavigatorState? _confirmationNavigator;

  bool get _interactive => widget.enabled && !widget.loading;

  void _onDragStart(DragStartDetails _) {
    if (!_interactive) return;
    setState(() {
      _dragging = true;
      _fired = false;
    });
  }

  void _onDragUpdate(DragUpdateDetails details, double travel) {
    if (!_interactive) return;
    setState(() => _dragX = (_dragX + details.delta.dx).clamp(0.0, travel));
  }

  void _onDragEnd(double travel) {
    if (!_interactive) return;

    final armed = SlideToConfirm.isArmed(_dragX, travel);
    setState(() {
      _dragging = false;
      _dragX = 0;
    });

    if (!armed || _fired) return;
    _fired = true;
    _commit();
  }

  void _cancelDrag() {
    if (!mounted) return;
    setState(() {
      _dragX = 0;
      _dragging = false;
    });
  }

  @override
  void didUpdateWidget(covariant SlideToConfirm oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_interactive) {
      _dragX = 0;
      _dragging = false;
      _dismissConfirmation();
    }
  }

  /// Remove only this control's dialog. A terminal session may already have
  /// placed its receipt above it, so popping the top route would close that.
  void _dismissConfirmation() {
    final route = _confirmationRoute;
    final navigator = _confirmationNavigator;
    _confirmationRoute = null;
    if (route == null || navigator == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (navigator.mounted && route.isActive) {
        navigator.removeRoute(route, false);
      }
    });
  }

  @override
  void dispose() {
    _dismissConfirmation();
    super.dispose();
  }

  Future<void> _commit() async {
    if (!_interactive || _committing) return;
    _committing = true;
    HapticFeedback.mediumImpact();
    try {
      await widget.onConfirmed();
    } finally {
      _committing = false;
    }
  }

  Future<void> _confirmAccessible() async {
    if (!_interactive || _confirming || _committing) return;
    _confirming = true;
    _confirmationNavigator = Navigator.of(context, rootNavigator: true);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        _confirmationRoute = ModalRoute.of<bool>(context);
        return AlertDialog(
          title: Text(widget.confirmationTitle),
          content: SingleChildScrollView(
            child: Text(widget.confirmationMessage),
          ),
          actions: [
            TextButton(
              autofocus: true,
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(widget.confirmationTitle),
            ),
          ],
        );
      },
    );
    _confirming = false;
    _confirmationRoute = null;
    if (!mounted || confirmed != true || !_interactive) return;
    await _commit();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.color ?? Theme.of(context).colorScheme.primary;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final travel = SlideToConfirm.travel(
              constraints.hasBoundedWidth
                  ? constraints.maxWidth
                  : SlideToConfirm.height,
              SlideToConfirm.height,
            );
            final thumbSize = SlideToConfirm.thumbSize(SlideToConfirm.height);
            final labelStyle = TextStyle(
              color: color,
              fontWeight: FontWeight.w600,
            );
            final labelPainter =
                TextPainter(
                  text: TextSpan(
                    text: widget.label,
                    style: DefaultTextStyle.of(context).style.merge(labelStyle),
                  ),
                  textDirection: Directionality.of(context),
                  textScaler: MediaQuery.textScalerOf(context),
                )..layout(
                  maxWidth: (constraints.maxWidth - 116).clamp(
                    1,
                    double.infinity,
                  ),
                );
            final trackHeight = (labelPainter.height + 16).clamp(
              SlideToConfirm.height,
              double.infinity,
            );
            labelPainter.dispose();

            return Opacity(
              opacity: widget.enabled ? 1 : 0.5,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onHorizontalDragStart: _onDragStart,
                onHorizontalDragUpdate: (details) =>
                    _onDragUpdate(details, travel),
                onHorizontalDragEnd: (_) => _onDragEnd(travel),
                onHorizontalDragCancel: _cancelDrag,
                excludeFromSemantics: true,
                child: SizedBox(
                  height: trackHeight,
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(
                              trackHeight / 2,
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        left: 0,
                        top: 0,
                        bottom: 0,
                        width:
                            _dragX + thumbSize + 2 * SlideToConfirm.thumbInset,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.22),
                            borderRadius: BorderRadius.circular(
                              trackHeight / 2,
                            ),
                          ),
                        ),
                      ),
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 58),
                          child: Text(
                            widget.label,
                            textAlign: TextAlign.center,
                            style: labelStyle,
                          ),
                        ),
                      ),
                      AnimatedPositioned(
                        duration:
                            _dragging || MediaQuery.disableAnimationsOf(context)
                            ? Duration.zero
                            : SlideToConfirm._springBack,
                        curve: Curves.easeOut,
                        left: _dragX + SlideToConfirm.thumbInset,
                        top: (trackHeight - thumbSize) / 2,
                        child: _Thumb(
                          size: thumbSize,
                          color: color,
                          icon: widget.icon,
                          loading: widget.loading,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
        TextButton(
          onPressed: _interactive ? _confirmAccessible : null,
          child: Text('${widget.confirmationTitle} with confirmation'),
        ),
        if (widget.hint != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              widget.hint!,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
      ],
    );
  }
}

class _Thumb extends StatelessWidget {
  const _Thumb({
    required this.size,
    required this.color,
    required this.icon,
    required this.loading,
  });

  final double size;
  final Color color;
  final IconData icon;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Center(
        child: loading
            ? SizedBox(
                width: size * 0.4,
                height: size * 0.4,
                child: CircularProgressIndicator(
                  strokeWidth: 2.4,
                  color: color,
                ),
              )
            : Icon(icon, color: color, size: size * 0.5),
      ),
    );
  }
}
