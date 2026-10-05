# BiletFlow Check-In — setup

## 1. Dependencies
```
flutter pub add mobile_scanner flutter_secure_storage http
```

## 2. Permissions
**Android** — `android/app/src/main/AndroidManifest.xml` (inside `<manifest>`):
```xml
<uses-permission android:name="android.permission.CAMERA"/>
<uses-permission android:name="android.permission.INTERNET"/>
```
`flutter_secure_storage` needs `minSdkVersion 23` (android/app/build.gradle).
`mobile_scanner` may need `minSdkVersion 21+` (check its README for the current value).

**iOS** — `ios/Runner/Info.plist`:
```xml
<key>NSCameraUsageDescription</key>
<string>Камера нужна для сканирования QR-кодов билетов</string>
```

## 3. Mock vs real backend
`lib/services/api_service.dart`:
- `kUseMockApi = true` runs everything in-memory. Login: any email with `@` and password of 4+ chars.
- Set `kUseMockApi = false` and edit `kBaseUrl` when the backend exists. Align endpoint paths and JSON with the team's API contract.

## 4. Testing the scanner with mock data
Admission QR payload format: `BF1:<ticketId>`. Generate QR codes (any online generator) for:
`BF1:T-1001` (valid), `BF1:T-1004` (already used), `BF1:T-1005` (cancelled), `BF1:T-1006` (refunded), `BF1:T-9999` (invalid).
A QR containing `https://...` is rejected as a Campaign QR / non-ticket.

## 5. Replace your old files
Replace `main.dart`, `scanner_screen.dart`, `event_selection_screen.dart`. New: `models/`, `services/`, `screens/login_screen.dart`, `screens/attendee_search_screen.dart`.
(Move the screens into `lib/screens/` and update imports, or keep your original folder layout.)
