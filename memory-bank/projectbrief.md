# Project Brief: Ride or Drive Weather - Enhanced Motorcycle Weather App

## Project Overview
Ride or Drive Weather is an enhanced Flutter mobile application that helps motorcyclists make informed decisions about whether to ride their motorcycle or drive their car based on current and forecasted weather conditions. The app categorizes weather into 5 safety tiers and provides intelligent recommendations for motorcycle riding safety with advanced features and improved user experience.

## Current State
- **Status**: Fully implemented and functional motorcycle weather app
- **Platform**: Cross-platform Flutter application (Android, iOS, Web, macOS support)
- **Development Stage**: Production-ready with all core features implemented

## Technical Foundation
- **Framework**: Flutter 3.6.1+
- **Language**: Dart
- **Architecture**: Service-based architecture with background processing
- **Dependencies**: Weather API, location services, notifications, background tasks

## Project Structure
```
ride_or_drive/
├── lib/
│   ├── main.dart (app initialization)
│   ├── models/
│   │   └── weather_category.dart (5-tier categorization system)
│   ├── screens/
│   │   ├── home_screen.dart (main weather display)
│   │   └── settings_screen.dart (user preferences)
│   └── services/
│       ├── weather_service.dart (Open-Meteo API integration)
│       ├── notification_service.dart (local notifications)
│       └── background_service.dart (monitoring & alerts)
├── android/ (Android platform files)
├── ios/ (iOS platform files)
├── memory-bank/ (project documentation)
└── pubspec.yaml (comprehensive dependencies)
```

## Core Features Implemented
- **5-Tier Weather Categorization**: Perfect, Good, Okay, Bad, Dangerous
- **Real-time Weather Data**: Open-Meteo API integration
- **Location-based Forecasting**: GPS-based weather for user's location
- **Smart Notifications**: Daily motorcycle ride/drive recommendations
- **Background Monitoring**: Continuous weather change detection
- **Emergency Alerts**: Notifications for dangerous condition changes
- **User Settings**: Customizable notification times and preferences
- **Modern UI**: Material Design 3 with intuitive weather visualization

## Goals Achieved
- ✅ Functional motorcycle safety weather application
- ✅ Flutter best practices implementation
- ✅ Clean, scalable service-based architecture
- ✅ Multi-platform compatibility
- ✅ Background processing with battery optimization
- ✅ Comprehensive notification system

## Technical Constraints
- Cross-platform compatibility (Android, iOS, Web, macOS)
- Battery optimization for background services
- Location permission handling
- API rate limiting considerations
- Material Design 3 compliance
- Maintain Flutter performance standards