import 'package:intl/intl.dart';

final NumberFormat _myr = NumberFormat.currency(
  symbol: 'RM ',
  decimalDigits: 2,
);

String formatMyr(num amount) => _myr.format(amount);

String formatMoney(num amount, String currency) => currency == 'MYR'
    ? formatMyr(amount)
    : NumberFormat.currency(
        locale: 'en',
        symbol: '$currency ',
        decimalDigits: 2,
      ).format(amount);

String formatDecimalMoney(String amount, String currency) =>
    formatMoney(num.parse(amount), currency);

/// Unit prices retain up to six decimals; wallet amounts use minor units.
String formatTariff(num amount, String currency) =>
    '${currency == 'MYR' ? 'RM' : currency} '
    '${NumberFormat('#,##0.00####', 'en').format(amount)}';

String formatKwh(num kwh, {int decimals = 1}) =>
    '${kwh.toStringAsFixed(decimals)} kWh';

String formatKw(num kw, {int decimals = 1}) =>
    '${kw.toStringAsFixed(decimals)} kW';

/// Rounds money the way the backend does (`round2`), so a locally estimated
/// cost matches the eventual receipt.
double round2(num value) => (value * 100).roundToDouble() / 100;

/// Shown where the backend has not sent a reading yet.
///
/// A session that has just started has no live telemetry, and an estimate can
/// exist without a battery size: both cases must read "unknown", never `0`.
const String kNoValue = '—';

/// `58.4` → `58%`; `null` → [kNoValue]. Used by the monitor and the mini-bar.
String formatPercent(num? percent) =>
    percent == null ? kNoValue : '${percent.round()}%';

/// `872` → `00:14:32`: how a charging duration reads, on the monitor's
/// telemetry row and on the receipt alike.
///
/// Negative or missing values read `00:00:00`, so a row is never blank.
String formatDuration(int? seconds) {
  if (seconds == null || seconds < 0) return '00:00:00';

  final hours = seconds ~/ 3600;
  final minutes = (seconds % 3600) ~/ 60;
  final rest = seconds % 60;

  return '${hours.toString().padLeft(2, '0')}:'
      '${minutes.toString().padLeft(2, '0')}:'
      '${rest.toString().padLeft(2, '0')}';
}

String formatClock(int? seconds) => formatDuration(seconds);

/// `null` → [kNoValue]: a receipt for a session the backend has not dated.
String formatDateTime(DateTime? moment) => moment == null
    ? kNoValue
    : DateFormat('dd MMM yyyy, h:mm a').format(moment.toLocal());

String formatDayMonth(DateTime? moment) => moment == null
    ? kNoValue
    : DateFormat('dd MMM, h:mm a').format(moment.toLocal());

/// Returns `null` until the meter has delivered energy.
double? energyCost(num? kwh, double tariffPerKwh) =>
    kwh == null ? null : round2(kwh * tariffPerKwh);
