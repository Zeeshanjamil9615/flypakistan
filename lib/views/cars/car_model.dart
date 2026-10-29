import 'package:intl/intl.dart';

/// One rental car from https://flypakistan.pk/api/fetch-cars or
/// https://flypakistan.pk/api/car-details.
class CarModel {
  final String id;
  final String name;
  final String description;
  final String year;
  final String city;
  final String currency;

  /// Color, seats and transmission only come from the car-details API;
  /// fetch-cars leaves them empty / 0.
  final String color;
  final int capacity;
  final String transmission;

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
    this.color = '',
    this.capacity = 0,
    this.transmission = '',
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
      // Sent in any case, e.g. 'grey', 'manual'.
      color: _capitalize(json['vehicle_color']?.toString() ?? ''),
      capacity: int.tryParse(json['vehicle_capacity']?.toString() ?? '') ?? 0,
      transmission: _capitalize(
        json['vehicle_transmission']?.toString() ?? '',
      ),
    );
  }

  bool get hasRate => (rate ?? 0) > 0;

  bool get hasSpecs =>
      color.isNotEmpty || capacity > 0 || transmission.isNotEmpty;

  /// "4 Persons", as on the website.
  String get capacityLabel => capacity == 1 ? '1 Person' : '$capacity Persons';

  /// "PKR 6,000", or "On Call" when the rate is missing.
  String rateLabel(double? amount) =>
      (amount ?? 0) > 0 ? formatAmount(amount!) : 'On Call';

  String formatAmount(double amount) =>
      '$currency ${NumberFormat('#,##0').format(amount)}';

  static double? _toDouble(dynamic value) =>
      value == null ? null : double.tryParse(value.toString());

  /// 'grey and white' -> 'Grey and white'
  static String _capitalize(String value) {
    final String trimmed = value.trim();
    if (trimmed.isEmpty) return trimmed;
    return trimmed[0].toUpperCase() + trimmed.substring(1);
  }

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
