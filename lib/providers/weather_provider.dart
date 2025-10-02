import 'package:flutter/foundation.dart';
import '../models/weather_category.dart';
import '../services/optimized_weather_service.dart';
import '../shared/utils/logging_utils.dart';
import '../shared/utils/error_handler.dart';
import '../shared/mixins/service_access_mixin.dart';

class WeatherProvider extends ChangeNotifier
    with ErrorHandlingMixin, ServiceAccessMixin {
  late final OptimizedWeatherService _weatherService;

  // State variables
  WeatherData? _currentWeather;
  List<WeatherData> _forecastData = [];
  bool _isLoading = false;
  String? _errorMessage;
  DateTime? _lastUpdate;

  bool _hasForecast = false;

  // Getters
  WeatherData? get currentWeather => _currentWeather;
  List<WeatherData> get forecastData => _forecastData;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  DateTime? get lastUpdate => _lastUpdate;

  bool get hasForecast => _hasForecast;

  WeatherProvider() {
    _initializeService();
  }

  void _initializeService() {
    _weatherService = serviceManager.getService<OptimizedWeatherService>();
  }

  Future<void> loadWeatherData({bool forceRefresh = false}) async {
    // If we have cached data and it's not a force refresh, show it immediately
    final hasCachedData = _currentWeather != null && _lastUpdate != null;
    final timeSinceUpdate =
        hasCachedData ? DateTime.now().difference(_lastUpdate!) : null;

    // Skip loading if we have fresh data (unless force refresh)
    if (!forceRefresh && hasCachedData && timeSinceUpdate!.inMinutes < 10) {
      LoggingUtils.logDebug(
          'Using cached weather data (${timeSinceUpdate.inMinutes} minutes old)');
      return;
    }

    // Only show loading state if we don't have cached data to display
    if (!hasCachedData) {
      _setLoading(true);
    }
    _clearError();

    await handleAsync(
      operation: () async {
        // Load current weather and forecast in parallel for better performance
        final results = await Future.wait([
          _weatherService.getCurrentWeather(forceRefresh: forceRefresh),
          _weatherService.getHourlyForecast(
              hours: 24, forceRefresh: forceRefresh),
        ]);

        _currentWeather = results[0] as WeatherData;
        _forecastData = results[1] as List<WeatherData>;
        _lastUpdate = DateTime.now();
        _hasForecast = _forecastData.isNotEmpty;

        LoggingUtils.logDebug('Weather data loaded successfully (parallel)');
        return 'Weather data loaded';
      },
      operationName: 'Load weather data',
      onError: (error) {
        // Only show error if we don't have cached data to fall back on
        if (!hasCachedData) {
          _setError(
              'Failed to load weather data. Please check your internet connection and location permissions.');
        }
        LoggingUtils.logError('Weather loading failed: $error');
      },
    );

    _setLoading(false);
  }

  Future<void> refreshWeatherData() async {
    LoggingUtils.logDebug('Refreshing weather data...');
    await loadWeatherData(forceRefresh: true);
  }

  void _setLoading(bool loading) {
    if (_isLoading != loading) {
      _isLoading = loading;
      notifyListeners();
    }
  }

  void _setError(String error) {
    _errorMessage = error;
    notifyListeners();
  }

  void _clearError() {
    if (_errorMessage != null) {
      _errorMessage = null;
      notifyListeners();
    }
  }

  void clearWeatherData() {
    _currentWeather = null;
    _forecastData = [];
    _lastUpdate = null;
    _hasForecast = false;

    _clearError();
    notifyListeners();
  }

  @override
  void dispose() {
    LoggingUtils.logDebug('WeatherProvider disposed');
    super.dispose();
  }
}
