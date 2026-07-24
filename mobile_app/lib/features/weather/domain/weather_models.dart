/// Weather domain models — used by both data and presentation layers.
///
/// Moved from data/weather_repository.dart per Clean Architecture.
class WeatherCondition {
  final int code;
  final String text;

  const WeatherCondition({required this.code, required this.text});

  factory WeatherCondition.fromJson(Map<String, dynamic> json) {
    return WeatherCondition(
      code: json['code'] as int,
      text: json['text'] as String,
    );
  }
}

class CurrentWeather {
  final double temp;
  final double feelsLike;
  final WeatherCondition condition;
  final int humidity;
  final double windSpeed;

  const CurrentWeather({
    required this.temp,
    required this.feelsLike,
    required this.condition,
    required this.humidity,
    required this.windSpeed,
  });

  factory CurrentWeather.fromJson(Map<String, dynamic> json) {
    return CurrentWeather(
      temp: (json['temp'] as num).toDouble(),
      feelsLike: (json['feels_like'] as num).toDouble(),
      condition: WeatherCondition.fromJson(json['condition'] as Map<String, dynamic>),
      humidity: json['humidity'] as int,
      windSpeed: (json['wind_speed'] as num).toDouble(),
    );
  }
}

class DailyForecast {
  final DateTime date;
  final double tempMax;
  final double tempMin;
  final WeatherCondition condition;

  const DailyForecast({
    required this.date,
    required this.tempMax,
    required this.tempMin,
    required this.condition,
  });

  factory DailyForecast.fromJson(Map<String, dynamic> json) {
    return DailyForecast(
      date: DateTime.parse(json['date'] as String),
      tempMax: (json['temp_max'] as num).toDouble(),
      tempMin: (json['temp_min'] as num).toDouble(),
      condition: WeatherCondition.fromJson(json['condition'] as Map<String, dynamic>),
    );
  }
}

class HourlyForecast {
  final DateTime time;
  final double temp;
  final WeatherCondition condition;

  const HourlyForecast({
    required this.time,
    required this.temp,
    required this.condition,
  });

  factory HourlyForecast.fromJson(Map<String, dynamic> json) {
    return HourlyForecast(
      time: DateTime.parse(json['time'] as String),
      temp: (json['temp'] as num).toDouble(),
      condition: WeatherCondition.fromJson(json['condition'] as Map<String, dynamic>),
    );
  }
}

class WeatherData {
  final CurrentWeather current;
  final List<DailyForecast> daily;
  final List<HourlyForecast> hourly;

  const WeatherData({
    required this.current,
    required this.daily,
    required this.hourly,
  });

  factory WeatherData.fromJson(Map<String, dynamic> json) {
    return WeatherData(
      current: CurrentWeather.fromJson(json['current'] as Map<String, dynamic>),
      daily: (json['daily'] as List<dynamic>)
          .map((e) => DailyForecast.fromJson(e as Map<String, dynamic>))
          .toList(),
      hourly: (json['hourly'] as List<dynamic>)
          .map((e) => HourlyForecast.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}
