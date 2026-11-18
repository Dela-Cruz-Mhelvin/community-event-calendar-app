# Community Event Calendar

A simple mobile app built with Flutter that helps people in a community keep track of local events such as barangay assemblies, clean-up drives, sports leagues and cultural nights.

## Features

- Monthly calendar with colored dots on days that have events
- Tap a date to see its events
- Add an event with a name, date, time, place and category
- Delete events (with a confirmation message)
- Five categories: Meeting, Health, Sports, Culture and Learning
- Filter the calendar and lists by category
- "Coming up" list of the next five events
- Light and dark theme switch
- Events and theme are saved on the device, so they are still there after closing the app

## How to install and run

### Requirements

- [Flutter SDK](https://docs.flutter.dev/get-started/install) (3.x or newer)
- Android Studio or VS Code with the Flutter extension
- An Android phone with USB debugging on, or an Android emulator

### Steps

1. Download or clone this repository:

   ```bash
   git clone https://github.com/Dela-Cruz-Mhelvin/community-event-calendar-app.git
   cd community-event-calendar-app
   ```

2. Install the packages:

   ```bash
   flutter pub get
   ```

3. Start an emulator or connect your phone, then run the app:

   ```bash
   flutter run
   ```

   To try it in Chrome instead, run `flutter run -d chrome`.

4. (Optional) Build an installable APK:

   ```bash
   flutter build apk
   ```

   The file is created at `build/app/outputs/flutter-apk/app-release.apk`.

## Built with

- Flutter and Dart
- `shared_preferences` package for saving data on the device

## Author

**Mhelvin A. Dela Cruz**
Section: *BSINTE-2C*
Bachelor of Science in Information Technology, Nueva Vizcaya State University