# Technical Context: Ride or Drive Weather - Motorcycle Weather App

## Technology Stack

### Core Framework
- **Flutter**: 3.6.1+ (Cross-platform UI framework)
- **Dart**: Programming language with null safety
- **Material Design 3**: UI design system with motorcycle weather-focused theming

### Key Dependencies
```yaml
dependencies:
  flutter:
    sdk: flutter
  provider: ^6.1.2                # State management with Provider pattern
  http: ^1.2.2                    # API requests to Open-Meteo
  geolocator: ^10.1.1             # GPS location services
  flutter_local_notifications: ^17.2.3  # Local notifications
  workmanager: ^0.5.2             # Background processing
  shared_preferences: ^2.3.2      # User settings persistence
  timezone: ^0.9.4                # Timezone handling
  cupertino_icons: ^1.0.2         # iOS-style icons

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^2.0.0           # Code quality
```

### Platform Support
- **Android**: API level 21+ (Android 5.0+) with Android Gradle Plugin 8.7.2 and Kotlin 2.1.0 - Required for background services
- **iOS**: iOS 12.0+ - Required for background app refresh
- **Web**: Modern browsers (limited background functionality)
- **macOS**: macOS 10.14+ (desktop notifications supported)

### Code Quality Standards - Advanced Performance Optimization Complete
- **Performance Monitoring**: Enterprise-grade AdvancedPerformanceMonitor with real-time metrics and trend analysis
- **Performance Dashboard**: Interactive dashboard with visualization, recommendations, and alert management
- **Memory Management**: Enhanced memory tracking with leak detection and automated cleanup mechanisms
- **Background Optimization**: Battery-efficient processing with intelligent scheduling and adaptive intervals
- **API Performance**: Advanced HTTP client with smart caching, request deduplication, and performance metrics
- **Utility Consolidation**: ConsolidatedUtils and EnhancedUIUtils reducing code duplication across application
- **Widget Optimization**: Enhanced rebuild patterns with RepaintBoundary and performance-optimized mixins
- **Enterprise Features**: Automated recommendations, severity-based alerts, and comprehensive reporting capabilities
- **Production Ready**: Complete performance optimization suite ready for enterprise deployment with scalable monitoring

## External Services Integration

### Weather API - Enhanced
- **Provider**: Open-Meteo (open-source weather API)
- **Endpoint**: `https://api.open-meteo.com/v1/forecast`
- **Features**: Current weather, hourly forecasts, humidity data, no API key required
- **Data Points**: temperature_2m, relative_humidity_2m, precipitation, weather_code, wind_speed_10m, wind_direction_10m, precipitation_probability, visibility
- **Rate Limiting**: 10,000 requests/day (generous free tier)

### Permission Management - Enhanced with Background Support
- **Component**: PermissionCoordinator singleton class
- **Location**: `lib/shared/permission_coordinator.dart`
- **Purpose**: Sequential permission request management including background location access
- **Dependencies**: permission_handler, flutter_local_notifications, geolocator
- **State Management**: Internal boolean flags for request tracking
- **Architecture**: Callback-based completion with proper error handling
- **Background Permissions**: ACCESS_BACKGROUND_LOCATION for Android 10+ devices
- **Permission Flow**: Basic location → Background location → Service initialization
- **Platform Support**: Android-specific background location handling with iOS compatibility
- **Integration**: Used by NotificationService and WeatherService

### Location Caching & Background Resilience - NEW
- **Cache Duration**: 6-hour expiry for location coordinates
- **Storage**: SharedPreferences via enhanced PreferencesService
- **Cache Keys**: `last_latitude`, `last_longitude`, `last_location_time`
- **Fallback Chain**: GPS (10s timeout) → Last Known Position → Cached Location
- **Retry Logic**: Up to 2 retries with 2-second delays for weather API calls
- **Error Handling**: Comprehensive TimeoutException resolution for background scenarios
- **Performance**: Reduced GPS usage and battery consumption through intelligent caching
- **Platform Compatibility**: Android 10+ background location support with iOS fallback

### Location Services - Enhanced
- **Provider**: Device GPS via geolocator package
- **Permission Management**: Handled through PermissionCoordinator
- **Permissions**: Location access required for weather data
- **Accuracy**: High accuracy for precise weather forecasting
- **Privacy**: Location data not stored, only used for API requests
- **Error Resolution**: Eliminates "Can request only one set of permissions at a time" conflicts

## Development Environment

### Required Tools
- **Flutter SDK**: 3.6.1+
- **Dart SDK**: Included with Flutter
- **Android Studio**: For Android development and emulation
- **Xcode**: For iOS development (macOS only)
- **VS Code**: Alternative IDE with Flutter extensions

### Android Build Configuration
- **Android Gradle Plugin**: 8.7.2 (updated from 8.2.1)
- **Kotlin Version**: 2.1.0 (updated from 1.9.10)
- **Desugar JDK Libraries**: 2.1.4 (updated from 2.0.4)
- **Target SDK**: API 34 (Android 14)
- **Minimum SDK**: API 21 (Android 5.0)

### Build Configuration
- **Android**: Gradle build system with background service permissions
- **iOS**: Xcode build system with background app refresh capabilities
- **Permissions**: Location, notifications, background processing

## Architecture Components

### Service Layer
- **WeatherService**: HTTP client for Open-Meteo API integration
- **NotificationService**: Local notification scheduling and management
- **BackgroundService**: WorkManager integration for continuous monitoring

### Data Models - Enhanced
- **WeatherCategory**: 5-tier safety classification system
- **Weather Data**: Structured API response handling with humidity field integration
- **User Preferences**: Settings persistence via SharedPreferences
- **Data Enhancement**: WeatherData model now includes humidity percentage for motorcycle riding decisions

### Background Processing
- **WorkManager**: Cross-platform background task scheduling
- **Periodic Tasks**: Weather monitoring every 15-30 minutes
- **Battery Optimization**: Minimal processing to preserve device battery

## Code Quality & Testing

### Linting & Standards
- **flutter_lints**: ^2.0.0 with custom rules
- **Code Style**: Dart formatting with 2-space indentation
- **Documentation**: Comprehensive inline documentation
- **Error Handling**: Try-catch blocks with user-friendly error messages

### Testing Strategy
- **Unit Tests**: Service layer logic testing
- **Widget Tests**: UI component testing
- **Integration Tests**: End-to-end weather flow testing
- **API Mocking**: Offline testing capabilities

## Performance Optimizations

### API Efficiency
- **Request Caching**: Avoid redundant weather API calls
- **Batch Processing**: Efficient data retrieval patterns
- **Error Retry**: Exponential backoff for failed requests

### Background Processing
- **Minimal Frequency**: Balance between freshness and battery life
- **Conditional Processing**: Only process when conditions change significantly
- **Platform Optimization**: iOS/Android-specific background handling

### UI Performance
- **Async Loading**: Non-blocking weather data fetching
- **State Management**: Efficient setState() usage
- **Memory Management**: Proper disposal of resources

## Security & Privacy

### Data Protection
- **Location Privacy**: GPS data not stored or transmitted to third parties
- **API Security**: HTTPS-only communication with weather services
- **Local Storage**: Encrypted SharedPreferences for sensitive settings
- **No User Tracking**: No analytics or user behavior tracking

### Permissions
- **Location**: Required for weather data accuracy
- **Notifications**: Required for safety alerts
- **Background Processing**: Required for continuous monitoring
- **Graceful Degradation**: App functions with limited permissions

## Deployment Configuration

### Production Setup
- **Android**: Play Store deployment with background service permissions
- **iOS**: App Store deployment with background app refresh
- **Code Signing**: Platform-specific signing certificates
- **Release Builds**: Optimized production builds

### CI/CD Considerations
- **Automated Testing**: Unit and integration test execution
- **Build Automation**: Multi-platform build generation
- **Version Management**: Semantic versioning for releases
- **Dependency Updates**: Regular security and feature updates

## Technical Constraints

### Platform Limitations
- **iOS Background**: Limited background processing time
- **Android Battery**: Doze mode and app standby restrictions
- **Web Limitations**: No background processing or local notifications
- **API Rate Limits**: 10,000 requests/day for weather data

### Performance Requirements
- **Cold Start**: App launch under 3 seconds
- **Weather Loading**: Data fetch under 2 seconds
- **Battery Impact**: Minimal background processing overhead
- **Memory Usage**: Efficient resource management