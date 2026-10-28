import 'package:intl/intl.dart';

/// One tour from https://flypakistan.pk/api/fetch-tours.
class TourModel {
  final String id;
  final String name;
  final String description;
  final String country;
  final String image;
  final bool priceOnCall;
  final String currency;
  final double? price;
  final double? adultRate;
  final double? childRate;
  final int paxNo;

  const TourModel({
    required this.id,
    required this.name,
    required this.description,
    required this.country,
    required this.image,
    required this.priceOnCall,
    required this.currency,
    this.price,
    this.adultRate,
    this.childRate,
    this.paxNo = 0,
  });

  factory TourModel.fromJson(Map<String, dynamic> json) {
    return TourModel(
      id: json['id']?.toString() ?? '',
      // Some names arrive with trailing spaces, e.g. 'Khanpur Day Tour '.
      name: _unescapeHtml(json['tour_name']?.toString() ?? '').trim(),
      description: _cleanDescription(json['description']?.toString() ?? ''),
      country: _titleCase(json['country']?.toString() ?? ''),
      image: json['image']?.toString().trim() ?? '',
      priceOnCall:
          json['price_on_call'] == true ||
          json['price_on_call']?.toString() == '1',
      currency: (json['currency']?.toString().trim().isNotEmpty ?? false)
          ? json['currency'].toString().trim()
          : 'PKR',
      price: _toDouble(json['price']),
      adultRate: _toDouble(json['adult_rate']),
      childRate: _toDouble(json['child_rate']),
      paxNo: int.tryParse(json['pax_no']?.toString() ?? '') ?? 0,
    );
  }

  bool get hasPrice => !priceOnCall && (price ?? 0) > 0;

  String get priceLabel => hasPrice ? formatAmount(price!) : 'Price On Call';

  String formatAmount(double amount) =>
      '$currency ${NumberFormat('#,##0').format(amount)}';

  static double? _toDouble(dynamic value) =>
      value == null ? null : double.tryParse(value.toString());

  /// Descriptions are HTML-escaped (`&quot;`) and use '\r\n' line breaks.
  static String _cleanDescription(String raw) {
    return _unescapeHtml(raw)
        .replaceAll('\r\n', '\n')
        .replaceAll(RegExp(r'\n{3,}'), '\n\n')
        .trim();
  }

  static String _unescapeHtml(String value) {
    return value
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#039;', "'")
        .replaceAll('&#39;', "'")
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&');
  }

  /// 'PAKISTAN' -> 'Pakistan'
  static String _titleCase(String value) {
    return value
        .trim()
        .toLowerCase()
        .split(RegExp(r'\s+'))
        .where((word) => word.isNotEmpty)
        .map((word) => word[0].toUpperCase() + word.substring(1))
        .join(' ');
  }
}
