import 'package:intl/intl.dart';

final _rupees = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

String formatPaise(int? paise) => paise == null ? '—' : _rupees.format(paise / 100);

String formatTime(String iso) => DateFormat.jm().format(DateTime.parse(iso).toLocal());

String formatDate(String iso) => DateFormat('EEE, d MMM').format(DateTime.parse(iso).toLocal());

String isoDate(DateTime d) => DateFormat('yyyy-MM-dd').format(d);

String titleCase(String s) =>
    s.replaceAll('_', ' ').replaceAll('-', ' ').split(' ').map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}').join(' ');
