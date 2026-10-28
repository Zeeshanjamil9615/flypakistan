import 'package:intl/intl.dart';

/// One rental car from https://flypakistan.pk/api/fetch-cars.
class CarModel {
  final String id;
  final String name;
  final String description;
  final String year;
  final String city;
  final String currency;

  /// Rent for driving within the city.
  final double? rate;

  /// Rent for driving out of the city.
  final double? outRate;
  final String image;

  /// Car page on the website.
  final String detailsUrl;

  const CarModel({
    required this.id,
    required this.name,
    required this.description,
    required this.year,
    required this.city,
    required this.currency,
    required this.image,
    required this.detailsUrl,
    this.rate,
    this.outRate,
  });

  factory CarModel.fromJson(Map<String, dynamic> json) {
    return CarModel(
      id: json['id']?.toString() ?? '',
      name: _unescapeHtml(json['vehicle_name']?.toString() ?? '').trim(),
      description: _unescapeHtml(json['description']?.toString() ?? '')
          .replaceAll('\r\n', '\n')
          .trim(),
      year: json['vehicle_year']?.toString().trim() ?? '',
      city: json['city']?.toString().trim() ?? '',
      currency: (json['currency']?.toString().trim().isNotEmpty ?? false)
          ? json['currency'].toString().trim()
          : 'PKR',
      rate: _toDouble(json['rate']),
      outRate: _toDouble(json['out_rate']),
      image: json['image']?.toString().trim() ?? '',
      detailsUrl: json['details_url']?.toString().trim() ?? '',
    );
  }

  bool get hasRate => (rate ?? 0) > 0;

  /// "PKR 6,000", or "On Call" when the rate is missing.
  String rateLabel(double? amount) =>
      (amount ?? 0) > 0 ? formatAmount(amount!) : 'On Call';

  String formatAmount(double amount) =>
      '$currency ${NumberFormat('#,##0').format(amount)}';

  static double? _toDouble(dynamic value) =>
      value == null ? null : double.tryParse(value.toString());

  /// Descriptions are HTML-escaped, e.g. 'Ac &amp; Heater'.
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
}
