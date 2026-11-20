/// API base URL. Override at build/run time:
///   flutter run --dart-define=API_BASE=http://10.0.2.2:8000     (Android emulator)
///   flutter build web --dart-define=API_BASE=https://api.example.com
const apiBase = String.fromEnvironment('API_BASE', defaultValue: 'http://127.0.0.1:8000');
