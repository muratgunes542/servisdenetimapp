import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:fl_chart/fl_chart.dart'; // YENİ PAKET
import '/services/database_service.dart';
import '/utils/constants.dart';

class ReportsScreen extends StatefulWidget {
  @override
  _ReportsScreenState createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  final SupabaseClient _supabase = Supabase.instance.client;
  final DatabaseService _dbService = DatabaseService();

  List<Map<String, dynamic>> _allInspections = [];
  List<Map<String, dynamic>> _filteredInspections = [];
  bool _isLoading = true;
  DateTime? _startDate;
  DateTime? _endDate;
  String _selectedStatus = 'all';
  int _touchedIndex = -1;

  @override
  void initState() {
    super.initState();
    _loadReports();
  }

  Future<void> _loadReports() async {
    try {
      final inspections = await _dbService.getAllInspections();
      setState(() {
        _allInspections = inspections;
        _filteredInspections = inspections;
        _isLoading = false;
      });
    } catch (e) {
      print('Rapor yükleme hatası: $e');
      setState(() => _isLoading = false);
    }
  }

  void _applyFilters() {
    List<Map<String, dynamic>> filtered = _allInspections;

    if (_startDate != null) {
      filtered = filtered.where((inspection) {
        final inspectionDate = DateTime.parse(inspection['inspection_date']);
        return inspectionDate.isAfter(_startDate!);
      }).toList();
    }

    if (_endDate != null) {
      filtered = filtered.where((inspection) {
        final inspectionDate = DateTime.parse(inspection['inspection_date']);
        return inspectionDate.isBefore(_endDate!.add(Duration(days: 1)));
      }).toList();
    }

    if (_selectedStatus != 'all') {
      filtered = filtered.where((inspection) {
        return inspection['status'] == _selectedStatus;
      }).toList();
    }

    setState(() {
      _filteredInspections = filtered;
    });
  }

  void _clearFilters() {
    setState(() {
      _startDate = null;
      _endDate = null;
      _selectedStatus = 'all';
      _filteredInspections = _allInspections;
    });
  }

  Map<String, dynamic> _getStats() {
    final total = _filteredInspections.length;
    final compliant = _filteredInspections.where((i) => i['status'] == 'compliant').length;
    final conditional = _filteredInspections.where((i) => i['status'] == 'conditional').length;
    final nonCompliant = _filteredInspections.where((i) => i['status'] == 'non_compliant').length;

    return {
      'total': total,
      'compliant': compliant,
      'conditional': conditional,
      'nonCompliant': nonCompliant,
      'complianceRate': total > 0 ? ((compliant / total) * 100) : 0,
    };
  }

  List<PieChartSectionData> _getPieChartData() {
    final stats = _getStats();
    final total = stats['total'] as int;
    if (total == 0) return [];

    return [
      PieChartSectionData(
        color: Colors.green,
        value: stats['compliant'].toDouble(),
        title: '${((stats['compliant'] / total) * 100).toStringAsFixed(1)}%',
        radius: _touchedIndex == 0 ? 60 : 50,
        titleStyle: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
      ),
      PieChartSectionData(
        color: Colors.orange,
        value: stats['conditional'].toDouble(),
        title: '${((stats['conditional'] / total) * 100).toStringAsFixed(1)}%',
        radius: _touchedIndex == 1 ? 60 : 50,
        titleStyle: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
      ),
      PieChartSectionData(
        color: Colors.red,
        value: stats['nonCompliant'].toDouble(),
        title: '${((stats['nonCompliant'] / total) * 100).toStringAsFixed(1)}%',
        radius: _touchedIndex == 2 ? 60 : 50,
        titleStyle: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final stats = _getStats();
    final pieChartData = _getPieChartData();

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Color(0xFFE3F2FD),
        title: Text(
          'Detaylı Raporlar',
          style: TextStyle(
            color: Color(0xFF2196F3),
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Color(0xFF2196F3)),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: Color(0xFF2196F3)),
            onPressed: _loadReports,
          ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : Column(
        children: [
          // Filtreler (Aynı kalacak)
          _buildFilters(),

          // İstatistik Kartları
          _buildStatsCards(stats),

          // Grafik
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(16),
              child: Column(
                children: [
                  // Pasta Grafik
                  _buildPieChart(pieChartData, stats),

                  // Detaylı Liste
                  _buildDetailedList(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPieChart(List<PieChartSectionData> pieChartData, Map<String, dynamic> stats) {
    return Card(
      elevation: 2,
      margin: EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            Text(
              'Denetim Dağılımı',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ),
            ),
            SizedBox(height: 16),
            Container(
              height: 300,
              child: pieChartData.isEmpty
                  ? Center(child: Text('Gösterilecek veri yok'))
                  : PieChart(
                PieChartData(
                  pieTouchData: PieTouchData(
                    touchCallback: (FlTouchEvent event, pieTouchResponse) {
                      setState(() {
                        if (!event.isInterestedForInteractions ||
                            pieTouchResponse == null ||
                            pieTouchResponse.touchedSection == null) {
                          _touchedIndex = -1;
                          return;
                        }
                        _touchedIndex = pieTouchResponse.touchedSection!.touchedSectionIndex;
                      });
                    },
                  ),
                  borderData: FlBorderData(show: false),
                  sectionsSpace: 0,
                  centerSpaceRadius: 40,
                  sections: pieChartData,
                ),
              ),
            ),
            // Grafik Açıklamaları
            SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildChartLegend('Uygun', Colors.green, stats['compliant']),
                _buildChartLegend('Şartlı', Colors.orange, stats['conditional']),
                _buildChartLegend('Uygun Değil', Colors.red, stats['nonCompliant']),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChartLegend(String text, Color color, int count) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        SizedBox(width: 4),
        Text(
          '$text ($count)',
          style: TextStyle(fontSize: 12),
        ),
      ],
    );
  }

  // Diğer widget'lar aynı kalacak (_buildFilters, _buildStatsCards, _buildDetailedList vb.)
  Widget _buildFilters() {
    return Card(
      margin: EdgeInsets.all(16),
      elevation: 2,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Filtreler',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[800],
                    ),
                  ),
                ),
                TextButton(
                  onPressed: _clearFilters,
                  child: Text('Filtreleri Temizle'),
                ),
              ],
            ),
            SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Başlangıç Tarihi', style: TextStyle(fontSize: 12)),
                      SizedBox(height: 4),
                      InkWell(
                        onTap: () async {
                          final date = await showDatePicker(
                            context: context,
                            initialDate: _startDate ?? DateTime.now(),
                            firstDate: DateTime(2020),
                            lastDate: DateTime.now(),
                          );
                          if (date != null) {
                            setState(() => _startDate = date);
                            _applyFilters();
                          }
                        },
                        child: Container(
                          padding: EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.calendar_today, size: 16),
                              SizedBox(width: 8),
                              Text(
                                _startDate != null
                                    ? '${_startDate!.day}/${_startDate!.month}/${_startDate!.year}'
                                    : 'Tarih Seçin',
                                style: TextStyle(fontSize: 14),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Bitiş Tarihi', style: TextStyle(fontSize: 12)),
                      SizedBox(height: 4),
                      InkWell(
                        onTap: () async {
                          final date = await showDatePicker(
                            context: context,
                            initialDate: _endDate ?? DateTime.now(),
                            firstDate: DateTime(2020),
                            lastDate: DateTime.now(),
                          );
                          if (date != null) {
                            setState(() => _endDate = date);
                            _applyFilters();
                          }
                        },
                        child: Container(
                          padding: EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.calendar_today, size: 16),
                              SizedBox(width: 8),
                              Text(
                                _endDate != null
                                    ? '${_endDate!.day}/${_endDate!.month}/${_endDate!.year}'
                                    : 'Tarih Seçin',
                                style: TextStyle(fontSize: 14),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _selectedStatus,
              decoration: InputDecoration(
                labelText: 'Denetim Durumu',
                border: OutlineInputBorder(),
              ),
              items: [
                DropdownMenuItem(value: 'all', child: Text('Tümü')),
                DropdownMenuItem(value: 'compliant', child: Text('Uygun')),
                DropdownMenuItem(value: 'conditional', child: Text('Şartlı Uygun')),
                DropdownMenuItem(value: 'non_compliant', child: Text('Uygun Değil')),
              ],
              onChanged: (value) {
                setState(() => _selectedStatus = value!);
                _applyFilters();
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsCards(Map<String, dynamic> stats) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          _buildStatCard('Toplam Denetim', stats['total'].toString(), Icons.assessment, Colors.blue),
          SizedBox(width: 12),
          _buildStatCard('Uygun', stats['compliant'].toString(), Icons.check_circle, Colors.green),
          SizedBox(width: 12),
          _buildStatCard('Uygun Değil', stats['nonCompliant'].toString(), Icons.warning, Colors.red),
          SizedBox(width: 12),
          _buildStatCard('Uyum Oranı', '${stats['complianceRate'].toStringAsFixed(1)}%',
              Icons.trending_up, Colors.orange),
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Card(
      elevation: 2,
      child: Container(
        width: 150,
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon, size: 30, color: color),
            SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 20,
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

  Widget _buildDetailedList() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Detaylı Liste (${_filteredInspections.length} denetim)',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ),
            ),
            SizedBox(height: 12),
            ..._filteredInspections.take(10).map((inspection) =>
                _buildInspectionItem(inspection)
            ).toList(),
            if (_filteredInspections.length > 10)
              Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  '... ve ${_filteredInspections.length - 10} denetim daha',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildInspectionItem(Map<String, dynamic> inspection) {
    final vehicle = inspection['vehicles'] ?? {};
    final status = inspection['status'] ?? 'compliant';
    final date = DateTime.parse(inspection['inspection_date']);

    Color getStatusColor(String status) {
      switch (status) {
        case 'compliant': return Colors.green;
        case 'conditional': return Colors.orange;
        case 'non_compliant': return Colors.red;
        default: return Colors.grey;
      }
    }

    String getStatusText(String status) {
      switch (status) {
        case 'compliant': return 'Uygun';
        case 'conditional': return 'Şartlı Uygun';
        case 'non_compliant': return 'Uygun Değil';
        default: return status;
      }
    }

    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: getStatusColor(status).withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          status == 'compliant' ? Icons.check_circle : Icons.warning,
          color: getStatusColor(status),
        ),
      ),
      title: Text(
        vehicle['plate'] ?? 'Plaka Yok',
        style: TextStyle(fontWeight: FontWeight.bold),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('${inspection['inspector_name']} • ${date.day}/${date.month}/${date.year}'),
          if (vehicle['model'] != null)
            Text(vehicle['model'], style: TextStyle(fontSize: 12)),
        ],
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            '${inspection['total_score']}/32',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: getStatusColor(status),
            ),
          ),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: getStatusColor(status).withOpacity(0.1),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              getStatusText(status),
              style: TextStyle(
                fontSize: 10,
                color: getStatusColor(status),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}