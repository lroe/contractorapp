# Quick Setup Guide - Offline Features

## 🚀 Getting Started (5 Minutes)

### Step 1: Update Dependencies
```bash
cd mobile_app
flutter pub get
```

### Step 2: Generate Hive Adapters
The new `DailyProgressReport` model needs code generation:

```bash
flutter pub run build_runner build --delete-conflicting-outputs
```

**Note**: This generates the `models.g.dart` file. If you get errors, run:
```bash
flutter clean && flutter pub get && flutter pub run build_runner build
```

### Step 3: Run the App
```bash
flutter run
```

## ✅ What to Verify

### 1. Session Persistence
- [ ] Open app and login with Gmail
- [ ] Close app completely
- [ ] Reopen app - should auto-login without showing login screen
- [ ] Logout from menu - should show login screen next time

### 2. Offline Functionality
- [ ] Turn on airplane mode or disconnect WiFi
- [ ] App should show "OFFLINE" badge on home screen
- [ ] Open DPR screen - should show offline warning
- [ ] Create a DPR report with remarks + photo
- [ ] Should show "Saved locally - will sync when online"
- [ ] Open phone settings and check `Documents/dpr_media/` folder - photos should be there

### 3. Auto-Sync
- [ ] Have pending offline DPRs from step 2
- [ ] Turn internet back on (disable airplane mode)
- [ ] Wait 10 seconds
- [ ] Should see sync notification in console logs
- [ ] DPR should be marked as synced

## 📦 Installed Packages

- **connectivity_plus** - Network monitoring
- **path_provider** - App documents directory access
- **hive** - Already had this for local storage
- **build_runner** - Code generation tool

## 🔍 Testing Offline Mode

### Simulate Offline on Android
```bash
# Using Android emulator
adb emu network status               # Check current status
adb emu network speed full          # Full connectivity
adb emu network speed gsm           # Slow connection
adb emu network speed none          # No connectivity
```

### Simulate Offline on iOS
```bash
# Using iOS simulator
# Settings → Developer → Network Link Conditioner
# Or use Xcode:
# Xcode Menu → Product → Scheme → Edit Scheme → Run → Pre-actions
```

### Or Just Use Device Settings
- Android: Settings → Network → Airplane Mode → Toggle
- iOS: Control Center → Airplane Mode → Toggle

## 📊 Monitor Sync Queue

Add this debug widget to see pending syncs:

```dart
// In home_screen.dart, add to actions:
actions: [
  IconButton(
    icon: const Icon(Icons.info),
    onPressed: () {
      final pending = SyncQueueManager.getQueueSize();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$pending reports pending sync')),
      );
    },
  ),
],
```

## 🐛 Common Issues & Fixes

### Issue: Build runner won't generate adapters
```bash
# Try this:
flutter pub global activate build_runner
flutter pub run build_runner build --delete-conflicting-outputs
```

### Issue: Hive adapter errors at runtime
```
Error: DailyProgressReportAdapter not found
```
**Solution**: Run build_runner again - you didn't regenerate properly

### Issue: "connectivity_plus" plugin not found
```bash
flutter pub get
cd ios && pod install && cd ..  # iOS only
```

### Issue: Photos not saving offline
**Check**: 
- Does app have file permission? 
- Is `path_provider` properly imported?
- Check console logs for `[OfflineDPR]` messages

### Issue: Auto-login not working
**Check**:
1. `SessionManager.hasActiveSession()` returns false
2. Check if session was saved after Gmail login
3. Look for `[LoginScreen] Session saved for auto-login` in logs

## 📝 Code Examples

### Check if User is Logged In
```dart
final user = SessionManager.getStoredUser();
if (user != null) {
  print('User is logged in: ${user.name}');
}
```

### Check Internet Status
```dart
final isOnline = NetworkConnectivity().isOnline;
if (!isOnline) {
  print('App is in offline mode');
}
```

### Manual Sync Trigger
```dart
// Force sync immediately (normally happens automatically)
BackgroundSyncService().performSync();
```

### Get Pending Operations
```dart
final pending = SyncQueueManager.getPendingOperations();
for (var op in pending) {
  print('Pending: ${op.type} (${op.id})');
}
```

## 🎯 Performance Tips

1. **Media Compression**: Consider compressing photos before saving
2. **Sync Timing**: Default 10s check interval - adjust in `background_sync_service.dart` if needed
3. **Database Cleanup**: Old synced reports remain in Hive for history
4. **Battery**: Background sync runs in foreground service, won't drain battery quickly

## 🔗 Related Files

- Main initialization: `lib/main.dart`
- Login flow: `lib/screens/login_screen.dart`
- Home screen: `lib/screens/home_screen.dart`
- DPR offline: `lib/screens/dpr_screen.dart`
- All services: `lib/services/*.dart`

## 📱 Android Permissions

Add to `android/app/src/main/AndroidManifest.xml` if missing:

```xml
<uses-permission android:name="android.permission.INTERNET" />
<uses-permission android:name="android.permission.ACCESS_NETWORK_STATE" />
<uses-permission android:name="android.permission.ACCESS_WIFI_STATE" />
<uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE" />
<uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE" />
```

## 🍎 iOS Permissions

Add to `ios/Runner/Info.plist`:

```xml
<key>NSLocalNetworkUsageDescription</key>
<string>This app uses network connectivity to sync reports</string>
<key>NSBonjourServiceTypes</key>
<array>
  <string>_http._tcp</string>
</array>
```

## ✨ Next After Setup

1. Test all 3 scenarios (online, offline, sync)
2. Check console for any errors
3. Review `OFFLINE_FEATURES_GUIDE.md` for detailed documentation
4. Read inline code comments in service files
5. Extend sync for other data types as needed

---

**Questions?** Check the logs - every service logs with a `[ServiceName]` prefix for easy debugging!
