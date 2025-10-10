import 'package:flutter/material.dart';
import '/services/database_service.dart';

class InspectionFormScreen extends StatefulWidget {
  final String vehiclePlate;

  const InspectionFormScreen({Key? key, required this.vehiclePlate}) : super(key: key);

  @override
  _InspectionFormScreenState createState() => _InspectionFormScreenState();
}

class _InspectionFormScreenState extends State<InspectionFormScreen> {
  final DatabaseService _dbService = DatabaseService();
  bool _isSubmitting = false;

  // Kategori bazlı denetim maddeleri - SÜRELİ EVRAKLAR EKLENDİ
  final List<InspectionCategory> _inspectionCategories = [
    InspectionCategory(
      name: 'Sürücü',
      items: [
        InspectionItem(
          id: 1,
          question: "Araç Sürücüsü Yeterli sürücü Belgesine Sahip mi? (D,E5-D1,B7)",
          description: "D sınıfı sürücü belgesi için en az beş yıllık, D1 sınıfı sürücü belgesi için en az yedi yıllık sürücü belgesine sahip olmak",
          hasDateField: true,
          dateFieldLabel: "Ehliyet Geçerlilik Tarihi",
        ),
        InspectionItem(
          id: 2,
          question: "Araç sürücüsünün yaşı uygun mu?",
          description: "26 yaşından gün almış 66 yaşından gün almamış olmak",
        ),
        InspectionItem(
          id: 3,
          question: "Araç sürücüsü SRC1-SRC2 Belgesi var mı?",
          description: "",
          hasDateField: true,
          dateFieldLabel: "SRC Belge Geçerlilik Tarihi",
        ),
        InspectionItem(
          id: 4,
          question: "Sürücünün kıyafeti uygun mu?",
          description: "",
        ),
        InspectionItem(
          id: 5,
          question: "Sürücü 'Öğrenci Yoklama Defteri' tutuyor mu?",
          description: "",
        ),
      ],
    ),
    InspectionCategory(
      name: 'Rehber',
      items: [
        InspectionItem(
          id: 6,
          question: "Rehber personel yaşı uygun mu?",
          description: "22 yaşını doldurmuş ve 61 yaşından gün almamış olmak",
        ),
        InspectionItem(
          id: 7,
          question: "Rehber personel standart ikaz yeleği giymiş mi?",
          description: "TS EN ISO 20471 standartlara uygun, sarı renkte reflektif yelek",
        ),
        InspectionItem(
          id: 8,
          question: "Rehber Personelde yardımcı ışıklar bulunuyor mu?",
          description: "Işıklı çubuk, dur-geç levhası gibi",
        ),
      ],
    ),
    InspectionCategory(
      name: 'Araç Belgeleri',
      items: [
        InspectionItem(
          id: 9,
          question: "Araçta tanıtım kartı mevcut mu?",
          description: "",
        ),
        InspectionItem(
          id: 25,
          question: "Zorunlu Mali ve Koltuk Sigortası yapılmış mı?",
          description: "Bitiş tarihlerine dikkat edilecek",
          hasDateField: true,
          dateFieldLabel: "Sigorta Bitiş Tarihi",
          isCriticalDate: true,
        ),
        InspectionItem(
          id: 26,
          question: "Aracın muayenesi yapılmış mı?",
          description: "Bitiş tarihine dikkat edilecek",
          hasDateField: true,
          dateFieldLabel: "Muayene Bitiş Tarihi",
          isCriticalDate: true,
        ),
        InspectionItem(
          id: 31,
          question: "Güzergah izin belgesi var mı?",
          description: "Özel Servis",
          hasDateField: true,
          dateFieldLabel: "İzin Belgesi Bitiş Tarihi",
        ),
        InspectionItem(
          id: 32,
          question: "Farklı İlden geliyorsa G Belgesi var mı?",
          description: "Özel Servis",
          hasDateField: true,
          dateFieldLabel: "G Belgesi Bitiş Tarihi",
        ),
      ],
    ),
    InspectionCategory(
      name: 'Araç Durumu',
      items: [
        InspectionItem(
          id: 10,
          question: "Servis aracının yaşı 15'ten küçük mü?",
          description: "Fabrikasınca imal edildiği tarihten sonra gelen ilk takvim yılı esas alınacak",
        ),
        InspectionItem(
          id: 11,
          question: "DUR lambası tesis edilmiş mi?",
          description: "En az 30 cm çapında kırmızı ışık veren lamba ve DUR yazısı",
        ),
        InspectionItem(
          id: 12,
          question: "Aracın arkasında 'OKUL TAŞITI' yazısı var mı?",
          description: "Standartlara uygun şekilde",
        ),
        InspectionItem(
          id: 29,
          question: "Araç arkasında İlçe MEM numarası var mı?",
          description: "",
        ),
      ],
    ),
    InspectionCategory(
      name: 'Araç İç Düzen',
      items: [
        InspectionItem(
          id: 13,
          question: "Cam ve çerçeveler sabit mi? İç aksam kaplanmış mı?",
          description: "Demir aksamlar yumuşak madde ile kaplanmış mı?",
        ),
        InspectionItem(
          id: 14,
          question: "Araç kapıları otomatik veya mekanik mi?",
          description: "Sürücü tarafından açılıp kapatılabilecek şekilde",
        ),
        InspectionItem(
          id: 15,
          question: "Isıtma ve soğutma sistemi çalışıyor mu?",
          description: "",
        ),
        InspectionItem(
          id: 20,
          question: "Beyaz cam dışında renkli cam kullanılmış mı?",
          description: "",
        ),
        InspectionItem(
          id: 27,
          question: "Oturma kapasitesi listesi asılı mı?",
          description: "",
        ),
        InspectionItem(
          id: 28,
          question: "Taşınan öğrenci listesi asılı mı?",
          description: "",
        ),
      ],
    ),
    InspectionCategory(
      name: 'Araç Donanım',
      items: [
        InspectionItem(
          id: 16,
          question: "Araç geri vites sireni mevcut mu?",
          description: "",
        ),
        InspectionItem(
          id: 17,
          question: "Araç takip sistemi var ve çalışıyor mu?",
          description: "Kayıtlar en az otuz gün muhafaza edilecek",
        ),
        InspectionItem(
          id: 18,
          question: "İç-dış kamera sistemi var ve çalışıyor mu?",
          description: "1/1/2018 öncesi araçlarda aranmaz",
        ),
        InspectionItem(
          id: 19,
          question: "Oturmaya duyarlı sensör çalışıyor mu?",
          description: "1/1/2018 öncesi araçlarda aranmaz",
        ),
      ],
    ),
    InspectionCategory(
      name: 'Güvenlik',
      items: [
        InspectionItem(
          id: 21,
          question: "Her öğrenci için emniyet kemeri var mı?",
          description: "1/1/2018 sonrası araçlarda üç nokta emniyet kemeri şartı",
        ),
        InspectionItem(
          id: 22,
          question: "İlkyardım Çantası ve Trafik Seti var mı?",
          description: "",
        ),
        InspectionItem(
          id: 23,
          question: "Yangın söndürme tüpü var ve bakımlı mı?",
          description: "",
          hasDateField: true,
          dateFieldLabel: "Yangın Tüpü Dolum/Kontrol Tarihi",
          isCriticalDate: true,
        ),
      ],
    ),
    InspectionCategory(
      name: 'Bakım',
      items: [
        InspectionItem(
          id: 24,
          question: "6 aylık periyodik bakım yapılıyor mu?",
          description: "Aracın temizliği, tertip düzeni iyi mi?",
          hasDateField: true,
          dateFieldLabel: "Son Bakım Tarihi",
        ),
      ],
    ),
    InspectionCategory(
      name: 'Diğer',
      items: [
        InspectionItem(
          id: 30,
          question: "Araç öğrenci dışında yolcu/yük taşıyor mu?",
          description: "",
          reverseScoring: true,
        ),
      ],
    ),
  ];

  int get _totalItems {
    return _inspectionCategories.fold(0, (sum, category) => sum + category.items.length);
  }

  int get _completedItems {
    return _inspectionCategories.fold(0, (sum, category) =>
    sum + category.items.where((item) => item.isCompliant != null).length
    );
  }

  int get _compliantItems {
    return _inspectionCategories.fold(0, (sum, category) =>
    sum + category.items.where((item) => item.isCompliant == true).length
    );
  }

  // Kritik tarih kontrolü
  int get _criticalItemsCount {
    return _inspectionCategories.fold(0, (sum, category) =>
    sum + category.items.where((item) => item.isCriticalDate == true).length
    );
  }

  int get _expiredItemsCount {
    final now = DateTime.now();
    return _inspectionCategories.fold(0, (sum, category) =>
    sum + category.items.where((item) =>
    item.isCriticalDate == true &&
        item.selectedDate != null &&
        item.selectedDate!.isBefore(now)
    ).length
    );
  }

  void _answerQuestion(InspectionItem item, bool isCompliant) {
    setState(() {
      item.isCompliant = isCompliant;
      if (!isCompliant) {
        item.explanation = "";
      }
    });
  }

  // Tarih seçim fonksiyonu
  void _selectDate(InspectionItem item) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: item.selectedDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );

    if (picked != null) {
      setState(() {
        item.selectedDate = picked;
      });
    }
  }

  // Tarih durumuna göre renk döndür
  Color _getDateStatusColor(DateTime? date, bool isCritical) {
    if (date == null) return Colors.grey;

    final now = DateTime.now();
    final difference = date.difference(now).inDays;

    if (!isCritical) return Colors.blue;

    if (date.isBefore(now)) return Colors.red;
    if (difference <= 30) return Colors.orange;
    if (difference <= 90) return Colors.yellow[700]!;
    return Colors.green;
  }

  // Tarih durumuna göre metin döndür
  String _getDateStatusText(DateTime? date, bool isCritical) {
    if (date == null) return 'Tarih seçilmedi';

    final now = DateTime.now();
    final difference = date.difference(now).inDays;

    if (!isCritical) return '${date.day}/${date.month}/${date.year}';

    if (date.isBefore(now)) return 'SÜRESİ DOLMUŞ!';
    if (difference <= 30) return '${difference} gün kaldı';
    if (difference <= 90) return '${difference} gün kaldı';
    return '${difference} gün kaldı';
  }

  void _submitInspection() async {
    // Tüm soruların cevaplandığını kontrol et
    final unansweredItems = _inspectionCategories
        .expand((category) => category.items)
        .where((item) => item.isCompliant == null)
        .toList();

    if (unansweredItems.isNotEmpty) {
      _showSnackBar('Lütfen tüm soruları yanıtlayın! (${unansweredItems.length} soru kaldı)', Colors.orange);
      return;
    }

    // Kritik tarih uyarıları
    final now = DateTime.now();
    final criticalItems = _inspectionCategories
        .expand((category) => category.items)
        .where((item) => item.isCriticalDate && item.selectedDate != null)
        .toList();

    final expiredItems = criticalItems.where((item) => item.selectedDate!.isBefore(now)).toList();
    final expiringItems = criticalItems.where((item) =>
    item.selectedDate!.isAfter(now) &&
        item.selectedDate!.difference(now).inDays <= 30
    ).toList();

    // Uyarı mesajı göster (opsiyonel - kullanıcı onayı isteyebilirsiniz)
    if (expiredItems.isNotEmpty || expiringItems.isNotEmpty) {
      String warningMessage = '';
      if (expiredItems.isNotEmpty) {
        warningMessage += '${expiredItems.length} adet süresi dolmuş evrak!\n';
      }
      if (expiringItems.isNotEmpty) {
        warningMessage += '${expiringItems.length} adet süresi dolmak üzere olan evrak!\n';
      }

      _showSnackBar(warningMessage + 'Yine de kaydetmek istiyor musunuz?', Colors.orange);
      // Burada kullanıcı onayı isteyebilirsiniz
    }

    setState(() => _isSubmitting = true);

    try {
      // Tüm maddeleri topla
      final allItems = _inspectionCategories.expand((category) => category.items).toList();
      final inspectionData = allItems.map((item) => {
        'item_number': item.id,
        'question': item.question,
        'is_compliant': item.isCompliant,
        'explanation': item.isCompliant == false ? item.explanation : null,
        'selected_date': item.selectedDate?.toIso8601String(),
        'date_field_label': item.dateFieldLabel,
        'is_critical_date': item.isCriticalDate,
      }).toList();

      // Supabase'e kaydet
      await _dbService.createInspection(
        vehiclePlate: widget.vehiclePlate,
        inspectorName: 'Ahmet Bey', // TODO: Gerçek kullanıcı adı
        inspectionItems: inspectionData,
      );

      _showSnackBar('✅ Denetim başarıyla kaydedildi!\nUygun: $_compliantItems/$_totalItems', Colors.green);

      // 2 saniye bekleyip ana sayfaya dön
      await Future.delayed(Duration(seconds: 2));
      Navigator.popUntil(context, (route) => route.isFirst);

    } catch (e) {
      _showSnackBar('❌ Hata: $e', Colors.red);
    } finally {
      setState(() => _isSubmitting = false);
    }
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        duration: Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Color(0xFFE3F2FD),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Denetim Formu',
              style: TextStyle(
                color: Color(0xFF2196F3),
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
            Text(
              widget.vehiclePlate,
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 14,
              ),
            ),
          ],
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Color(0xFF2196F3)),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          Padding(
            padding: EdgeInsets.all(8.0),
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Color(0xFF2196F3)),
              ),
              child: Text(
                '$_compliantItems/$_totalItems',
                style: TextStyle(
                  color: Color(0xFF2196F3),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // İlerleme Çubuğu
          Container(
            height: 4,
            child: LinearProgressIndicator(
              value: _totalItems > 0 ? _completedItems / _totalItems : 0,
              backgroundColor: Colors.grey[300],
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF2196F3)),
            ),
          ),

          // İstatistik Kartı - KRİTİK TARİHLER EKLENDİ
          Container(
            padding: EdgeInsets.all(16),
            color: Colors.white,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatCard('Tamamlanan', '$_completedItems/$_totalItems', Colors.blue),
                _buildStatCard('Uygun', '$_compliantItems', Colors.green),
                _buildStatCard('Kritik', '$_expiredItemsCount/$_criticalItemsCount',
                    _expiredItemsCount > 0 ? Colors.red : Colors.orange),
              ],
            ),
          ),

          // Kategori Listesi
          Expanded(
            child: SingleChildScrollView(
              physics: AlwaysScrollableScrollPhysics(),
              child: ListView.builder(
                shrinkWrap: true,
                physics: NeverScrollableScrollPhysics(),
                itemCount: _inspectionCategories.length,
                itemBuilder: (context, categoryIndex) {
                  final category = _inspectionCategories[categoryIndex];
                  return _buildCategoryCard(category);
                },
              ),
            ),
          ),

          // Kaydet Butonu
          Container(
            padding: EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(
                top: BorderSide(color: Colors.grey[300]!),
              ),
            ),
            child: SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _submitInspection,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xFF2196F3),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  disabledBackgroundColor: Colors.grey[400],
                ),
                child: _isSubmitting
                    ? Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    SizedBox(width: 10),
                    Text('Kaydediliyor...'),
                  ],
                )
                    : Text(
                  'DENETİMİ TAMAMLA',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, String value, Color color) {
    return Column(
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
        SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildCategoryCard(InspectionCategory category) {
    final completedInCategory = category.items.where((item) => item.isCompliant != null).length;
    final totalInCategory = category.items.length;

    return Card(
      margin: EdgeInsets.all(8),
      elevation: 2,
      child: ExpansionTile(
        leading: Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: Color(0xFFE3F2FD),
            borderRadius: BorderRadius.circular(15),
          ),
          child: Center(
            child: Text(
              '$completedInCategory/$totalInCategory',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Color(0xFF2196F3),
              ),
            ),
          ),
        ),
        title: Text(
          category.name,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.grey[800],
          ),
        ),
        children: category.items.map((item) => _buildQuestionItem(item)).toList(),
      ),
    );
  }

  Widget _buildQuestionItem(InspectionItem item) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Soru Numarası ve Metni
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Color(0xFFE3F2FD),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '${item.id}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2196F3),
                  ),
                ),
              ),
              SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.question,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey[800],
                      ),
                    ),
                    if (item.description.isNotEmpty) ...[
                      SizedBox(height: 4),
                      Text(
                        item.description,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),

          SizedBox(height: 12),

          // Tarih Alanı (Eğer varsa)
          if (item.hasDateField) _buildDateField(item),

          // Cevap Butonları
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 40,
                  child: ElevatedButton(
                    onPressed: () => _answerQuestion(item, item.reverseScoring ? false : true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: item.isCompliant == true
                          ? Color(0xFF4CAF50)
                          : Colors.grey[300],
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.check_circle,
                          size: 18,
                          color: item.isCompliant == true ? Colors.white : Colors.grey,
                        ),
                        SizedBox(width: 4),
                        Text(
                          'UYGUN',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: item.isCompliant == true ? Colors.white : Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              SizedBox(width: 8),
              Expanded(
                child: SizedBox(
                  height: 40,
                  child: ElevatedButton(
                    onPressed: () => _answerQuestion(item, item.reverseScoring ? true : false),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: item.isCompliant == false
                          ? Color(0xFFF44336)
                          : Colors.grey[300],
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.cancel,
                          size: 18,
                          color: item.isCompliant == false ? Colors.white : Colors.grey,
                        ),
                        SizedBox(width: 4),
                        Text(
                          'UYGUN DEĞİL',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: item.isCompliant == false ? Colors.white : Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),

          // Açıklama Alanı (Uygun değilse)
          if (item.isCompliant == false) ...[
            SizedBox(height: 12),
            TextField(
              onChanged: (value) {
                setState(() {
                  item.explanation = value;
                });
              },
              decoration: InputDecoration(
                hintText: 'Uygunsuzluk sebebini açıklayınız...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              maxLines: 2,
            ),
            SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              height: 36,
              child: OutlinedButton.icon(
                onPressed: () {
                  _showSnackBar('Fotoğraf özelliği yakında eklenecek', Colors.blue);
                },
                icon: Icon(Icons.camera_alt, size: 16),
                label: Text('FOTOĞRAF EKLE'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Color(0xFF2196F3),
                  side: BorderSide(color: Color(0xFF2196F3)),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDateField(InspectionItem item) {
    return Container(
      margin: EdgeInsets.only(bottom: 12),
      padding: EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: _getDateStatusColor(item.selectedDate, item.isCriticalDate),
          width: 2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            item.dateFieldLabel!,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Colors.grey[700],
            ),
          ),
          SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 36,
                  child: OutlinedButton(
                    onPressed: () => _selectDate(item),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _getDateStatusColor(item.selectedDate, item.isCriticalDate),
                      side: BorderSide(color: _getDateStatusColor(item.selectedDate, item.isCriticalDate)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.calendar_today, size: 16),
                        SizedBox(width: 4),
                        Text(
                          item.selectedDate != null
                              ? '${item.selectedDate!.day}/${item.selectedDate!.month}/${item.selectedDate!.year}'
                              : 'Tarih Seçin',
                          style: TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              SizedBox(width: 8),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _getDateStatusColor(item.selectedDate, item.isCriticalDate),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  _getDateStatusText(item.selectedDate, item.isCriticalDate),
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class InspectionCategory {
  final String name;
  final List<InspectionItem> items;

  InspectionCategory({required this.name, required this.items});
}

class InspectionItem {
  final int id;
  final String question;
  final String description;
  bool? isCompliant;
  String explanation;
  final bool reverseScoring;

  // YENİ ALANLAR: Süreli evrak takibi için
  final bool hasDateField;
  final String? dateFieldLabel;
  final bool isCriticalDate;
  DateTime? selectedDate;

  InspectionItem({
    required this.id,
    required this.question,
    required this.description,
    this.isCompliant,
    this.explanation = '',
    this.reverseScoring = false,
    this.hasDateField = false,
    this.dateFieldLabel,
    this.isCriticalDate = false,
    this.selectedDate,
  });
}