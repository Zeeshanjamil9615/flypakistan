import 'dart:convert';

import 'package:dio/dio.dart';

import '../views/tours/tour_model.dart';

/// Failure with a message that can be shown to the user as-is.
class ToursApiException implements Exception {
  final String message;

  const ToursApiException(this.message);

  @override
  String toString() => message;
}

class ApiServiceTours {
  static const String _url = 'https://flypakistan.pk/api/fetch-tours';

  /// Fetches all tours. Throws [ToursApiException] on any failure.
  Future<List<TourModel>> fetchTours() async {
    try {
      print('━━━ fetchTours REQUEST ━━━');
      print('URL: $_url');

      final response = await Dio().request(
        _url,
        options: Options(method: 'GET'),
      );

      print('━━━ fetchTours RESPONSE ━━━');
      print('Status: ${response.statusCode}');

      var data = response.data;
      if (data is String) {
        data = json.decode(data);
      }

      if (data is! Map || data['tours'] is! List) {
        final message = data is Map ? data['message']?.toString() : null;
        throw ToursApiException(
          (message != null && message.isNotEmpty)
              ? message
              : 'No tours available right now.',
        );
      }

      final List<TourModel> tours =
          (data['tours'] as List)
              .whereType<Map>()
              .map((tour) => TourModel.fromJson(Map<String, dynamic>.from(tour)))
              .where((tour) => tour.name.isNotEmpty)
              .toList();

      print('Tours: ${tours.length}');
      return tours;
    } on ToursApiException {
      rethrow;
    } on DioException catch (e) {
      print('━━━ fetchTours DIO ERROR ━━━');
      print('Message: ${e.message}');
      throw const ToursApiException(
        'Could not load tours. Please check your internet connection.',
      );
    } catch (e) {
      print('━━━ fetchTours ERROR ━━━');
      print('$e');
      throw const ToursApiException('Could not load tours. Please try again.');
    }
  }
}
