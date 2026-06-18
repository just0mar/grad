# EQQ - Agent Customization Guide

**EQQ** is a Flutter mobile application for equipment and event management. This guide helps AI coding agents understand the project structure, conventions, and best practices.

## Project Overview

- **Type**: Flutter mobile app (Android & iOS)
- **Language**: Dart 3.9+
- **Architecture**: MVVM (Model-View-ViewModel) with feature-based folder structure
- **State Management**: Provider pattern (provider 6.1.2)
- **Key Dependencies**: file_picker, syncfusion_flutter_pdfviewer, table_calendar, fl_chart, device_info_plus

## Project Structure

```
lib/
├── main.dart              # App entry point
├── auth/                  # Authentication screens
│   ├── LoginModel.dart
│   ├── LoginView.dart
│   ├── LoginViewModel.dart
│   └── ...
├── [feature]/             # Feature folders (home, team, chat, profile, etc.)
│   ├── [Feature]Model.dart      # Data model (plain class)
│   ├── [Feature]View.dart       # UI widgets
│   └── [Feature]ViewModel.dart  # Business logic & state
├── navigation/            # Navigation & routing
├── appbar/                # Reusable components (CustomAppBar)
└── [other features...]    # 20+ feature modules
```

## Architecture & Patterns

### MVVM Pattern

Each feature follows **Model-View-ViewModel** separation:

1. **Model** - Plain Dart class with data and simple validation
   ```dart
   class LoginModel {
     final String email;
     final String password;
     LoginModel({required this.email, required this.password});
   }
   ```

2. **ViewModel** - Business logic, validation, state management
   ```dart
   class LoginViewModel {
     LoginModel? _loginModel;
     
     void setCredentials(String email, String password) {
       _loginModel = LoginModel(email: email, password: password);
     }
   }
   ```

3. **View** - UI layer using Dart widgets
   - Use StatelessWidget or StatefulWidget as appropriate
   - Compose UI with reusable components like CustomAppBar

### Reusable Components

- **CustomAppBar** - Located in `appbar/CustomAppBar.dart`
  - Provides consistent app bar styling across screens
  - Implements PreferredSizeWidget
  - Supports custom back button callbacks

### Feature-Based Organization

Features are organized in separate folders: auth, home, team, chat, profile, search, settings, notifications, etc. This makes features:
- Easy to locate and maintain
- Independently testable
- Simple to add or remove

## Development Conventions

### File Naming
- Use PascalCase for file names: `LoginView.dart`, `AddTeamModel.dart`
- Models end with `Model`: `LoginModel.dart`
- Views end with `View`: `LoginView.dart`
- ViewModels end with `ViewModel`: `LoginViewModel.dart`

### Widget Building
- Use SafeArea when needed to respect device notches/status bars
- Use SingleChildScrollView to prevent overflow errors
- Apply consistent padding and spacing
- Use OutlineInputBorder with borderRadius for text fields

### Imports
- Use relative imports within features: `import 'LoginModel.dart';`
- Use absolute imports across features: `import '../home/HomeView.dart';`

### Code Style
- Follow flutter_lints (enabled in analysis_options.yaml)
- Use const constructors where possible
- Prefer named parameters in constructors
- Add documentation comments for public APIs

## Build & Run Commands

```bash
# Get dependencies
flutter pub get

# Analyze code
flutter analyze

# Run app
flutter run

# Build release
flutter build apk          # Android APK
flutter build ipa          # iOS build archive
flutter build web          # Web version
```

## Key Files & Directories

| Path | Purpose |
|------|---------|
| `lib/main.dart` | Application entry point and root widget |
| `lib/auth/` | Login/signup screens and authentication |
| `lib/navigation/` | Navigation routing and app structure |
| `lib/appbar/CustomAppBar.dart` | Reusable app bar component |
| `pubspec.yaml` | Dependencies and project metadata |
| `analysis_options.yaml` | Lint rules and analysis settings |
| `android/` | Android native configuration |
| `ios/` | iOS native configuration |
| `assets/` | Images, fonts, and other static resources |

## Common Tasks

### Adding a New Feature
1. Create folder in `lib/` with feature name (e.g., `lib/newfeature/`)
2. Add three files: `NewFeatureModel.dart`, `NewFeatureView.dart`, `NewFeatureViewModel.dart`
3. Follow MVVM pattern from existing features
4. Add navigation route if needed in `navigation/` folder

### Creating Reusable Components
1. Place in `appbar/` or appropriate shared folder
2. Use StatelessWidget if no internal state needed
3. Document constructor parameters clearly
4. Use const constructor when possible

### Modifying Existing Screens
1. Update Model for data structure changes
2. Update ViewModel for business logic changes
3. Update View for UI changes
4. Ensure consistency with CustomAppBar styling

## Dependencies to Know

| Package | Version | Purpose |
|---------|---------|---------|
| provider | 6.1.2 | State management |
| file_picker | 8.0.0 | File selection from device |
| syncfusion_flutter_pdfviewer | 31.1.19 | PDF viewing capability |
| table_calendar | 3.0.9 | Calendar widget for events/plans |
| fl_chart | 0.68.0 | Chart generation for stats |
| cupertino_icons | 1.0.8 | iOS-style icons |

## Current State

**Note**: Much of the codebase is currently commented out. The project appears to be in active development/refactoring. When implementing features:
- Uncomment and adapt existing code as appropriate
- Follow the established patterns (MVVM, feature-based structure)
- Maintain consistency with existing implementations
- Test thoroughly on both Android and iOS

## Performance Considerations

- Use `const` constructors to avoid rebuilds
- Leverage Provider pattern for efficient state updates
- Use `SingleChildScrollView` for scrollable content to prevent overflow
- Consider lazy loading for large lists/PDFs

## Troubleshooting

- **Overflow errors**: Wrap content with SingleChildScrollView
- **Import errors**: Verify relative/absolute path correctness
- **Widget issues**: Check if parent widget provides required constraints
- **State management**: Ensure ViewModels handle null states properly

---

**Last Updated**: April 2026 | **Status**: Active Development
