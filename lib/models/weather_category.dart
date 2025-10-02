import 'package:flutter/material.dart';

/// Weather categorization system for motorcycle safety
/// Based on research of dangerous conditions for motorcyclists
enum WeatherCategory {
  perfect(
      'Perfect',
      'Ideal weather with clear skies, mild temperatures, and calm winds',
      0xFF4CAF50),
  good('Good', 'Pleasant conditions with minor weather factors to consider',
      0xFF8BC34A),
  ok('Okay', 'Acceptable weather but requires extra caution and awareness',
      0xFFFFC107),
  bad('Bad', 'Challenging conditions with significant weather hazards present',
      0xFFFF9800),
  dangerous('Dangerous',
      'Severe weather posing serious safety risks - avoid riding', 0xFFF44336);

  const WeatherCategory(this.title, this.description, this.colorValue);

  final String title;
  final String description;
  final int colorValue;

  /// Get Color object from colorValue
  Color get color => Color(colorValue);
}

/// Weather condition thresholds for categorization
/// Updated to be more forgiving while keeping rain as bad and snow as dangerous
class WeatherThresholds {
  // Temperature thresholds (Celsius) - More forgiving ranges
  static const double perfectTempMin = 12.0; // Was 15.0
  static const double perfectTempMax = 28.0; // Was 25.0
  static const double goodTempMin = 7.0;     // Was 10.0
  static const double goodTempMax = 33.0;    // Was 30.0
  static const double okTempMin = 2.0;       // Was 5.0
  static const double okTempMax = 38.0;      // Was 35.0
  static const double dangerousTempMin = -5.0; // Reverted back
  static const double dangerousTempMax = 40.0;  // Reverted back

  // Wind speed thresholds (km/h) - More forgiving
  static const double perfectWindMax = 15.0; // Was 10.0
  static const double goodWindMax = 25.0;    // Was 20.0
  static const double okWindMax = 35.0;      // Was 30.0
  static const double badWindMax = 55.0;     // Was 50.0
  // Above 55 km/h is dangerous

  // Precipitation thresholds (mm/h) - Rain stays strict for safety
  static const double lightRain = 1.0;       // Unchanged - any rain is notable
  static const double moderateRain = 4.0;    // Unchanged - rain is bad for motorcycles
  static const double heavyRain = 10.0;      // Unchanged - heavy rain is dangerous
  // Above 10mm/h is dangerous

  // Visibility thresholds (km) - More forgiving
  static const double goodVisibility = 8.0;  // Was 10.0
  static const double okVisibility = 3.0;    // Was 5.0
  static const double badVisibility = 0.5;   // Was 1.0
  // Below 0.5km is dangerous
}

/// Weather data model for categorization
class WeatherData {
  final double temperature;
  final double windSpeed;
  final double windDirection;
  final double precipitation;
  final double precipitationProbability;
  final double visibility;
  final double humidity;
  final String weatherCode;
  final DateTime timestamp;

  const WeatherData({
    required this.temperature,
    required this.windSpeed,
    required this.windDirection,
    required this.precipitation,
    required this.precipitationProbability,
    required this.visibility,
    required this.humidity,
    required this.weatherCode,
    required this.timestamp,
  });

  /// Create WeatherData from JSON
  factory WeatherData.fromJson(Map<String, dynamic> json) {
    return WeatherData(
      temperature: (json['main']['temp'] as num).toDouble(),
      windSpeed: (json['wind']['speed'] as num).toDouble() *
          3.6, // Convert m/s to km/h
      windDirection: (json['wind']['deg'] as num?)?.toDouble() ?? 0.0,
      precipitation: ((json['rain']?['1h'] as num?) ?? 0.0).toDouble(),
      precipitationProbability: ((json['pop'] as num?) ?? 0.0).toDouble() * 100,
      visibility: ((json['visibility'] as num?) ?? 10000.0).toDouble() /
          1000, // Convert m to km
      humidity: (json['main']['humidity'] as num).toDouble(),
      weatherCode: json['weather'][0]['id'].toString(),
      timestamp: DateTime.fromMillisecondsSinceEpoch(json['dt'] * 1000),
    );
  }

  /// Get the weather category for this weather data
  WeatherCategory get category => categorize();

  /// Categorize weather conditions based on safety thresholds
  /// Rain is always bad, snow is always dangerous
  WeatherCategory categorize() {
    // Check for dangerous conditions first (including snow)
    if (_isDangerous()) {
      return WeatherCategory.dangerous;
    }

    // Check for rain - always bad regardless of amount
    if (_hasRain()) {
      return WeatherCategory.bad;
    }

    // Check for bad conditions
    if (_isBad()) {
      return WeatherCategory.bad;
    }

    // Check for OK conditions
    if (_isOk()) {
      return WeatherCategory.ok;
    }

    // Check for good conditions
    if (_isGood()) {
      return WeatherCategory.good;
    }

    // Default to perfect if all conditions are met
    return WeatherCategory.perfect;
  }

  /// Categorize weather conditions based on current weather + forecast data
  /// Takes current weather and next 8 hours of forecast to determine overall safety
  static WeatherCategory categorizeWithForecast(
      WeatherData current, List<WeatherData> forecast) {
    // Get the worst category from current weather
    WeatherCategory worstCategory = current.categorize();

    // Check forecast for next 8 hours (or available hours if less than 8)
    final hoursToCheck = forecast.length > 8 ? 8 : forecast.length;

    for (int i = 0; i < hoursToCheck; i++) {
      final forecastCategory = forecast[i].categorize();

      // If we find a worse condition in the forecast, use that
      if (_isWorse(forecastCategory, worstCategory)) {
        worstCategory = forecastCategory;
      }
    }

    return worstCategory;
  }

  /// Helper method to determine if one category is worse than another
  static bool _isWorse(WeatherCategory category1, WeatherCategory category2) {
    final index1 = WeatherCategory.values.indexOf(category1);
    final index2 = WeatherCategory.values.indexOf(category2);
    return index1 > index2; // Higher index means worse conditions
  }

  bool _isDangerous() {
    return temperature < WeatherThresholds.dangerousTempMin ||
        temperature > WeatherThresholds.dangerousTempMax ||
        windSpeed > WeatherThresholds.badWindMax ||
        precipitation > WeatherThresholds.heavyRain ||
        visibility < WeatherThresholds.badVisibility ||
        _hasStormyWeather(); // This includes snow conditions
  }

  bool _isBad() {
    return temperature < WeatherThresholds.okTempMin ||
        temperature > WeatherThresholds.okTempMax ||
        windSpeed > WeatherThresholds.okWindMax ||
        visibility < WeatherThresholds.okVisibility;
    // Removed precipitation check - handled separately in _hasRain()
  }

  bool _isOk() {
    return temperature < WeatherThresholds.goodTempMin ||
        temperature > WeatherThresholds.goodTempMax ||
        windSpeed > WeatherThresholds.goodWindMax ||
        visibility < WeatherThresholds.goodVisibility;
    // Removed precipitation check - handled separately in _hasRain()
  }

  bool _isGood() {
    return temperature < WeatherThresholds.perfectTempMin ||
        temperature > WeatherThresholds.perfectTempMax ||
        windSpeed > WeatherThresholds.perfectWindMax;
  }

  /// Check for any rain - rain is always bad for motorcycles
  bool _hasRain() {
    return precipitation > 0.0;
  }

  bool _hasStormyWeather() {
    // WMO Weather codes for dangerous conditions
    // 95-99: Thunderstorms
    // 85-86: Snow showers
    // 71-77: Snow fall
    final code = int.tryParse(weatherCode) ?? 0;
    return code >= 95 || // Thunderstorms
        (code >= 85 && code <= 86) || // Snow showers
        (code >= 71 && code <= 77); // Snow fall
  }

  /// Funny message pools for each weather category
  static const List<String> perfectMessages = [
    '🏍️ Perfect weather for riding today, but not as perfect as you! <3',
    '🏍️ The weather gods have blessed us! Time to show your motorcycle some looove!',
    '🏍️ Perfect riding conditions detected! Your bike is probably doing happy wheelies in the garage!',
    '🏍️ The weather\'s so perfect, even your perfect face has competition, babe.',
    '🏍️ Absolutely flawless weather for riding! Just like you, mi amor.',
    '🏍️ Sugar, this weather is chef\'s kiss perfect! Just like your butt.',
    '🏍️ The sun’s out, the roads are clear… and they’re all waiting for your legendary rides!',
    '🏍️ Perfect conditions detected, honey. Mother Nature herself is asking you on a date today.',
    '🏍️ The weather today is absolutely legen- wait for it- dary!',
    '🏍️ Excellent riding conditions on the horizon captain! Let\'s show off our riding skills.'
  ];

  static const List<String> goodMessages = [
    '🏍️ Good weather for riding! Not perfect, but hey, neither am I.',
    '🏍️ Pretty solid riding weather! Your bike is giving you the puppy dog eyes from the garage.',
    '🏍️ Good conditions ahead! Time to make some vrooom-vrooom magic happen.',
    '🏍️ Weather\'s looking good! Perfect excuse to ignore your responsibilities and ride.',
    '🏍️ Decent riding weather! Your motorcycle just sent you a ride request... accept it.',
    '🏍️ Good weather - good vibes. Like the ones we have when we ride.',
    '🏍️ Good riding conditions detected. Deploying motorcycle vehicle. Beep boop.',
    '🏍️ Good weather alert, boss! We have to make our escape with our motorcycles.',
    '🏍️ Solid riding weather and the cavalry is here! We ride at dawn!',
    '🏍️ Reporting good riding weather conditions, general! Private motorcycle on duty! '
  ];

  static const List<String> okMessages = [
    '🏍️ Okay conditions for riding, but you\'re definitely not just Okay - you\'re awesome!',
    '🏍️ Meh weather, but your riding skills are still fire! Proceed with care and style.',
    '🏍️ Okay-ish weather detected. Your bike says "I\'ve seen worse, let\'s do this!"',
    '🏍️ Weather\'s being a bit moody today, but so is your motorcycle - perfect match!',
    '🏍️ Conditions are Okay! Not great, not terrible... kind of like my cooking. Ride carefully.',
    '🏍️ Mediocre weather, but you\'re still spectacular, honey! Ride with extra style.',
    '🏍️ So-so conditions, sugar, but your awesomeness makes up for it! Proceed with caution and charm.',
    '🏍️ Okay weather detected. It\'s a Monday isn\'t it? Why is it always Mondays?',
    '🏍️ Average conditions outside but nothing average about your riding game dude.',
    '🏍️ Okay-ish weather outside but hey- I didn\'t hear no bell!'
  ];

  static const List<String> badMessages = [
    '🚗 Bad weather for riding! Your car misses you anyway - give it some attention.',
    '🚗 Weather\'s being a party pooper today. Time for four-wheeled adventures instead.',
    '🚗 Not ideal for riding weather. Your motorcycle understands and suggests Netflix instead.',
    '🚗 Bad riding conditions. Even your bike is wearing a raincoat and shaking its head.',
    '🚗 Weather says no to riding today. Your bike\'s four-wheeled sibling is awaiting your command.',
    '🚗 Rough weather today. Hey, cars have their upsides too I guess.',
    '🚗 Bad riding conditions, unfortunately. Your motorcycle needed a break anyway.',
    '🚗 Not great conditions for riding today, I am afraid. Car it is!',
    '🚗 Poor weather for riding today. C\'mon, the car was getting jealous anyway.',
    '🚗 Bad conditions detected, darling! Even your bike is suggesting a cozy indoor day!'
  ];

  static const List<String> dangerousMessages = [
    '🚗 Dangerous weather! Your motorcycle just filed a restraining order against today.',
    '🚗 Absolutely NOT riding weather! Even the car is thinking about it.',
    '🚗 Dangerous conditions for riding! I mean c\'mon, the car needs some love too.',
    '🚗 NOPE weather detected! Time to drive and live to ride another day dude.',
    '🚗 Extremely dangerous for riding! Just like you sexy beast. Rawr.',
    '🚗 Heeell no weather today. Your motorcycle just packed its bags and moved to Florida.',
    '🚗 Absolutely terrifying conditions. Your bike is hiding under a blanket fort.',
    '🚗 Dangerous zone weather, babe. Even your fearless motorcycle is calling in sick today.',
    '🚗 Dangerous weather conditions, unfortunately. You can conquer anything, but this one, you shouldn\'t',
    '🚗 NOPE-NOPE-NOPE weather, today! Your motorcycle just hired a bodyguard named "Garage Door".'
  ];

  /// Get recommendation message based on category
  String getRecommendation() {
    final category = categorize();
    final random =
        DateTime.now().millisecondsSinceEpoch % 5; // Simple randomization

    switch (category) {
      case WeatherCategory.perfect:
        return perfectMessages[random];
      case WeatherCategory.good:
        return goodMessages[random];
      case WeatherCategory.ok:
        return okMessages[random];
      case WeatherCategory.bad:
        return badMessages[random];
      case WeatherCategory.dangerous:
        return dangerousMessages[random];
    }
  }

  /// Convert wind direction degrees to compass direction
  String getWindDirectionText() {
    if (windDirection >= 337.5 || windDirection < 22.5) return 'N';
    if (windDirection >= 22.5 && windDirection < 67.5) return 'NE';
    if (windDirection >= 67.5 && windDirection < 112.5) return 'E';
    if (windDirection >= 112.5 && windDirection < 157.5) return 'SE';
    if (windDirection >= 157.5 && windDirection < 202.5) return 'S';
    if (windDirection >= 202.5 && windDirection < 247.5) return 'SW';
    if (windDirection >= 247.5 && windDirection < 292.5) return 'W';
    if (windDirection >= 292.5 && windDirection < 337.5) return 'NW';
    return 'N'; // Default fallback
  }

  /// Convert visibility from km to more user-friendly description
  String getVisibilityText() {
    if (visibility >= 10) return 'Excellent (${(visibility * 0.621371).toStringAsFixed(1)} mi)';
    if (visibility >= 5)  return 'Good (${(visibility * 0.621371).toStringAsFixed(1)} mi)';
    if (visibility >= 2)  return 'Moderate (${(visibility * 0.621371).toStringAsFixed(1)} mi)';
    if (visibility >= 1)  return 'Poor (${(visibility * 0.621371).toStringAsFixed(1)} mi)';
    return 'Very Poor (${(visibility * 0.621371).toStringAsFixed(1)} mi)';
  }

  /// Get detailed condition description
  String getConditionDetails() {
    final List<String> details = [];

    if (temperature < 0) {
      details.add('Freezing temperature (${temperature.toStringAsFixed(1)}°C)');
    } else if (temperature > 35) {
      details.add('Very hot (${temperature.toStringAsFixed(1)}°C)');
    }

    if (windSpeed > WeatherThresholds.okWindMax) {
      details.add('Strong winds (${windSpeed.toStringAsFixed(1)} km/h)');
    }

    if (precipitation > WeatherThresholds.lightRain) {
      details.add('Rain (${precipitation.toStringAsFixed(1)} mm/h)');
    }

    if (visibility < WeatherThresholds.goodVisibility) {
      details.add('Poor visibility (${visibility.toStringAsFixed(1)} km)');
    }

    return details.join(', ');
  }
}
