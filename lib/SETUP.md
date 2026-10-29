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

## 3. Backend
The app talks to the live backend: `kBaseUrl` in `lib/services/api_service.dart`
(`https://biletflow.duckdns.org/api`). API docs: https://biletflow.duckdns.org/swagger-ui/index.html

## 4. Who sees what
Every signed-in user gets the attendee tabs: **Афиша** (events, ticket selection, order),
**Билеты** (tickets with the server-generated QR code) and **Заказы** (orders, demo payment, cancel).
Users assigned to an event as check-in staff (`POST /api/events/{id}/staff` by the organizer)
also get the **Проверка** tab: scanner, attendee search, undo check-in.

## 5. Testing check-in end to end
1. Register attendee account A and buy/register a ticket in the app.
2. As the event's organizer, assign account B as staff for that event.
3. Sign in as B, open **Проверка**, and scan A's ticket QR from another phone or screen.
   A QR containing `https://...` is rejected as a Campaign QR / non-ticket.
