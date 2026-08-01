import 'dart:async';

import 'package:flutter/material.dart';

/// Floating "Search stations or area" pill over the map.
///
/// The field owns the debounce, so typing never fires one request per keystroke:
/// [onQueryChanged] runs 400 ms after the last keystroke, and immediately when
/// the query is cleared.
class SearchPillWidget extends StatefulWidget {
  const SearchPillWidget({
    super.key,
    required this.controller,
    required this.onQueryChanged,
    this.focusNode,
    this.debounce = const Duration(milliseconds: 400),
    this.hintText = 'Search stations or area',
  });

  /// Owned by the parent screen so it can be cleared/disposed there.
  final TextEditingController controller;

  /// Called with the trimmed query once typing pauses.
  final ValueChanged<String> onQueryChanged;
  final FocusNode? focusNode;

  final Duration debounce;
  final String hintText;

  @override
  State<SearchPillWidget> createState() => _SearchPillWidgetState();
}

class _SearchPillWidgetState extends State<SearchPillWidget> {
  Timer? _debounceTimer;

  void _externalChange() {
    if (widget.controller.text.isEmpty) _debounceTimer?.cancel();
  }

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_externalChange);
  }

  @override
  void didUpdateWidget(covariant SearchPillWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_externalChange);
      widget.controller.addListener(_externalChange);
      _debounceTimer?.cancel();
    }
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    widget.controller.removeListener(_externalChange);
    super.dispose();
  }

  void _onChanged(String value) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(widget.debounce, () {
      if (widget.focusNode?.hasFocus ?? true) {
        widget.onQueryChanged(value.trim());
      }
    });
  }

  void _clear() {
    _debounceTimer?.cancel();
    widget.controller.clear();
    widget.onQueryChanged('');
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      elevation: 3,
      borderRadius: BorderRadius.circular(28),
      child: ValueListenableBuilder<TextEditingValue>(
        valueListenable: widget.controller,
        builder: (context, value, _) => TextField(
          controller: widget.controller,
          focusNode: widget.focusNode,
          onChanged: _onChanged,
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            hintText: widget.hintText,
            prefixIcon: const Icon(Icons.search),
            suffixIcon: value.text.isEmpty
                ? null
                : IconButton(
                    icon: const Icon(Icons.close),
                    tooltip: 'Clear search',
                    onPressed: _clear,
                  ),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
          ),
        ),
      ),
    );
  }
}
