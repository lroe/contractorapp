import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'models/models.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();

  // Register Adapters
  Hive.registerAdapter(UserAdapter());
  Hive.registerAdapter(ProjectAdapter());
  Hive.registerAdapter(GangAdapter());
  Hive.registerAdapter(WorkerAdapter());
  Hive.registerAdapter(AttendanceAdapter());

  // Open Boxes
  await Hive.openBox<Project>('projects');
  await Hive.openBox<Gang>('gangs');
  await Hive.openBox<Worker>('workers');
  await Hive.openBox<Attendance>('attendance');

  runApp(const ContractorApp());
}

class ContractorApp extends StatelessWidget {
  const ContractorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Contractor DB',
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
        '/': (context) => const LoginScreen(),
        '/login': (context) => const LoginScreen(),
        '/home': (context) => const HomeScreen(),
      },
    );
  }
}
