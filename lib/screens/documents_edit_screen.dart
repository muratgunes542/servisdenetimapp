//documents_edit_screen.dart
import 'package:flutter/material.dart';
import '/services/database_service.dart';
import '/utils/constants.dart';

class DocumentsEditScreen extends StatefulWidget {
  final Map<String, dynamic> vehicle;
  final Map<String, dynamic>? documentsData;

  const DocumentsEditScreen({
    Key? key,
    required this.vehicle,
    this.documentsData,
  }) : super(key: key);

  @override
  _DocumentsEditScreenState createState() => _DocumentsEditScreenState();
}

class _DocumentsEditScreenState extends State<DocumentsEditScreen> {
  final DatabaseService _dbService = DatabaseService();

  DateTime? _insuranceExpiry;
  DateTime? _inspectionExpiry;
  DateTime? _routePermitExpiry;
  DateTime? _gCertificateExpiry;
  DateTime? _fireExtinguisherExpiry;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _initializeForm();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final data = await _dbService.getDriverByVehicleId(widget.vehicle['id']);
      if (data != null) {
        setState(() {
          // Verileri form alanlarına yükle
        });
      }
    } catch (e) {
      print('Veri yükleme hatası: $e');
    }
  }

  void _initializeForm() {
    if (widget.documentsData != null) {
      if (widget.documentsData!['insurance_expiry'] != null) {
        _insuranceExpiry = DateTime.parse(widget.documentsData!['insurance_expiry']);
      }
      if (widget.documentsData!['inspection_expiry'] != null) {
        _inspectionExpiry = DateTime.parse(widget.documentsData!['inspection_expiry']);
      }
      if (widget.documentsData!['route_permission_expiry'] != null) {
        _routePermitExpiry = DateTime.parse(widget.documentsData!['route_permission_expiry']);
      }
      if (widget.documentsData!['g_certificate_expiry'] != null) {
        _gCertificateExpiry = DateTime.parse(widget.documentsData!['g_certificate_expiry']);
      }
      if (widget.documentsData!['fire_extinguisher_expiry'] != null) {
        _fireExtinguisherExpiry = DateTime.parse(widget.documentsData!['fire_extinguisher_expiry']);
      }
    }
  }

  Future<void> _selectDate(BuildContext context, DateTime? initialDate, Function(DateTime) onSelected) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initialDate ?? DateTime.now().add(Duration(days: 365)), // 1 yıl sonrası
      firstDate: DateTime(2000), // 2000'den itibaren
      lastDate: DateTime(2100), // 2100'e kadar
    );
    if (picked != null) {
      onSelected(picked);
    }
  }

  Widget _buildDocumentCard(String title, String description, DateTime? selectedDate, Function(DateTime) onDateSelected, bool isCritical) {
    final isExpired = selectedDate != null && selectedDate.isBefore(DateTime.now());

    return Card(
      elevation: 2,
      color: isExpired ? Color(0xFFFFEBEE) : (isCritical ? Color(0xFFFFF3E0) : Colors.white),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  isExpired ? Icons.error :
                  (isCritical ? Icons.warning : Icons.description),
                  color: isExpired ? Colors.red :
                  (isCritical ? Colors.orange : Colors.green),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: isExpired ? Colors.red :
                          (isCritical ? Colors.orange : Colors.green),
                        ),
                      ),
                      if (description.isNotEmpty) ...[
                        SizedBox(height: 4),
                        Text(
                          description,
                          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                        ),
                      ],
                    ],
                  ),
                ),
                if (isExpired)
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      'SÜRESİ DOLMUŞ',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
            SizedBox(height: 12),
            InkWell(
              onTap: () => _selectDate(context, selectedDate, onDateSelected),
              child: Container(
                width: double.infinity,
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey[300]!),
                  borderRadius: BorderRadius.circular(8),
                  color: Colors.white,
                ),
                child: Row(
                  children: [
                    Icon(Icons.calendar_today, size: 18, color: Colors.grey[600]),
                    SizedBox(width: 12),
                    Text(
                      selectedDate != null
                          ? '${selectedDate.day}/${selectedDate.month}/${selectedDate.year}'
                          : 'Tarih seçin...',
                      style: TextStyle(
                        color: selectedDate != null ? Colors.black : Colors.grey,
                      ),
                    ),
                    Spacer(),
                    if (selectedDate != null)
                      Text(
                        _calculateDaysRemaining(selectedDate),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: isExpired ? Colors.red : Colors.green,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _calculateDaysRemaining(DateTime date) {
    final now = DateTime.now();
    final difference = date.difference(now).inDays;

    if (date.isBefore(now)) {
      return '${difference.abs()} gün geçmiş';
    } else if (difference <= 30) {
      return '$difference gün kaldı';
    } else {
      return '${(difference / 30).round()} ay kaldı';
    }
  }

  Future<void> _saveDocuments() async {
    setState(() => _isSubmitting = true);

    try {
      final documentsData = {
        'vehicle_id': widget.vehicle['id'],
        'insurance_expiry': _insuranceExpiry?.toIso8601String(),
        'inspection_expiry': _inspectionExpiry?.toIso8601String(),
        'route_permission_expiry': _routePermitExpiry?.toIso8601String(),
        'g_certificate_expiry': _gCertificateExpiry?.toIso8601String(),
        'fire_extinguisher_expiry': _fireExtinguisherExpiry?.toIso8601String(),
      };

      // Database'e kaydet
      await _dbService.saveDocuments(documentsData);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Belge bilgileri başarıyla kaydedildi'),
          backgroundColor: Colors.green,
        ),
      );

      Navigator.pop(context, true);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Kayıt hatası: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Araç Belgeleri'),
        backgroundColor: Color(0xFFFF9800),
        actions: [
          if (_isSubmitting)
            Padding(
              padding: EdgeInsets.only(right: 16),
              child: Center(child: CircularProgressIndicator(color: Colors.white)),
            )
          else
            IconButton(
              icon: Icon(Icons.save),
              onPressed: _saveDocuments,
            ),
        ],
      ),
      body: _isSubmitting
          ? _buildLoading()
          : Padding(
        padding: EdgeInsets.all(16),
        child: ListView(
          children: [
            // Kritik Belgeler
            Text(
              'Kritik Belgeler *',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text(
              'Bu belgelerin süresi dolmuşsa araç trafiğe çıkamaz',
              style: TextStyle(color: Colors.red, fontSize: 12),
            ),
            SizedBox(height: 16),

            // Sigorta
            _buildDocumentCard(
              'Sigorta',
              'Zorunlu Mali Sorumluluk Sigortası',
              _insuranceExpiry,
                  (date) => setState(() => _insuranceExpiry = date),
              true,
            ),
            SizedBox(height: 12),

            // Muayene
            _buildDocumentCard(
              'Araç Muayenesi',
              'Periyodik araç muayenesi',
              _inspectionExpiry,
                  (date) => setState(() => _inspectionExpiry = date),
              true,
            ),
            SizedBox(height: 12),

            // Yangın Tüpü
            _buildDocumentCard(
              'Yangın Tüpü Kontrolü',
              'Yangın söndürme tüpü dolum/kontrol tarihi',
              _fireExtinguisherExpiry,
                  (date) => setState(() => _fireExtinguisherExpiry = date),
              true,
            ),
            SizedBox(height: 24),

            // Diğer Belgeler (Özel Taşıma)
            if (widget.vehicle['transport_type'] == 'private') ...[
              _buildDocumentCard(
                'Güzergah İzin Belgesi',
                'Özel servis güzergah izni - MEB onaylı',
                _routePermitExpiry,
                    (date) => setState(() => _routePermitExpiry = date),
                true, // Kritik belge
              ),
              SizedBox(height: 12),

              _buildDocumentCard(
                'G Belgesi',
                'Farklı ilden öğrenci taşımacılığı belgesi',
                _gCertificateExpiry,
                    (date) => setState(() => _gCertificateExpiry = date),
                false,
              ),
              SizedBox(height: 12),
            ],

            // Kaydet Butonu
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _saveDocuments,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xFFFF9800),
                ),
                child: Text(
                  'KAYDET',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoading() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text('Kaydediliyor...'),
        ],
      ),
    );
  }
}