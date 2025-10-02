import 'dart:async';

import 'package:geolocator/geolocator.dart';
import '../models/weather_category.dart';
import '../shared/utils/enhanced_http_client.dart';
import '../shared/utils/network_cache.dart';
import '../shared/utils/enhanced_memory_manager.dart';
import '../shared/utils/logging_utils.dart';
import '../shared/permission_coordinator.dart';
import '../shared/mixins/service_access_mixin.dart';

/// Optimized weather service with advanced caching and performance features
class OptimizedWeatherService with EnhancedServiceResourceMixin, ServiceAccessMixin {
  static final OptimizedWeatherService _instance =
      OptimizedWeatherService._internal();
  factory OptimizedWeatherService() => _instance;
  OptimizedWeatherService._internal();

  // Configuration
  static const String _baseUrl = 'https://api.open-meteo.com/v1/forecast';
  static const Duration _defaultTimeout = Duration(seconds: 10);
  
  // Location caching constants
  static const String _lastLatitudeKey = 'last_known_latitude';
  static const String _lastLongitudeKey = 'last_known_longitude';
  static const String _lastLocationTimeKey = 'last_location_time';
  static const Duration _locationCacheExpiry = Duration(hours: 6);

  // Singleton instance variables for state management
  bool _isInitialized = false;
  final Map<String, Completer<WeatherData>> _weatherRequests = {};
  final Map<String, Completer<List<WeatherData>>> _forecastRequests = {};

  // Performance tracking
  int _totalRequests = 0;
  int _cacheHits = 0;
  int _networkRequests = 0;
  int _failedRequests = 0;
  DateTime? _lastRequestTime;

  /// Initialize the service
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      LoggingUtils.logDebug('Initializing OptimizedWeatherService');

      // Initialize service resource mixin only if not already initialized
      try {
        initializeService('OptimizedWeatherService');
      } catch (e) {
        // If _serviceId is already initialized, just log and continue
        if (e.toString().contains('has already been initialized')) {
          LoggingUtils.logDebug(
              'Service resource already initialized, continuing...');
        } else {
          rethrow;
        }
      }

      // Preload common endpoints
      await _preloadCommonData();

      _isInitialized = true;
      LoggingUtils.logDebug('OptimizedWeatherService initialized successfully');
    } catch (e) {
      LoggingUtils.logError('Failed to initialize OptimizedWeatherService', e);
      rethrow;
    }
  }

  /// Preload common weather data
  Future<void> _preloadCommonData() async {
    try {
      // Skip preloading for now - location service not available
      LoggingUtils.logDebug('Skipping weather data preloading');
    } catch (e) {
      LoggingUtils.logDebug('Could not preload weather data: $e');
    }
  }

  /// Get current weather data
  Future<WeatherData> getCurrentWeather({
    double? latitude,
    double? longitude,
    String? cityName,
    bool forceRefresh = false,
  }) async {
    await _ensureInitialized();

    _totalRequests++;
    _lastRequestTime = DateTime.now();

    try {
      // Determine location
      final coords = await _resolveLocation(latitude, longitude, cityName);
      final cacheKey = _buildWeatherCacheKey(coords.latitude, coords.longitude);

      // Check for existing request
      if (_weatherRequests.containsKey(cacheKey)) {
        LoggingUtils.logDebug(
            'Waiting for existing weather request: $cacheKey');
        return await _weatherRequests[cacheKey]!.future;
      }

      // Create new request completer
      final completer = Completer<WeatherData>();
      _weatherRequests[cacheKey] = completer;

      try {
        // Check cache first (unless force refresh)
        if (!forceRefresh) {
          final url = _buildWeatherUrl(coords.latitude, coords.longitude);
          final cachedData = await NetworkCache.getCachedData(url);
          if (cachedData != null) {
            _cacheHits++;
            final weatherData = _parseCurrentWeatherData(cachedData);
            completer.complete(weatherData);
            return weatherData;
          }
        }

        // Make network request
        _networkRequests++;
        final url = _buildWeatherUrl(coords.latitude, coords.longitude);

        final jsonData = await EnhancedHttpClient.get(
          url,
          timeout: _defaultTimeout,
        );

        final weatherData = _parseCurrentWeatherData(jsonData);

        // Cache the result
        await NetworkCache.setCachedData(url, jsonData);

        completer.complete(weatherData);
        return weatherData;
      } catch (e) {
        _failedRequests++;
        completer.completeError(e);
        rethrow;
      } finally {
        _weatherRequests.remove(cacheKey);
      }
    } catch (e) {
      LoggingUtils.logError('Failed to get current weather', e);
      rethrow;
    }
  }

  /// Get weather forecast
  Future<List<WeatherData>> getWeatherForecast({
    double? latitude,
    double? longitude,
    String? cityName,
    int days = 5,
    bool forceRefresh = false,
  }) async {
    await _ensureInitialized();

    _totalRequests++;
    _lastRequestTime = DateTime.now();

    try {
      // Determine location
      final coords = await _resolveLocation(latitude, longitude, cityName);
      final cacheKey =
          _buildForecastCacheKey(coords.latitude, coords.longitude, days);

      // Check for existing request
      if (_forecastRequests.containsKey(cacheKey)) {
        LoggingUtils.logDebug(
            'Waiting for existing forecast request: $cacheKey');
        return await _forecastRequests[cacheKey]!.future;
      }

      // Create new request completer
      final completer = Completer<List<WeatherData>>();
      _forecastRequests[cacheKey] = completer;

      try {
        // Check cache first (unless force refresh)
        final url = _buildForecastUrl(coords.latitude, coords.longitude, days);
        if (!forceRefresh) {
          final cachedData = await NetworkCache.getCachedData(url);
          if (cachedData != null) {
            _cacheHits++;
            final forecastData = _parseForecastData(cachedData);
            completer.complete(forecastData);
            return forecastData;
          }
        }

        // Make network request
        _networkRequests++;

        final jsonData = await EnhancedHttpClient.get(
          url,
          timeout: _defaultTimeout,
        );

        final forecastData = _parseForecastData(jsonData);

        // Cache the result
        await NetworkCache.setCachedData(url, jsonData);

        completer.complete(forecastData);
        return forecastData;
      } catch (e) {
        _failedRequests++;
        completer.completeError(e);
        rethrow;
      } finally {
        _forecastRequests.remove(cacheKey);
      }
    } catch (e) {
      LoggingUtils.logError('Failed to get weather forecast', e);
      rethrow;
    }
  }

  /// Get hourly forecast
  Future<List<WeatherData>> getHourlyForecast({
    double? latitude,
    double? longitude,
    String? cityName,
    int hours = 24,
    bool forceRefresh = false,
  }) async {
    // For now, use the regular forecast and limit to requested hours
    final forecast = await getWeatherForecast(
      latitude: latitude,
      longitude: longitude,
      cityName: cityName,
      days: (hours / 24).ceil(),
      forceRefresh: forceRefresh,
    );

    return forecast.take(hours).toList();
  }

  /// Get weather for multiple locations
  Future<List<WeatherData>> getMultipleWeather(
      List<({double latitude, double longitude})> locations) async {
    await _ensureInitialized();

    final futures = locations
        .map((location) => getCurrentWeather(
              latitude: location.latitude,
              longitude: location.longitude,
            ).catchError((e) {
              LoggingUtils.logWarning(
                  'Failed to get weather for ${location.latitude},${location.longitude}: $e');
              // Return a default WeatherData object or rethrow
              throw e;
            }))
        .toList();

    final results = await Future.wait(futures);
    return results.whereType<WeatherData>().toList();
  }

  /// Helper methods

  Future<({double latitude, double longitude})> _resolveLocation(
    double? latitude,
    double? longitude,
    String? cityName,
  ) async {
    if (latitude != null && longitude != null) {
      return (latitude: latitude, longitude: longitude);
    }

    if (cityName != null) {
      // For now, return default coordinates
      // In a real app, you'd use a geocoding service
      return (latitude: 40.7128, longitude: -74.0060); // New York
    }

    // Get user's actual location
    final position = await _getCurrentPosition();
    if (position != null) {
      return (latitude: position.latitude, longitude: position.longitude);
    }

    // Fallback to default location only if location services fail
    LoggingUtils.logWarning('Using fallback location (New York) - location services unavailable');
    return (latitude: 40.7128, longitude: -74.0060); // New York
  }

  /// Get current position with proper error handling and caching
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
      
      await prefsService.setDouble(_lastLatitudeKey, position.latitude);
      await prefsService.setDouble(_lastLongitudeKey, position.longitude);
      await prefsService.setInt(_lastLocationTimeKey, timestamp);
      
      LoggingUtils.logDebug('Location cached: ${position.latitude}, ${position.longitude}');
    } catch (e) {
      LoggingUtils.logError('Failed to cache location', e);
    }
  }
  
  /// Get cached location if available and not expired
  Future<Position?> _getCachedLocation() async {
    try {
      final prefsService = preferencesService;
      
      final latitude = await prefsService.getDouble(_lastLatitudeKey);
      final longitude = await prefsService.getDouble(_lastLongitudeKey);
      final timestamp = await prefsService.getInt(_lastLocationTimeKey);
      
      if (latitude == null || longitude == null || timestamp == null) {
        LoggingUtils.logDebug('No cached location available');
        return null;
      }
      
      // Check if cached location is still valid
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
        accuracy: 0,
        altitude: 0,
        altitudeAccuracy: 0,
        heading: 0,
        headingAccuracy: 0,
        speed: 0,
        speedAccuracy: 0,
      );
    } catch (e) {
      LoggingUtils.logError('Failed to get cached location', e);
      return null;
    }
  }

  String _buildWeatherCacheKey(double latitude, double longitude) {
    return 'weather_${latitude.toStringAsFixed(4)}_${longitude.toStringAsFixed(4)}';
  }

  String _buildForecastCacheKey(double latitude, double longitude, int days) {
    return 'forecast_${latitude.toStringAsFixed(4)}_${longitude.toStringAsFixed(4)}_${days}d';
  }

  String _buildWeatherUrl(double latitude, double longitude) {
    return '$_baseUrl?latitude=$latitude&longitude=$longitude&current=temperature_2m,relative_humidity_2m,precipitation,weather_code,wind_speed_10m,wind_direction_10m,precipitation_probability,visibility&timezone=auto';
  }

  String _buildForecastUrl(double latitude, double longitude, int days) {
    // Use start_date and end_date instead of forecast_days to ensure we get current and future data
    final now = DateTime.now();
    final startDate = now.toIso8601String().split('T')[0];
    final endDate = now.add(Duration(days: days)).toIso8601String().split('T')[0];
    return '$_baseUrl?latitude=$latitude&longitude=$longitude&hourly=temperature_2m,precipitation,weather_code,wind_speed_10m,visibility&timezone=auto&start_date=$startDate&end_date=$endDate';
  }

  WeatherData _parseCurrentWeatherData(Map<String, dynamic> jsonData) {
    try {
      final current = jsonData['current'];

      return WeatherData(
        temperature: current['temperature_2m']?.toDouble() ?? 0.0,
        windSpeed: current['wind_speed_10m']?.toDouble() ?? 0.0,
        windDirection: current['wind_direction_10m']?.toDouble() ?? 0.0,
        precipitation: current['precipitation']?.toDouble() ?? 0.0,
        precipitationProbability:
            current['precipitation_probability']?.toDouble() ?? 0.0,
        visibility: current['visibility']?.toDouble() ?? 10.0,
        humidity: current['relative_humidity_2m']?.toDouble() ?? 50.0,
        weatherCode: current['weather_code']?.toString() ?? '0',
        timestamp: DateTime.now(),
      );
    } catch (e) {
      LoggingUtils.logError('Error parsing current weather data', e);
      // Return default weather data
      return WeatherData(
        temperature: 0.0,
        windSpeed: 0.0,
        windDirection: 0.0,
        precipitation: 0.0,
        precipitationProbability: 0.0,
        visibility: 10.0,
        humidity: 50.0,
        weatherCode: '0',
        timestamp: DateTime.now(),
      );
    }
  }

  List<WeatherData> _parseForecastData(Map<String, dynamic> jsonData) {
    try {
      final hourly = jsonData['hourly'];
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
      
      LoggingUtils.logDebug('Parsing forecast data: ${times.length} hours available');
      LoggingUtils.logDebug('Current time: $now');
      if (times.isNotEmpty) {
        LoggingUtils.logDebug('First forecast time: ${times.first}');
        LoggingUtils.logDebug('Last forecast time: ${times.last}');
      }

      for (int i = 0; i < times.length; i++) {
        final time = DateTime.parse(times[i]);

        // Only include future hours
        if (time.isAfter(now)) {
          forecast.add(WeatherData(
            temperature: temperatures[i].toDouble(),
            windSpeed: windSpeeds[i].toDouble(),
            windDirection: 0.0, // Not available in hourly data
            precipitation: precipitations[i].toDouble(),
            precipitationProbability: 0.0, // Not available in hourly data
            visibility: visibilities[i].toDouble(),
            humidity: 50.0, // Not available in hourly data
            weatherCode: weatherCodes[i].toString(),
            timestamp: time,
          ));
        }
      }
      
      LoggingUtils.logDebug('Filtered forecast: ${forecast.length} future hours');
      return forecast;
    } catch (e) {
      LoggingUtils.logError('Error parsing hourly weather data', e);
      return [];
    }
  }

  /// Ensure service is initialized
  Future<void> _ensureInitialized() async {
    if (!_isInitialized) {
      await initialize();
    }
  }

  /// Warm up connections for better performance
  Future<void> warmUpConnections() async {
    await _ensureInitialized();

    try {
      // Pre-warm connections by making test requests
      // Note: EnhancedHttpClient doesn't have warmUpConnections method
      LoggingUtils.logDebug('Weather service connections ready');
    } catch (e) {
      LoggingUtils.logWarning('Failed to warm up connections: $e');
    }
  }

  /// Clear all cached data
  Future<void> clearCache() async {
    await NetworkCache.clearCache();
    await EnhancedHttpClient.clearAll();
    LoggingUtils.logDebug('Weather service cache cleared');
  }

  /// Get service performance statistics
  Map<String, dynamic> getPerformanceStatistics() {
    final httpStats = EnhancedHttpClient.getStats();

    return {
      'service': {
        'total_requests': _totalRequests,
        'cache_hits': _cacheHits,
        'network_requests': _networkRequests,
        'failed_requests': _failedRequests,
        'cache_hit_rate': _totalRequests > 0
            ? '${(_cacheHits / _totalRequests * 100).toStringAsFixed(1)}%'
            : '0%',
        'last_request': _lastRequestTime?.toIso8601String(),
        'active_weather_requests': _weatherRequests.length,
        'active_forecast_requests': _forecastRequests.length,
      },
      'http_client': httpStats,
    };
  }

  /// Get cache information
  Map<String, dynamic> getCacheInfo() {
    return {
      'cache_enabled': true,
      'cache_type': 'NetworkCache',
    };
  }

  /// Preload weather data for specific locations
  Future<void> preloadWeatherData(
      List<({double latitude, double longitude})> locations) async {
    await _ensureInitialized();

    final futures = locations.map((location) async {
      try {
        await getCurrentWeather(
          latitude: location.latitude,
          longitude: location.longitude,
        );
      } catch (e) {
        LoggingUtils.logDebug(
            'Failed to preload weather for ${location.latitude},${location.longitude}: $e');
      }
    });

    await Future.wait(futures);
    LoggingUtils.logDebug(
        'Preloaded weather data for ${locations.length} locations');
  }

  /// Handle memory pressure
  void handleMemoryPressure() {
    // Clear pending requests
    _weatherRequests.clear();
    _forecastRequests.clear();

    LoggingUtils.logDebug('Weather service handled memory pressure');
  }

  /// Dispose the service
  Future<void> dispose() async {
    LoggingUtils.logDebug('Disposing OptimizedWeatherService');

    // Cancel pending requests
    for (final completer in _weatherRequests.values) {
      if (!completer.isCompleted) {
        completer.completeError(Exception('Service disposed'));
      }
    }
    _weatherRequests.clear();

    for (final completer in _forecastRequests.values) {
      if (!completer.isCompleted) {
        completer.completeError(Exception('Service disposed'));
      }
    }
    _forecastRequests.clear();

    // Dispose dependencies
    // Note: EnhancedHttpClient and NetworkCache are static classes - no disposal needed

    _isInitialized = false;

    // Call mixin dispose
    disposeResources();

    LoggingUtils.logDebug('OptimizedWeatherService disposed');
  }
}
