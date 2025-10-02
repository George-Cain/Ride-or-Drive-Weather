import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/weather_provider.dart';
import '../models/weather_category.dart';
import '../shared/widgets/common_widgets.dart';
import '../shared/widgets/optimized_widgets.dart';
import '../shared/utils/image_optimization.dart';
import '../shared/permission_coordinator.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();

    // Register callback to retry weather fetch when location permissions are granted
    final coordinator = PermissionCoordinator();
    coordinator.onLocationPermissionsReady(() {
      if (mounted) {
        final weatherProvider =
            Provider.of<WeatherProvider>(context, listen: false);
        weatherProvider.loadWeatherData();
      }
    });

    // Defer service initialization to after build is complete
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeServices();
    });
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _initializeServices() async {
    if (mounted) {
      final weatherProvider =
          Provider.of<WeatherProvider>(context, listen: false);

      // First attempt
      await weatherProvider.loadWeatherData();

      // If first attempt failed and we have no weather data, try automatic retry
      if (weatherProvider.errorMessage != null &&
          weatherProvider.currentWeather == null &&
          mounted) {
        // Wait a bit before retry
        await Future.delayed(const Duration(seconds: 2));

        if (mounted) {
          await weatherProvider.loadWeatherData();
        }
      }
    }
  }

  Future<void> _onRefresh() async {
    if (mounted) {
      final weatherProvider =
          Provider.of<WeatherProvider>(context, listen: false);
      await weatherProvider.refreshWeatherData();
    }
  }



  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ride or Drive Weather'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const OptimizedIcon('settings'),
            onPressed: () =>
                NavigationUtils.pushScreen(context, const SettingsScreen()),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _onRefresh,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildProviderWeatherCard(),
              const SizedBox(height: 16),
              _buildProviderForecastCard(),
              const SizedBox(height: 16),
              _buildStatusCard(),
            ],
          ),
        ),
      ),
    );
  }

  /// Weather card using Provider Consumer for optimized rebuilds
  Widget _buildProviderWeatherCard() {
    return Consumer<WeatherProvider>(
      builder: (context, weatherProvider, child) {
        if (weatherProvider.isLoading) {
          return CommonWidgets.buildLoadingCard(context,
              message: 'Loading weather data...');
        }

        if (weatherProvider.errorMessage != null) {
          return CommonWidgets.buildErrorCard(
              context, weatherProvider.errorMessage!,
              onRetry: () => weatherProvider.loadWeatherData());
        }

        if (weatherProvider.currentWeather == null) {
          return CommonWidgets.buildErrorCard(
              context, 'No weather data available',
              onRetry: () => weatherProvider.loadWeatherData());
        }

        return OptimizedWeatherCard(
          currentWeather: weatherProvider.currentWeather!,
          forecastData: weatherProvider.forecastData,
          lastUpdate: weatherProvider.lastUpdate,
          onRetry: () => weatherProvider.loadWeatherData(),
        );
      },
    );
  }

  /// Forecast card using Provider Consumer
  Widget _buildProviderForecastCard() {
    return Consumer<WeatherProvider>(
      builder: (context, weatherProvider, child) {
        return OptimizedForecastCard(
            forecastData: weatherProvider.forecastData);
      },
    );
  }



  Widget _buildStatusCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Weather Assessment Guide',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 12),
            Text(
              'The app evaluates weather conditions based on temperature, wind speed, precipitation, and visibility to determine riding safety:',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            _buildWeatherCategoryGuide(WeatherCategory.perfect, '🟢',
                WeatherCategory.perfect.description),
            const SizedBox(height: 8),
            _buildWeatherCategoryGuide(
                WeatherCategory.good, '🟢', WeatherCategory.good.description),
            const SizedBox(height: 8),
            _buildWeatherCategoryGuide(
                WeatherCategory.ok, '🟡', WeatherCategory.ok.description),
            const SizedBox(height: 8),
            _buildWeatherCategoryGuide(
                WeatherCategory.bad, '🟠', WeatherCategory.bad.description),
            const SizedBox(height: 8),
            _buildWeatherCategoryGuide(WeatherCategory.dangerous, '🔴',
                WeatherCategory.dangerous.description),
          ],
        ),
      ),
    );
  }

  Widget _buildWeatherCategoryGuide(
      WeatherCategory category, String emoji, String description) {
    return Row(
      children: [
        Text(
          emoji,
          style: const TextStyle(fontSize: 16),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: Theme.of(context).textTheme.bodyMedium,
              children: [
                TextSpan(
                  text: '${category.title}: ',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Color(category.colorValue),
                  ),
                ),
                TextSpan(
                  text: description,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
