import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../../models/weather_category.dart';
import '../../services/weather_service.dart';
import '../utils/image_optimization.dart';

// WeatherData is imported from weather_category.dart

/// Advanced performance optimizations with RepaintBoundary and ValueListenableBuilder
class AdvancedOptimizedWidgets {
  /// Creates a RepaintBoundary wrapper for expensive widgets
  static Widget withRepaintBoundary(Widget child, {String? debugLabel}) {
    return RepaintBoundary(
      child: child,
    );
  }

  /// Creates a ValueListenableBuilder for targeted rebuilds
  static Widget valueListenableBuilder<T>({
    required ValueListenable<T> valueListenable,
    required Widget Function(BuildContext, T, Widget?) builder,
    Widget? child,
  }) {
    return ValueListenableBuilder<T>(
      valueListenable: valueListenable,
      builder: builder,
      child: child,
    );
  }
}

/// Optimized weather card widget that minimizes rebuilds
class OptimizedWeatherCard extends StatelessWidget {
  const OptimizedWeatherCard({
    super.key,
    required this.currentWeather,
    required this.forecastData,
    required this.lastUpdate,
    required this.onRetry,
  });

  final WeatherData currentWeather;
  final List<WeatherData> forecastData;
  final DateTime? lastUpdate;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    // Wrap the entire card in RepaintBoundary to isolate repaints
    return AdvancedOptimizedWidgets.withRepaintBoundary(
      _buildCardContent(context),
      debugLabel: 'WeatherCard',
    );
  }

  Widget _buildCardContent(BuildContext context) {
    // Pre-calculate expensive operations outside of build
    final category = forecastData.isNotEmpty
        ? WeatherData.categorizeWithForecast(currentWeather, forecastData)
        : currentWeather.categorize();
    final recommendation = _getRecommendationForCategory(category);
    final weatherDescription =
        WeatherService.getWeatherDescription(currentWeather.weatherCode);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            // Weather Category Badge
            AdvancedOptimizedWidgets.withRepaintBoundary(
              OptimizedWeatherCategoryBadge(category: category),
              debugLabel: 'CategoryBadge',
            ),
            const SizedBox(height: 16),

            // Temperature and Weather Description
            AdvancedOptimizedWidgets.withRepaintBoundary(
              OptimizedTemperatureRow(
                temperature: currentWeather.temperature,
                description: weatherDescription,
              ),
              debugLabel: 'TemperatureRow',
            ),
            const SizedBox(height: 16),

            // Recommendation
            OptimizedRecommendationCard(
              recommendation: recommendation,
              hasForecast: forecastData.isNotEmpty,
            ),
            const SizedBox(height: 16),

            // Weather Details
            OptimizedWeatherDetails(weather: currentWeather),

            if (lastUpdate != null) ...[
              const SizedBox(height: 16),
              AdvancedOptimizedWidgets.withRepaintBoundary(
                OptimizedLastUpdateText(lastUpdate: lastUpdate!),
                debugLabel: 'LastUpdate',
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _getRecommendationForCategory(WeatherCategory category) {
    final random =
        DateTime.now().millisecondsSinceEpoch % 5; // Simple randomization

    switch (category) {
      case WeatherCategory.perfect:
        return WeatherData.perfectMessages[random];
      case WeatherCategory.good:
        return WeatherData.goodMessages[random];
      case WeatherCategory.ok:
        return WeatherData.okMessages[random];
      case WeatherCategory.bad:
        return WeatherData.badMessages[random];
      case WeatherCategory.dangerous:
        return WeatherData.dangerousMessages[random];
    }
  }
}

/// Optimized weather category badge with const constructor
class OptimizedWeatherCategoryBadge extends StatelessWidget {
  const OptimizedWeatherCategoryBadge({
    super.key,
    required this.category,
  });

  final WeatherCategory category;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
      decoration: BoxDecoration(
        color: Color(category.colorValue),
        borderRadius: BorderRadius.circular(25),
      ),
      child: Text(
        category.title,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 20,
        ),
      ),
    );
  }
}

/// Optimized temperature row widget
class OptimizedTemperatureRow extends StatelessWidget {
  const OptimizedTemperatureRow({
    super.key,
    required this.temperature,
    required this.description,
  });

  final double temperature;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          '${temperature.toStringAsFixed(1)}°C',
          style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(width: 16),
        Flexible(
          child: Text(
            description,
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
      ],
    );
  }
}

/// Optimized recommendation card widget
class OptimizedRecommendationCard extends StatelessWidget {
  const OptimizedRecommendationCard({
    super.key,
    required this.recommendation,
    required this.hasForecast,
  });

  final String recommendation;
  final bool hasForecast;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(
            recommendation,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
            textAlign: TextAlign.center,
          ),
          if (hasForecast) ...[
            const SizedBox(height: 8),
            Text(
              'Based on current weather + next 8 hours forecast',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontStyle: FontStyle.italic,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }
}

/// Optimized weather details widget
class OptimizedWeatherDetails extends StatelessWidget {
  const OptimizedWeatherDetails({
    super.key,
    required this.weather,
  });

  final WeatherData weather;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: OptimizedWeatherDetailItem(
                icon: ImageOptimization.getIcon('wind'),
                label: 'Wind',
                value:
                    '${weather.windSpeed.toStringAsFixed(1)} km/h ${weather.getWindDirectionText()}',
              ),
            ),
            Expanded(
              child: OptimizedWeatherDetailItem(
                icon: ImageOptimization.getIcon('humidity'),
                label: 'Rain Chance',
                value:
                    '${weather.precipitationProbability.toStringAsFixed(0)}%',
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: OptimizedWeatherDetailItem(
                icon: ImageOptimization.getIcon('visibility'),
                label: 'Visibility',
                value: weather.getVisibilityText(),
              ),
            ),
            Expanded(
              child: OptimizedWeatherDetailItem(
                icon: ImageOptimization.getIcon('precipitation'),
                label: 'Humidity',
                value: '${weather.humidity.toStringAsFixed(0)}%',
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Optimized weather detail item widget
class OptimizedWeatherDetailItem extends StatelessWidget {
  const OptimizedWeatherDetailItem({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon,
            size: 20, color: Theme.of(context).colorScheme.onSurfaceVariant),
        const SizedBox(height: 4),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall,
        ),
        Text(
          value,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w500,
              ),
        ),
      ],
    );
  }
}

/// Optimized last update text widget
class OptimizedLastUpdateText extends StatelessWidget {
  const OptimizedLastUpdateText({
    super.key,
    required this.lastUpdate,
  });

  final DateTime lastUpdate;

  @override
  Widget build(BuildContext context) {
    return Text(
      'Last updated: ${_formatTime(lastUpdate)}',
      style: Theme.of(context).textTheme.bodySmall,
    );
  }

  String _formatTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes} minute${difference.inMinutes == 1 ? '' : 's'} ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours} hour${difference.inHours == 1 ? '' : 's'} ago';
    } else {
      return '${dateTime.day}/${dateTime.month} ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
    }
  }
}

/// Optimized forecast card widget with RepaintBoundary and efficient list building
class OptimizedForecastCard extends StatelessWidget {
  const OptimizedForecastCard({
    super.key,
    required this.forecastData,
  });

  final List<WeatherData> forecastData;

  @override
  Widget build(BuildContext context) {
    if (forecastData.isEmpty) {
      return const SizedBox.shrink();
    }

    return AdvancedOptimizedWidgets.withRepaintBoundary(
      Card(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '24-Hour Forecast',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 120,
                child: OptimizedForecastList(forecastData: forecastData),
              ),
              const SizedBox(height: 8),
              Text(
                'Next 8 hours (highlighted) are used for ride/drive recommendations',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontStyle: FontStyle.italic,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
            ],
          ),
        ),
      ),
      debugLabel: 'ForecastCard',
    );
  }
}

/// Optimized forecast list with AutomaticKeepAliveClientMixin for performance
class OptimizedForecastList extends StatefulWidget {
  const OptimizedForecastList({
    super.key,
    required this.forecastData,
  });

  final List<WeatherData> forecastData;

  @override
  State<OptimizedForecastList> createState() => _OptimizedForecastListState();
}

class _OptimizedForecastListState extends State<OptimizedForecastList>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive =>
      true; // Keep the list alive to preserve scroll position

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for AutomaticKeepAliveClientMixin

    return ListView.builder(
      scrollDirection: Axis.horizontal,
      itemCount: widget.forecastData.length,
      // Use itemExtent for better performance
      itemExtent: 92, // 80 width + 12 margin
      itemBuilder: (context, index) {
        // Wrap each item in RepaintBoundary for isolated repaints
        return AdvancedOptimizedWidgets.withRepaintBoundary(
          OptimizedForecastItem(
            forecast: widget.forecastData[index],
            hourIndex: index + 1,
            isNext8Hours: index < 8,
          ),
          debugLabel: 'ForecastItem_$index',
        );
      },
    );
  }
}

/// Optimized forecast item widget
class OptimizedForecastItem extends StatelessWidget {
  const OptimizedForecastItem({
    super.key,
    required this.forecast,
    required this.hourIndex,
    required this.isNext8Hours,
  });

  final WeatherData forecast;
  final int hourIndex;
  final bool isNext8Hours;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final hour = now.add(Duration(hours: hourIndex));
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      width: 80,
      margin: const EdgeInsets.only(right: 12),
      child: Column(
        children: [
          Text(
            '${hour.hour.toString().padLeft(2, '0')}:00',
            style: textTheme.bodySmall?.copyWith(
              fontWeight: isNext8Hours ? FontWeight.bold : FontWeight.normal,
              color: isNext8Hours
                  ? colorScheme.primary
                  : colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: isNext8Hours
                  ? colorScheme.primaryContainer
                  : colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '${forecast.temperature.toStringAsFixed(0)}°',
              style: textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w500,
                color: isNext8Hours
                    ? colorScheme.onPrimaryContainer
                    : colorScheme.onSurface,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                ImageOptimization.getIcon('humidity'),
                size: 10,
                color: colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 2),
              Text(
                '${forecast.precipitationProbability.toStringAsFixed(0)}%',
                style: textTheme.bodySmall,
              ),
            ],
          ),
          const SizedBox(height: 2),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                ImageOptimization.getIcon('wind'),
                size: 10,
                color: colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 2),
              Text(
                '${forecast.windSpeed.toStringAsFixed(0)} km/h ${forecast.getWindDirectionText()}',
                style: textTheme.bodySmall,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Optimized settings card widget
class OptimizedSettingsCard extends StatelessWidget {
  const OptimizedSettingsCard({
    super.key,
    required this.title,
    required this.children,
  });

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),
            ...children,
          ],
        ),
      ),
    );
  }
}

/// Optimized switch tile widget
class OptimizedSwitchTile extends StatelessWidget {
  const OptimizedSwitchTile({
    super.key,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      title: Text(title),
      subtitle: Text(subtitle),
      value: value,
      onChanged: onChanged,
      contentPadding: EdgeInsets.zero,
    );
  }
}
