import 'package:flutter/foundation.dart';

/// Metadata accompanies the existing value notifiers; an empty value is data
/// only after its own endpoint has succeeded.
class DataLoadState {
  const DataLoadState({
    this.hasData = false,
    this.loading = false,
    this.error,
    this.updatedAt,
  });
  const DataLoadState.ready()
    : hasData = true,
      loading = false,
      error = null,
      updatedAt = null;
  final bool hasData;
  final bool loading;
  final String? error;
  final DateTime? updatedAt;
}

final walletLoadNotifier = ValueNotifier(const DataLoadState());
final vehiclesLoadNotifier = ValueNotifier(const DataLoadState());
final historyLoadNotifier = ValueNotifier(const DataLoadState());
final transactionsLoadNotifier = ValueNotifier(const DataLoadState());
final cposLoadNotifier = ValueNotifier(const DataLoadState());
final activeSessionLoadNotifier = ValueNotifier(const DataLoadState());
