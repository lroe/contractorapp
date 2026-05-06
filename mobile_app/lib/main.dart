import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'models/models.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'services/session_manager.dart';
import 'services/sync_queue_manager.dart';
import 'services/network_connectivity.dart';
import 'services/offline_dpr_manager.dart';
import 'services/background_sync_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();

  // Register Adapters
  Hive.registerAdapter(UserAdapter());
  Hive.registerAdapter(ProjectAdapter());
  Hive.registerAdapter(GangAdapter());
  Hive.registerAdapter(WorkerAdapter());
  Hive.registerAdapter(AttendanceAdapter());
  Hive.registerAdapter(ProjectDocumentAdapter());
  Hive.registerAdapter(DailyProgressReportAdapter());

  // Initialize all managers
  await SessionManager.initialize();
  await SyncQueueManager.initialize();
  await OfflineDPRManager.initialize();
  await NetworkConnectivity().initialize();

  // Open Boxes
  await Hive.openBox<Project>('projects');
  await Hive.openBox<Gang>('gangs');
  await Hive.openBox<Worker>('workers');
  await Hive.openBox<Attendance>('attendance');

  // Initialize background sync service
  BackgroundSyncService().initialize();

  runApp(const ContractorApp());
}

class ContractorApp extends StatelessWidget {
  const ContractorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Nirmitha',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1E293B), // Slate 800
          primary: const Color(0xFF1E293B),
          secondary: const Color(0xFF3B82F6), // Blue 500
        ),
        textTheme: GoogleFonts.outfitTextTheme(),
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => const SplashScreen(),
        '/login': (context) => const LoginScreen(),
        '/home': (context) => const HomeScreen(),
      },
    );
  }
}

/// Splash screen that handles auto-login
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkAutoLogin();
  }

  Future<void> _checkAutoLogin() async {
    await Future.delayed(const Duration(seconds: 1));

    if (!mounted) return;

    // Check if user has saved session
    final user = SessionManager.getStoredUser();

    if (user != null) {
      print('[AutoLogin] Restoring session for user: ${user.name}');
      Navigator.pushReplacementNamed(context, '/home', arguments: user);
    } else {
      Navigator.pushReplacementNamed(context, '/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(
              'Nirmitha',
              style: GoogleFonts.outfit(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Contractor Management',
              style: GoogleFonts.outfit(fontSize: 14, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}
