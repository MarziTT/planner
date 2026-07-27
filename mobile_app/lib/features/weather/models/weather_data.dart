/// Detailed weather data model for smart-advisory timeline items.
///
/// Includes full weather metrics plus air quality from OpenAQ.
/// Separate from domain/weather_models.dart which covers the legacy /weather/ endpoint.
class DetailedWeatherData {
  final double temp;
  final double feelsLike;
  final String condition;
  final double precipitation; // probability 0-100
  final double windSpeed; // m/s
  final int humidity; // %
  final double uvIndex;
  final double visibility; // km
  final double? pm25;
  final double? pm10;
  final double? o3;
  final double? no2;

  const DetailedWeatherData({
    required this.temp,
    required this.feelsLike,
    required this.condition,
    required this.precipitation,
    required this.windSpeed,
    required this.humidity,
    required this.uvIndex,
    required this.visibility,
    this.pm25,
    this.pm10,
    this.o3,
    this.no2,
  });

  factory DetailedWeatherData.fromJson(Map<String, dynamic> json) {
    return DetailedWeatherData(
      temp: (json['temp'] as num).toDouble(),
      feelsLike: (json['feels_like'] as num).toDouble(),
      condition: json['condition'] as String? ?? '',
      precipitation: (json['precipitation'] as num?)?.toDouble() ?? 0,
      windSpeed: (json['wind_speed'] as num?)?.toDouble() ?? 0,
      humidity: (json['humidity'] as num?)?.toInt() ?? 0,
      uvIndex: (json['uv_index'] as num?)?.toDouble() ?? 0,
      visibility: (json['visibility'] as num?)?.toDouble() ?? 0,
      pm25: (json['pm25'] as num?)?.toDouble(),
      pm10: (json['pm10'] as num?)?.toDouble(),
      o3: (json['o3'] as num?)?.toDouble(),
      no2: (json['no2'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toJson() => {
        'temp': temp,
        'feels_like': feelsLike,
        'condition': condition,
        'precipitation': precipitation,
        'wind_speed': windSpeed,
        'humidity': humidity,
        'uv_index': uvIndex,
        'visibility': visibility,
        if (pm25 != null) 'pm25': pm25,
        if (pm10 != null) 'pm10': pm10,
        if (o3 != null) 'o3': o3,
        if (no2 != null) 'no2': no2,
      };
}
