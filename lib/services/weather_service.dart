import 'package:geolocator/geolocator.dart';
import '../models/weather_category.dart';
import '../shared/utils/logging_utils.dart';
import '../shared/utils/error_handler.dart';
import '../shared/utils/async_utils.dart';
import '../shared/utils/enhanced_http_client.dart';
import '../shared/permission_coordinator.dart';
import '../shared/mixins/service_access_mixin.dart';

/// Service for fetching weather data from Open-Meteo API
class WeatherService with ServiceAccessMixin, ErrorHandlingMixin, AsyncOptimizationMixin {
  static const String _baseUrl = 'https://api.open-meteo.com/v1/forecast';
  
  // Location caching constants
  static const String _lastLatitudeKey = 'last_known_latitude';
  static const String _lastLongitudeKey = 'last_known_longitude';
  static const String _lastLocationTimeKey = 'last_location_time';
  static const Duration _locationCacheExpiry = Duration(hours: 6); // Cache location for 6 hours

  // Singleton pattern
  static final WeatherService _instance = WeatherService._internal();
  factory WeatherService() => _instance;
  WeatherService._internal();

  /// Get current weather data with enhanced background support
  Future<WeatherData?> getCurrentWeather() async {
    return await handleAsync<WeatherData>(
      operation: () async {
         final position = await _getCurrentPosition();
         if (position == null) {
           LoggingUtils.logError('Failed to get location for weather data', null);
           throw Exception('Failed to get location for weather data');
         }

         LoggingUtils.logDebug('Location obtained: ${position.latitude}, ${position.longitude}');
         
         final result = await executeWithRetry<WeatherData>(
           operation: () async {
             // Fetch weather data from Open-Meteo
             final weatherData = await _fetchWeatherData(
               position.latitude,
               position.longitude,
             );
             
             if (weatherData == null) {
               throw Exception('Failed to parse weather data');
             }
             
             LoggingUtils.logDebug('Weather data fetched successfully');
             return weatherData;
           },
           operationName: 'getCurrentWeather',
           maxRetries: 3,
           initialDelay: const Duration(seconds: 2),
           backoffMultiplier: 2.0,
           timeout: const Duration(seconds: 10),
         );
         
         if (result == null) {
           throw Exception('Failed to fetch weather data after retries');
         }
         
         return result;
      },
      operationName: 'getCurrentWeather',
    );
  }

  /// Get weather forecast for the next few hours
  Future<List<WeatherData>> getHourlyForecast({int hours = 24}) async {
    final result = await handleAsync<List<WeatherData>>(
      operation: () async {
        final position = await _getCurrentPosition();
        if (position == null) {
          LoggingUtils.logError('Failed to get location for forecast data', null);
          return <WeatherData>[];
        }

        return await executeWithRetry<List<WeatherData>>(
          operation: () async {
            final forecastData = await _fetchHourlyForecast(
              position.latitude,
              position.longitude,
              hours,
            );
            return forecastData;
          },
          operationName: 'getHourlyForecast',
          maxRetries: 3,
          initialDelay: const Duration(seconds: 2),
          backoffMultiplier: 2.0,
          timeout: const Duration(seconds: 15),
        ) ?? <WeatherData>[];
      },
      operationName: 'getHourlyForecast',
    );
    return result ?? <WeatherData>[];
  }

  /// Get current position with permission handling, retry logic, and caching
  Future<Position?> _getCurrentPosition() async {
    try {
      final coordinator = PermissionCoordinator();
      
      // Request location permissions through the coordinator
      final permission = await coordinator.requestLocationPermissions();
      
      if (permission == LocationPermission.denied) {
        LoggingUtils.logWarning('Location permissions are denied');
        return await _getCachedLocation();
      }
      
      if (permission == LocationPermission.deniedForever) {
        LoggingUtils.logWarning('Location permissions are permanently denied');
        return await _getCachedLocation();
      }

      // Try to get fresh location with shorter timeout for background scenarios
      try {
        final position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.medium,
          timeLimit: const Duration(seconds: 5), // Shorter timeout for background
        );
        LoggingUtils.logDebug('Fresh location obtained successfully');
        await _cacheLocation(position);
        return position;
      } catch (e) {
        LoggingUtils.logWarning('Fresh location failed: $e');
        
        // Try last known position from Geolocator
        try {
          final lastKnown = await Geolocator.getLastKnownPosition();
          if (lastKnown != null) {
            LoggingUtils.logDebug('Using last known position from Geolocator');
            await _cacheLocation(lastKnown);
            return lastKnown;
          }
        } catch (lastKnownError) {
          LoggingUtils.logWarning('Last known position failed: $lastKnownError');
        }
        
        // Fall back to cached location
        final cachedLocation = await _getCachedLocation();
        if (cachedLocation != null) {
          LoggingUtils.logDebug('Using cached location as fallback');
          return cachedLocation;
        }
        
        LoggingUtils.logError('All location attempts failed', e);
        return null;
      }
    } catch (e) {
      LoggingUtils.logError('Error in _getCurrentPosition', e);
      return await _getCachedLocation();
    }
  }
  
  /// Cache the current location for future use
  Future<void> _cacheLocation(Position position) async {
    try {
      final prefsService = preferencesService;
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      
      // Batch all preference writes for better performance
      await executeParallel<void>(
        operations: [
          () => prefsService.setDouble(_lastLatitudeKey, position.latitude),
          () => prefsService.setDouble(_lastLongitudeKey, position.longitude),
          () => prefsService.setInt(_lastLocationTimeKey, timestamp),
        ],
        timeout: const Duration(seconds: 5),
        operationName: 'cacheLocationData',
      );
      
      LoggingUtils.logDebug('Location cached: ${position.latitude}, ${position.longitude}');
    } catch (e) {
      LoggingUtils.logError('Failed to cache location', e);
    }
  }
  
  /// Get cached location if available and not expired
  Future<Position?> _getCachedLocation() async {
    try {
      final prefsService = preferencesService;
      
      // Parallelize preference reads for better performance
      final results = await executeParallel<dynamic>(
        operations: [
          () => prefsService.getDouble(_lastLatitudeKey),
          () => prefsService.getDouble(_lastLongitudeKey),
          () => prefsService.getInt(_lastLocationTimeKey),
        ],
        timeout: const Duration(seconds: 5),
        operationName: 'getCachedLocationData',
      );
      
      final latitude = results[0] as double?;
      final longitude = results[1] as double?;
      final timestamp = results[2] as int?;
      
      if (latitude == null || longitude == null || timestamp == null) {
        LoggingUtils.logDebug('No cached location available');
        return null;
      }
      
      final cacheTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
      final now = DateTime.now();
      
      if (now.difference(cacheTime) > _locationCacheExpiry) {
        LoggingUtils.logDebug('Cached location expired');
        return null;
      }
      
      LoggingUtils.logDebug('Using cached location: $latitude, $longitude');
      return Position(
        latitude: latitude,
        longitude: longitude,
        timestamp: cacheTime,
        accuracy: 100.0, // Assume moderate accuracy for cached location
        altitude: 0.0,
        altitudeAccuracy: 0.0,
        heading: 0.0,
        headingAccuracy: 0.0,
        speed: 0.0,
        speedAccuracy: 0.0,
      );
    } catch (e) {
      LoggingUtils.logError('Failed to get cached location', e);
      return null;
    }
  }

  /// Fetch current weather data from Open-Meteo API
  Future<WeatherData?> _fetchWeatherData(double lat, double lon) async {
    final queryParams = {
      'latitude': lat.toString(),
      'longitude': lon.toString(),
      'current': 'temperature_2m,relative_humidity_2m,precipitation,weather_code,wind_speed_10m,wind_direction_10m,precipitation_probability,visibility',
      'timezone': 'auto',
    };

    try {
      final data = await EnhancedHttpClient.get(
        _baseUrl,
        queryParams: queryParams,
        useCache: true,
        allowOffline: true,
      );
      
      return _parseCurrentWeatherData(data);
    } catch (e) {
      LoggingUtils.logError('Failed to fetch weather data', e);
      throw Exception('Failed to load weather data: $e');
    }
  }

  /// Fetch hourly forecast data from Open-Meteo API
  Future<List<WeatherData>> _fetchHourlyForecast(
    double lat,
    double lon,
    int hours,
  ) async {
    final queryParams = {
      'latitude': lat.toString(),
      'longitude': lon.toString(),
      'hourly': 'temperature_2m,precipitation,weather_code,wind_speed_10m,visibility',
      'timezone': 'auto',
      'forecast_days': '2',
    };

    try {
      final data = await EnhancedHttpClient.get(
        _baseUrl,
        queryParams: queryParams,
        useCache: true,
        allowOffline: true,
      );
      
      return _parseHourlyWeatherData(data, hours);
    } catch (e) {
      LoggingUtils.logError('Failed to fetch forecast data', e);
      throw Exception('Failed to load forecast data: $e');
    }
  }

  /// Parse current weather data from API response
  WeatherData? _parseCurrentWeatherData(Map<String, dynamic> data) {
    try {
      final current = data['current'];

      return WeatherData(
        temperature: (current['temperature_2m'] as num).toDouble(),
        windSpeed: (current['wind_speed_10m'] as num).toDouble(),
        windDirection:
            (current['wind_direction_10m'] as num?)?.toDouble() ?? 0.0,
        precipitation: (current['precipitation'] as num).toDouble(),
        precipitationProbability:
            (current['precipitation_probability'] as num?)?.toDouble() ?? 0.0,
        visibility: (current['visibility'] as num?)?.toDouble() ??
            10.0, // Default 10km if not available
        humidity: (current['relative_humidity_2m'] as num?)?.toDouble() ??
            50.0, // Default 50% if not available
        weatherCode: current['weather_code'].toString(),
        timestamp: DateTime.parse(current['time']),
      );
    } catch (e) {
      LoggingUtils.logError('Error parsing current weather data', e);
      return null;
    }
  }

  /// Parse hourly forecast data from API response
  List<WeatherData> _parseHourlyWeatherData(
      Map<String, dynamic> data, int hours) {
    try {
      final hourly = data['hourly'];
      final times = List<String>.from(hourly['time']);
      final temperatures = List<num>.from(hourly['temperature_2m']);
      final precipitations = List<num>.from(hourly['precipitation']);
      final weatherCodes = List<num>.from(hourly['weather_code']);
      final windSpeeds = List<num>.from(hourly['wind_speed_10m']);
      final visibilities = hourly['visibility'] != null
          ? List<num>.from(hourly['visibility'])
          : List.filled(times.length, 10.0); // Default visibility

      final List<WeatherData> forecast = [];
      final now = DateTime.now();

      for (int i = 0; i < times.length && forecast.length < hours; i++) {
        final time = DateTime.parse(times[i]);

        // Only include future hours
        if (time.isAfter(now)) {
          forecast.add(WeatherData(
            temperature: temperatures[i].toDouble(),
            windSpeed: windSpeeds[i].toDouble(),
            windDirection:
                0.0, // Hourly wind direction not used in current implementation
            precipitation: precipitations[i].toDouble(),
            precipitationProbability:
                0.0, // Hourly precipitation probability not used in current implementation
            visibility: visibilities[i].toDouble(),
            humidity:
                50.0, // Hourly humidity not used in current implementation
            weatherCode: weatherCodes[i].toString(),
            timestamp: time,
          ));
        }
      }

      return forecast;
    } catch (e) {
      LoggingUtils.logError('Error parsing hourly weather data', e);
      return [];
    }
  }

  /// Get weather description from WMO weather code
  static String getWeatherDescription(String code) {
    final weatherCode = int.tryParse(code) ?? 0;

    switch (weatherCode) {
      case 0:
        return 'Clear sky';
      case 1:
      case 2:
      case 3:
        return 'Partly cloudy';
      case 45:
      case 48:
        return 'Fog';
      case 51:
      case 53:
      case 55:
        return 'Drizzle';
      case 56:
      case 57:
        return 'Freezing drizzle';
      case 61:
      case 63:
      case 65:
        return 'Rain';
      case 66:
      case 67:
        return 'Freezing rain';
      case 71:
      case 73:
      case 75:
        return 'Snow';
      case 77:
        return 'Snow grains';
      case 80:
      case 81:
      case 82:
        return 'Rain showers';
      case 85:
      case 86:
        return 'Snow showers';
      case 95:
        return 'Thunderstorm';
      case 96:
      case 99:
        return 'Thunderstorm with hail';
      default:
        return 'Unknown';
    }
  }
}
