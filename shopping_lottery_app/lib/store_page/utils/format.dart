import 'package:intl/intl.dart';

final _currencyFormatter = NumberFormat.decimalPattern('zh_TW');

String formatTwd(int value) => 'NT\u0024 ${_currencyFormatter.format(value)}';

String formatDateYmd(DateTime dt) {
  final y = dt.year.toString().padLeft(4, '0');
  final m = dt.month.toString().padLeft(2, '0');
  final d = dt.day.toString().padLeft(2, '0');
  return '$y-$m-$d';
}

String formatDateZhTw(DateTime dt) {
  // e.g. 2026/3/2
  try {
    return DateFormat.yMd('zh_TW').format(dt);
  } catch (_) {
    return '${dt.year}/${dt.month}/${dt.day}';
  }
}
