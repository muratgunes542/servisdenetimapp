// screens/school_dashboard_screen.dart
import 'package:flutter/material.dart';
import 'vehicle_select_screen.dart';
import '/screens/school_vehicles_screen.dart';
import '/screens/school_vehicle_form_screen.dart';
import '/services/database_service.dart';
import '/services/auth_service.dart';
import '/utils/constants.dart';

class SchoolDashboardScreen extends StatefulWidget {
  @override
  State<SchoolDashboardScreen> createState() => _SchoolDashboardScreenState();
}

class _SchoolDashboardScreenState extends State<SchoolDashboardScreen> {
  final DatabaseService _dbService = DatabaseService();
  final AuthService _authService = AuthService();

  // State variables
  String? _userName;
  String? _userEmail;
  String? _schoolName;
  List<Map<String, dynamic>> _myVehicles = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initializeDashboard();
  }

  // Initialize dashboard data
  Future<void> _initializeDashboard() async {
    await _loadUserData();
    await _loadMyVehicles();
    setState(() => _isLoading = false);
  }

  // Load user and school data
  Future<void> _loadUserData() async {
    try {
      final user = await _authService.getCurrentUser();
      print('🔍 OKUL KULLANICI BİLGİLERİ:');
      print('• Ad Soyad: ${user?['full_name']}');
      print('• Email: ${user?['email']}');
      print('• Kullanıcı Tipi: ${user?['user_type']}');
      print('• Telefon: ${user?['phone']}');
      print('• Departman: ${user?['department']}');
      print('• Aktif Mi: ${user?['is_active']}');

      setState(() {
        _userName = user?['full_name'];
        _userEmail = user?['email'];
        _schoolName = user?['department'] ?? 'Okul Bilgisi Yok';
      });
    } catch (e) {
      print('❌ Kullanıcı verisi yükleme hatası: $e');
    }
  }

  // Load vehicles for this school
  Future<void> _loadMyVehicles() async {
    try {
      // TODO: Okula özel araçları getirecek metod
      final allVehicles = await _dbService.getAllVehicles();

      // Şimdilik tüm araçları göster (test için)
      setState(() {
        _myVehicles = allVehicles.take(3).toList(); // Test için sadece 3 araç
      });

      print('✅ Araçlar yüklendi: ${_myVehicles.length} adet');
    } catch (e) {
      print('❌ Araç yükleme hatası: $e');
    }
  }

  // Handle logout
  void _handleLogout() async {
    await _authService.logout();
    Navigator.pushReplacementNamed(context, '/login');
  }

  // Show coming soon message
  void _showComingSoon(String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$feature - Yakında eklenecek'),
        backgroundColor: Colors.blue,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: _buildAppBar(),
      body: _isLoading ? _buildLoading() : _buildDashboardContent(),
      floatingActionButton: _buildFloatingActionButton(),
    );
  }

  // AppBar with school info
  AppBar _buildAppBar() {
    return AppBar(
      backgroundColor: Color(0xFFE3F2FD),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Okul Servis Yönetimi',
            style: TextStyle(
              color: Color(0xFF2196F3),
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            _schoolName ?? 'Okul',
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 12,
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: Icon(Icons.person, color: Color(0xFF2196F3)),
          onPressed: _showUserInfo,
          tooltip: 'Kullanıcı Bilgisi',
        ),
        IconButton(
          icon: Icon(Icons.logout, color: Color(0xFF2196F3)),
          onPressed: _handleLogout,
          tooltip: 'Çıkış Yap',
        ),
      ],
    );
  }

  // Loading indicator
  Widget _buildLoading() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text('Okul paneli yükleniyor...'),
        ],
      ),
    );
  }

  // Main dashboard content
  Widget _buildDashboardContent() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        children: [
          _buildWelcomeCard(),
          SizedBox(height: 20),
          _buildStatsCards(),
          SizedBox(height: 20),
          _buildQuickActions(),
          SizedBox(height: 20),
          _buildMyVehicles(),
        ],
      ),
    );
  }

  // Welcome card with user and school info
  Widget _buildWelcomeCard() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: EdgeInsets.all(20),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: Color(0xFFE3F2FD),
              radius: 30,
              child: Icon(
                Icons.school,
                size: 30,
                color: Color(0xFF2196F3),
              ),
            ),
            SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Hoş Geldiniz, ${_userName ?? ''} 👋',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[800],
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    _schoolName ?? 'Okul',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    _userEmail ?? '',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[500],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Statistics cards
  Widget _buildStatsCards() {
    final totalVehicles = _myVehicles.length;
    final approvedVehicles = _myVehicles.where((v) => v['is_approved'] == true).length;
    final pendingVehicles = _myVehicles.where((v) => v['is_approved'] == false).length;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _buildStatCard('Toplam Araç', totalVehicles.toString(), Icons.directions_bus, Colors.blue),
          SizedBox(width: 12),
          _buildStatCard('Onaylı', approvedVehicles.toString(), Icons.check_circle, Colors.green),
          SizedBox(width: 12),
          _buildStatCard('Bekleyen', pendingVehicles.toString(), Icons.pending, Colors.orange),
          SizedBox(width: 12),
          _buildStatCard('Öğrenci', '0', Icons.school, Colors.purple),
        ],
      ),
    );
  }

  // Single stat card
  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Card(
      elevation: 2,
      child: Container(
        width: 140,
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon, size: 30, color: color),
            SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ),
            ),
            SizedBox(height: 4),
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  // Quick action buttons
  // screens/school_dashboard_screen.dart - Denetim butonu ekle
  Widget _buildQuickActions() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            _buildActionButton(
              'YENİ ARAÇ KAYDET',
              Icons.add_circle,
              Colors.green,
                  () => Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => SchoolVehicleFormScreen()),
              ),
            ),
            SizedBox(height: 10),
            _buildActionButton(
              'ARAÇ LİSTEM',
              Icons.list_alt,
              Colors.blue,
                  () => Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => SchoolVehiclesScreen()),
              ),
            ),
            SizedBox(height: 10),
            _buildActionButton(
              'DENETİM YAP',
              Icons.assignment,
              Colors.orange,
                  () => Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => VehicleSelectScreen()),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Reusable action button
  Widget _buildActionButton(String text, IconData icon, Color color, VoidCallback onPressed) {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon),
        label: Text(text),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
        ),
      ),
    );
  }

  // My vehicles list
  Widget _buildMyVehicles() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'KAYITLI ARAÇLARIM',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[800],
                  ),
                ),
                Spacer(),
                IconButton(
                  icon: Icon(Icons.refresh, size: 20),
                  onPressed: _loadMyVehicles,
                  tooltip: 'Yenile',
                ),
              ],
            ),
            SizedBox(height: 8),
            _myVehicles.isEmpty ? _buildEmptyVehicles() : _buildVehiclesList(),
          ],
        ),
      ),
    );
  }

  // Empty state for vehicles
  Widget _buildEmptyVehicles() {
    return Padding(
      padding: EdgeInsets.all(20),
      child: Column(
        children: [
          Icon(Icons.directions_bus, size: 48, color: Colors.grey[400]),
          SizedBox(height: 8),
          Text(
            'Henüz araç kaydınız bulunmuyor',
            style: TextStyle(color: Colors.grey[600]),
          ),
          SizedBox(height: 16),
          ElevatedButton(
            onPressed: () => _showComingSoon('Araç Kayıt'),
            child: Text('İLK ARAÇ KAYDINI OLUŞTUR'),
          ),
        ],
      ),
    );
  }

  // Vehicles list
  Widget _buildVehiclesList() {
    return Column(
      children: _myVehicles.map((vehicle) => _buildVehicleItem(vehicle)).toList(),
    );
  }

  // Single vehicle item
  Widget _buildVehicleItem(Map<String, dynamic> vehicle) {
    final isApproved = vehicle['is_approved'] == true;
    final driverName = vehicle['driver_name'] ?? 'Sürücü Bilgisi Yok';

    return Card(
      margin: EdgeInsets.only(bottom: 8),
      elevation: 1,
      child: ListTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: isApproved ? Colors.green.withOpacity(0.1) : Colors.orange.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            isApproved ? Icons.check_circle : Icons.pending,
            color: isApproved ? Colors.green : Colors.orange,
          ),
        ),
        title: Text(
          vehicle['plate'] ?? 'Plaka Yok',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(driverName),
            Text(
              vehicle['model'] ?? 'Model Yok',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: isApproved ? Colors.green.withOpacity(0.1) : Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                isApproved ? 'ONAYLI' : 'BEKLİYOR',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: isApproved ? Colors.green : Colors.orange,
                ),
              ),
            ),
          ],
        ),
        onTap: () => _showVehicleDetails(vehicle),
      ),
    );
  }

  // Floating action button for quick add
  Widget _buildFloatingActionButton() {
    return FloatingActionButton(
      onPressed: () => _showComingSoon('Hızlı Araç Ekle'),
      backgroundColor: Color(0xFF2196F3),
      child: Icon(Icons.add, color: Colors.white),
      tooltip: 'Yeni Araç Ekle',
    );
  }

  // Show user info dialog
  void _showUserInfo() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Kullanıcı Bilgileri'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildInfoRow('Ad Soyad:', _userName ?? 'Belirtilmemiş'),
            _buildInfoRow('Email:', _userEmail ?? 'Belirtilmemiş'),
            _buildInfoRow('Okul:', _schoolName ?? 'Belirtilmemiş'),
            _buildInfoRow('Kullanıcı Tipi:', 'Okul Kullanıcısı'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('TAMAM'),
          ),
        ],
      ),
    );
  }

  // Build info row for dialog
  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          SizedBox(width: 8),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  // Show vehicle details
  void _showVehicleDetails(Map<String, dynamic> vehicle) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Araç Detayları'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildInfoRow('Plaka:', vehicle['plate'] ?? 'Belirtilmemiş'),
            _buildInfoRow('Model:', vehicle['model'] ?? 'Belirtilmemiş'),
            _buildInfoRow('Kapasite:', vehicle['capacity']?.toString() ?? 'Belirtilmemiş'),
            _buildInfoRow('Sürücü:', vehicle['driver_name'] ?? 'Belirtilmemiş'),
            _buildInfoRow('Durum:', vehicle['is_approved'] == true ? 'ONAYLI' : 'ONAY BEKLİYOR'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('KAPAT'),
          ),
        ],
      ),
    );
  }
}