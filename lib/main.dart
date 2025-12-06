import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import '/services/local_storage_service.dart';
import 'screens/profile_edit_screen.dart';
import 'screens/inspection_form_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'screens/login_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/ilce_vehicles_screen.dart';
import 'screens/school_vehicles_screen.dart';
import 'screens/vehicle_approval_screen.dart';
import 'screens/school_vehicle_form_screen.dart';
import 'screens/vehicle_edit_screen.dart';
import 'screens/vehicle_reports_screen.dart';
import 'screens/user_management_screen.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Local storage'ı başlat
  await LocalStorageService().init();

  // SUPABASE INITIALIZE
  await Supabase.initialize(
    url: 'https://zxhvyfbzhuvbcnuxsaxq.supabase.co', // SUPABASE_URL'niz
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Inp4aHZ5ZmJ6aHV2YmNudXhzYXhxIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTk2ODg5MzMsImV4cCI6MjA3NTI2NDkzM30.rFB-7LP_ccNWrPXIpfTuwAW9zdgRXeX0w79kra5P0uQ', // ANON_KEY'iniz
  );

  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Servis Denetim App',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => LoginScreen(),
        '/home': (context) => DashboardScreen(),
        '/dashboard': (context) => DashboardScreen(),
        '/ilce-vehicles': (context) => IlceVehiclesScreen(),
        '/school-vehicles': (context) => SchoolVehiclesScreen(),
        '/vehicle-approval': (context) => VehicleApprovalScreen(),
        '/vehicle-form': (context) => SchoolVehicleFormScreen(),
        '/inspection': (context) => InspectionFormScreen(vehiclePlate: '',), // ← DOĞRU İSİM
        '/vehicle-edit': (context) => VehicleEditScreen(vehicle: {},), // BU SATIRI KALDIRIYORUZ
        '/reports': (context) => VehicleReportsScreen(),
        '/profile-edit': (context) {
          final user = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
          return ProfileEditScreen(user: user);
        },
      },
      onGenerateRoute: (settings) {
        // VehicleEditScreen için özel route handling
        if (settings.name == '/vehicle-edit') {
          final vehicle = settings.arguments as Map<String, dynamic>?;
          return MaterialPageRoute(
            builder: (context) => VehicleEditScreen(vehicle: vehicle ?? {}),
          );
        }

        // InspectionScreen için özel route handling
        if (settings.name == '/inspection-with-plate') {
          final args = settings.arguments as Map<String, dynamic>?;
          return MaterialPageRoute(
            builder: (context) => InspectionFormScreen(
              vehiclePlate: args?['vehiclePlate'] ?? '',
            ),
          );
        }
        return MaterialPageRoute(builder: (context) => LoginScreen());
      },
      onUnknownRoute: (settings) {
        return MaterialPageRoute(builder: (context) => LoginScreen());
      },
    );
  }

}
class LocalStorageService {
  Future<void> init() async {
    if (kIsWeb) {
      print('🌐 WEB ORTAMI: Local storage başlatılmıyor');
      return;
    }

    try {
      // Mevcut init kodu
      final directory = await getApplicationDocumentsDirectory();
      // ...
    } catch (e) {
      print('❌ Local storage init hatası: $e');
    }
  }
}