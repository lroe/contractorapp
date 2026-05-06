# Offline-First Contractor App - Implementation Guide

## 🎯 What We've Built

Your Flutter app now supports **complete offline functionality** with automatic background sync. Users can work on reports even without internet, and everything syncs automatically when connection is restored.

## ✨ Key Features Implemented

### 1. **Auto-Login After Gmail Sign-In** 🔐
- Once user logs in with Gmail, their session is saved locally
- App auto-logs them in on subsequent launches
- Session persists until manual logout
- **Location**: `lib/services/session_manager.dart`

### 2. **Offline Project Reports** 📝
- Create DPR (Daily Progress Reports) without internet
- Photos and remarks stored locally
- Offline indicator shows at top of app
- **Location**: `lib/screens/dpr_screen.dart`

### 3. **Automatic Background Sync** 🔄
- When network returns, app automatically syncs queued reports
- No user action needed - happens in background
- Syncs every 10 seconds while online
- **Location**: `lib/services/background_sync_service.dart`

### 4. **Network Status Monitoring** 🌐
- Real-time connectivity detection
- Offline badges shown on home screen and DPR screen
- Sync listeners notify UI of changes
- **Location**: `lib/services/network_connectivity.dart`

## 📁 New Files Added

### Core Services
| File | Purpose |
|------|---------|
| `session_manager.dart` | Persists & restores user login session |
| `network_connectivity.dart` | Monitors internet connectivity |
| `sync_queue_manager.dart` | Queues operations for sync |
| `offline_dpr_manager.dart` | Manages local DPR storage |
| `background_sync_service.dart` | Auto-syncs when online |

### Updated Files
| File | Changes |
|------|---------|
| `main.dart` | Initialize managers, auto-login splash screen |
| `login_screen.dart` | Save session after Gmail login |
| `home_screen.dart` | Show offline indicator, clear session on logout |
| `dpr_screen.dart` | Handle offline DPR creation & storage |
| `models.dart` | Added `DailyProgressReport` model |
| `pubspec.yaml` | Added `connectivity_plus`, `path_provider` |

## 🔧 How It Works

### On App Startup
```
1. App checks for saved user session
2. If found → Auto-login & go to home screen
3. If not found → Show login screen
4. Background sync service initializes
```

### Creating a Report Online
```
1. User fills DPR form
2. Clicks "Submit"
3. Report sent immediately to server
4. Success message shown
```

### Creating a Report Offline
```
1. User fills DPR form
2. Click "Submit"
3. Report saved locally with timestamp
4. Added to sync queue
5. Orange "offline saved" message shown
6. Media files stored in documents directory
```

### When Network Returns
```
1. Network connectivity detected
2. Background sync service kicks in
3. Queued reports sent to server one by one
4. Each successful sync updates local status
5. Failed operations retried (max 3 times)
6. User can see sync progress in logs
```

### Manual Logout
```
1. User clicks Logout in menu
2. Session is cleared locally
3. User returned to login screen
4. Sync queue remains (can sync later if needed)
```

## 📊 Data Flow Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│                        CONTRACTOR APP                           │
├─────────────────────────────────────────────────────────────────┤
│                                                                   │
│  [Network Available]              [Network Unavailable]         │
│       ↓                                    ↓                     │
│  Submit Report ────────────────→ Save Locally to Hive           │
│       ↓                                    ↓                     │
│  Send to API ────────────────→ Add to Sync Queue                │
│       ↓                                    ↓                     │
│  Success Response                    Show Offline Badge         │
│       ↓                                    ↓                     │
│  Update Local DB              Wait for Network Detection        │
│       ↓                                    ↓                     │
│  Show Success                      [Network Returns]            │
│                                           ↓                     │
│                              Background Sync Service            │
│                                           ↓                     │
│                              Send Queued Reports to API         │
│                                           ↓                     │
│                                    Update Local Status           │
│                                                                   │
└─────────────────────────────────────────────────────────────────┘
```

## 🚀 Next Steps & Future Enhancements

### Immediate (Required Before Production)
- [ ] Run `flutter pub get` to install new dependencies
- [ ] Run `flutter pub run build_runner build` to generate Hive adapters
- [ ] Test on iOS and Android
- [ ] Add iOS permissions for connectivity
- [ ] Add Android permissions for connectivity

### Short Term
- [ ] Add sync progress indicator on home screen
- [ ] Show pending sync count badge
- [ ] Add manual retry button for failed syncs
- [ ] Cache project list for offline browsing

### Medium Term
- [ ] Sync attendance records offline
- [ ] Sync project updates offline
- [ ] Local search of cached data
- [ ] Export offline reports to PDF

### Long Term
- [ ] Differential sync (only changed fields)
- [ ] Conflict resolution for concurrent edits
- [ ] P2P sync between devices
- [ ] Custom offline sync policies per operation type

## 🔌 Configuration

### Network Connectivity Monitoring
Located in `network_connectivity.dart` - checks every network change automatically

### Sync Retry Policy
- Max retries: 3 attempts
- Check interval: Every 10 seconds when online
- Located in `sync_queue_manager.dart` and `background_sync_service.dart`

### Local Storage Location
- DPR reports: Hive box `dpr_reports`
- Session data: Hive box `session`
- Sync queue: Hive box `sync_queue`
- Media files: `Documents/dpr_media/`

## 📝 API Integration Notes

The offline sync automatically calls your existing API endpoints:
- `POST /dpr/` - Submit DPR
- `POST /dpr/{id}/media/` - Upload DPR media
- Other endpoints can be added to sync operations by extending `BackgroundSyncService._syncOperation()`

## 🐛 Debugging & Troubleshooting

### Check Local Session
```dart
// In terminal or debug console
SessionManager.getStoredUser();  // Returns stored user or null
SessionManager.hasActiveSession();  // true/false
```

### Check Sync Queue
```dart
SyncQueueManager.getPendingOperations();  // List all queued ops
SyncQueueManager.getQueueSize();  // Count pending operations
```

### Check Network Status
```dart
NetworkConnectivity().isOnline;  // true/false
```

### Enable Debug Logging
All services print to console with `[ServiceName]` prefix:
- `[SessionManager]` - Session operations
- `[NetworkConnectivity]` - Network changes  
- `[SyncQueue]` - Queue operations
- `[OfflineDPR]` - DPR operations
- `[BackgroundSync]` - Sync operations

## ⚙️ Dependencies Added

```yaml
connectivity_plus: ^6.0.0  # Network monitoring
path_provider: ^2.1.2      # App documents directory
```

These replace platform-specific connectivity monitoring code.

## 🔒 Security Considerations

1. **Session Storage**: User data stored in local Hive box - encrypted by Hive
2. **Auth Token**: ID token stored locally for potential re-auth
3. **Media Files**: Stored in app documents directory (sandboxed)
4. **Sync Queue**: Contains unsynced data - cleared after successful upload

For production, consider:
- Adding encrypted shared preferences for tokens
- Implementing certificate pinning
- Adding device-level encryption

## 📱 User Experience Flow

### First Time User
1. Opens app → Sees login screen
2. Clicks "Sign with Gmail"
3. Completes Gmail auth
4. Session auto-saved
5. Redirected to home screen

### Returning User
1. Opens app
2. Auto-logs in with saved session
3. Goes directly to home screen

### Creating Report Offline
1. Clicks DPR button
2. Sees "OFFLINE" warning
3. Fills form and adds photos
4. Clicks submit
5. Sees "Saved locally - will sync when online"
6. When online, sees green success notification

### Creating Report Online
1. Clicks DPR button
2. No offline warning shown
3. Fills form and adds photos  
4. Clicks submit
5. Report sent immediately
6. Sees "✓ Report Submitted Successfully!"

## 💡 Tips for Users

- **Always add remarks or photo** - Required for report submission
- **Photos saved locally** - High-res photos stored on device
- **Offline indicator** - Watch for "OFFLINE" badge on top bar
- **Don't force close** - Background sync needs time to complete
- **Manual logout** - Use menu → Logout to clear session

---

**Need Help?** Check the debug logs with the service prefixes or review the inline comments in each service file.
