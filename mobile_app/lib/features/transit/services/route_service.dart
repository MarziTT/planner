/// Route service — subway / transit route planning.
///
/// Calls backend `/api/v1/transit/route` with from/to station names.
/// Also provides station search for autocomplete.
///
/// Spec: §6.4 — 地铁/出行路线

import 'package:dio/dio.dart';

import '../models/transit.dart';

class RouteService {
  final Dio _dio;

  RouteService({required Dio dio}) : _dio = dio;

  /// Search subway stations by keyword for autocomplete.
  Future<List<String>> searchStations(String keyword, {int limit = 10}) async {
    if (keyword.trim().isEmpty) return [];

    final response = await _dio.get(
      '/transit/stations',
      queryParameters: {'q': keyword.trim(), 'limit': limit},
    );

    final body = response.data as Map<String, dynamic>;
    final data = body['data'] as Map<String, dynamic>? ?? {};
    final stations = (data['stations'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList() ??
        [];

    return stations;
  }

  /// Plan a subway route between two stations.
  ///
  /// Returns [TransitRoute] or null if no route found.
  Future<TransitRoute?> planRoute(String fromStation, String toStation) async {
    try {
      final response = await _dio.post(
        '/transit/route',
        data: {
          'from_station': fromStation.trim(),
          'to_station': toStation.trim(),
        },
      );

      final body = response.data as Map<String, dynamic>;
      final data = body['data'] as Map<String, dynamic>?;
      if (data == null) return null;

      return TransitRoute.fromJson(data);
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return null;
      rethrow;
    }
  }
}
