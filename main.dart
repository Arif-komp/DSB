import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:provider/provider.dart';
import 'package:fluttertoast/fluttertoast.dart';

// =================================================================
// 1. DATA MODEL
// =================================================================

class ProductData {
  final String namaBarang;
  final String jenisProduk;
  final String kategori;
  final String lokasi;

  ProductData({
    required this.namaBarang,
    required this.jenisProduk,
    required this.kategori,
    required this.lokasi,
  });

  @override
  String toString() {
    return 'Nama: $namaBarang, Jenis: $jenisProduk, Kategori: $kategori, Lokasi: $lokasi';
  }
}

// =================================================================
// 2. STATE MANAGEMENT (Provider)
// =================================================================

class InventoryProvider extends ChangeNotifier {
  // 🔥 Ganti dengan ID Spreadsheet Anda
  final String spreadsheetId = '1Qii4ejSlHgnv_zGhY7jPaddAgfbDVAFFsavTCD8Kg7A';
  // Ganti dengan SCRIPT_URL yang benar untuk doGet/doPost
  // Menggunakan URL Apps Script yang ada:
  final String scriptUrl = 'https://script.google.com/macros/s/AKfycbw3EfBNy5bxshJddoSrPWx4feDc3gj2QvyKML-92ScCt8E38Pa-lO1RHsc_JOlDs2TQ/exec'; 

  Map<String, Map<String, List<String>>> _inventoryDataCache = {};
  List<ProductData> _flatInventoryData = [];
  String _activeUser = 'ADMIN'; // Ganti dengan login user
  String _currentMode = 'Masuk';
  String _currentCategory = '';
  bool _isLoading = false;

  Map<String, Map<String, List<String>>> get inventoryDataCache => _inventoryDataCache;
  List<ProductData> get flatInventoryData => _flatInventoryData;
  String get activeUser => _activeUser;
  String get currentMode => _currentMode;
  String get currentCategory => _currentCategory;
  bool get isLoading => _isLoading;

  void setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void setActiveUser(String user) {
    _activeUser = user.toUpperCase();
    notifyListeners();
  }

  void toggleMode() {
    _currentMode = (_currentMode == 'Masuk') ? 'Keluar' : 'Masuk';
    notifyListeners();
  }

  void selectCategory(String category) {
    if (_currentCategory != category) {
      _currentCategory = category;
      notifyListeners();
    }
  }

  // Fungsi untuk mendapatkan data dari Apps Script (doGet)
  Future<void> fetchProductData() async {
    setLoading(true);
    try {
      // Menggunakan JSONP untuk Apps Script Anda (tidak ideal, tapi sesuai format JS Anda)
      final url = Uri.parse('$scriptUrl?callback=handleProductData');
      final response = await http.get(url);

      // Memproses respons JSONP
      if (response.statusCode == 200) {
        String body = response.body;
        // Hapus handleProductData( dan );
        body = body.substring(body.indexOf('(') + 1, body.lastIndexOf(')'));
        final Map<String, dynamic> jsonResponse = json.decode(body);

        if (jsonResponse['status'] == 'ok' && jsonResponse['data'] is Map) {
          _inventoryDataCache = _transformDataToUppercase(jsonResponse['data']);
          _flattenInventoryData();
          Fluttertoast.showToast(msg: "Data produk dimuat.", toastLength: Toast.LENGTH_SHORT);
        } else {
          throw Exception('Gagal memuat data: ${jsonResponse['error']}');
        }
      } else {
        throw Exception('Gagal terkoneksi ke Apps Script: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching data: $e');
      Fluttertoast.showToast(msg: "❌ Gagal memuat data: $e", toastLength: Toast.LENGTH_LONG);
    } finally {
      setLoading(false);
    }
  }

  // Fungsi untuk memproses data dari Apps Script agar mudah dicari
  Map<String, Map<String, List<String>>> _transformDataToUppercase(Map<String, dynamic> data) {
    final transformed = <String, Map<String, List<String>>>{};
    data.forEach((catKey, typeMap) {
      final categoryKey = catKey.toUpperCase();
      transformed[categoryKey] = {};
      if (typeMap is Map) {
        typeMap.forEach((typeKey, productList) {
          final typeUppercase = typeKey.toUpperCase();
          if (productList is List) {
            transformed[categoryKey]![typeUppercase] = productList.map((name) => name.toString().toUpperCase()).toList();
          } else {
            transformed[categoryKey]![typeUppercase] = [];
          }
        });
      }
    });
    return transformed;
  }

  // Fungsi untuk meratakan data menjadi list untuk pencarian cepat
  void _flattenInventoryData() {
    _flatInventoryData.clear();
    _inventoryDataCache.forEach((kategori, jenisMap) {
      jenisMap.forEach((jenisProduk, namaList) {
        namaList.forEach((namaBarang) {
          // Menghilangkan nama barang yang tidak terpakai
          if (!_isExcluded(namaBarang)) {
             _flatInventoryData.add(ProductData(
              namaBarang: namaBarang,
              jenisProduk: jenisProduk,
              kategori: kategori,
              lokasi: _extractLokasi(namaBarang), // Lokasi akan diekstrak dari Nama Barang
            ));
          }
        });
      });
    });
  }

  // Implementasi Logika Lokasi Otomatis/Cerdas
  // Untuk Keramik, kita asumsikan Jenis Produk adalah 'Ukuran' dan Lokasi adalah 'Pola'
  // atau kita ambil dari nama barang secara heuristik (karena data sheet tidak detail)
  String _extractLokasi(String namaBarang) {
    // Implementasi Dummy: ambil kata setelah '/' pertama dan sebelum '/' kedua, atau kata pertama
    final parts = namaBarang.split('/').map((e) => e.trim()).toList();
    if (parts.length > 2) {
      return parts[1]; // Misal: 'AS ALPHA BLACK 20X20' dari 'STP/ AS ALPHA BLACK 20X20 /145'
    } else if (parts.isNotEmpty) {
      return parts[0].split(' ').first; // Jika tidak ada '/', ambil kata pertama sebagai lokasi (dummy)
    }
    return '';
  }
  
  bool _isExcluded(String productName) {
    const excludedKeywords = ['STP/', 'DBL/', 'DEL/', 'F/', 'D/', 'TIDAK DIPAKAI', 'TIDAK DIGUNAKAN', 'NON AKTIF'];
    return excludedKeywords.any((keyword) => productName.contains(keyword));
  }

  // Logika pencarian cerdas untuk KERAMIK (Kategori = Lokasi)
  List<ProductData> searchProductsByLocation(String locationInput) {
    final input = locationInput.toUpperCase().trim();
    if (input.isEmpty) return [];

    // Filter produk KERAMIK berdasarkan lokasi (yang diekstrak dari nama barang)
    // dan kelompokkan yang duplikat
    final matches = _flatInventoryData.where((p) =>
        p.kategori == 'KERAMIK' && p.lokasi.contains(input)).toList();

    return matches;
  }

  // Fungsi POST untuk menyimpan data (doPost)
  Future<Map<String, dynamic>> submitTransaction(Map<String, String> data) async {
    setLoading(true);
    try {
      final url = Uri.parse(scriptUrl);
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: data,
      );

      setLoading(false);

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        return {'status': 'error', 'error': 'Server error: ${response.statusCode}'};
      }
    } catch (e) {
      setLoading(false);
      return {'status': 'error', 'error': 'Jaringan error: $e'};
    }
  }
}

// =================================================================
// 3. UI/UX
// =================================================================

void main() {
  runApp(
    ChangeNotifierProvider(
      create: (context) => InventoryProvider(),
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DEPO SB - INVENTORY',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        fontFamily: 'Poppins',
        visualDensity: VisualDensity.adaptivePlatformDensity,
        colorScheme: ColorScheme.fromSwatch(primarySwatch: Colors.teal).copyWith(secondary: Colors.redAccent),
      ),
      home: const InventoryScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _lokasiController = TextEditingController();
  final TextEditingController _jumlahController = TextEditingController();
  final TextEditingController _keteranganController = TextEditingController();
  final TextEditingController _jenisProdukKeramikController = TextEditingController();
  final TextEditingController _namaBarangController = TextEditingController();

  String? _selectedJenisProdukDropdown;

  // Fokus Node untuk perpindahan otomatis
  final FocusNode _lokasiFocus = FocusNode();
  final FocusNode _namaBarangFocus = FocusNode();
  final FocusNode _jumlahFocus = FocusNode();
  final FocusNode _keteranganFocus = FocusNode();


  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<InventoryProvider>(context, listen: false).fetchProductData();
      Provider.of<InventoryProvider>(context, listen: false).setActiveUser('ADMIN'); // Ganti dengan logika login
    });
  }

  @override
  void dispose() {
    _lokasiController.dispose();
    _jumlahController.dispose();
    _keteranganController.dispose();
    _jenisProdukKeramikController.dispose();
    _namaBarangController.dispose();
    _lokasiFocus.dispose();
    _namaBarangFocus.dispose();
    _jumlahFocus.dispose();
    _keteranganFocus.dispose();
    super.dispose();
  }

  // Fungsi untuk mengosongkan form
  void _resetForm() {
    _lokasiController.clear();
    _jumlahController.clear();
    _keteranganController.clear();
    _jenisProdukKeramikController.clear();
    _namaBarangController.clear();
    _selectedJenisProdukDropdown = null;
    setState(() {});
  }

  // Fungsi untuk menanggapi pemilihan nama barang cerdas (KERAMIK)
  void _handleProductSelection(ProductData selectedProduct) {
    _namaBarangController.text = selectedProduct.namaBarang;
    // Mengisi Jenis Produk otomatis
    _jenisProdukKeramikController.text = selectedProduct.jenisProduk;
    
    // Pindah fokus ke Jumlah
    FocusScope.of(context).requestFocus(_jumlahFocus);
  }
  
  // Fungsi Submit
  Future<void> _submitTransaction(String action) async {
    final provider = Provider.of<InventoryProvider>(context, listen: false);

    if (!_formKey.currentState!.validate()) {
      Fluttertoast.showToast(msg: "❌ Lengkapi semua kolom wajib.", toastLength: Toast.LENGTH_SHORT);
      return;
    }
    
    // Tentukan Jenis Produk mana yang akan dikirim (dropdown atau search input)
    final jenisProdukToSend = provider.currentCategory == 'KERAMIK'
        ? _jenisProdukKeramikController.text.trim()
        : (_selectedJenisProdukDropdown ?? '').trim();
    
    if (jenisProdukToSend.isEmpty) {
       Fluttertoast.showToast(msg: "❌ Jenis Produk harus diisi.", toastLength: Toast.LENGTH_SHORT);
       return;
    }

    final dataToSend = {
      'kategori': provider.currentCategory,
      'jenisProduk': jenisProdukToSend,
      'namaBarang': _namaBarangController.text.trim(),
      'checker': provider.activeUser,
      'lokasi': _lokasiController.text.trim(),
      'formatSimpan': _keteranganController.text.trim(), // Keterangan dijadikan formatSimpan
      'masukIn': action == 'Masuk' ? _jumlahController.text.trim() : '',
      'keluarOut': action == 'Keluar' ? _jumlahController.text.trim() : '',
    };
    
    Fluttertoast.showToast(msg: "⏳ Mengirim data...", toastLength: Toast.LENGTH_SHORT);
    final result = await provider.submitTransaction(dataToSend);

    if (result['status'] == 'success') {
      Fluttertoast.showToast(msg: "✅ Data berhasil disimpan!", toastLength: Toast.LENGTH_LONG);
      _resetForm();
    } else {
      Fluttertoast.showToast(msg: "❌ Gagal: ${result['error']}", toastLength: Toast.LENGTH_LONG);
    }
  }

  // =================================================================
  // WIDGET BUILDER
  // =================================================================
  
  @override
  Widget build(BuildContext context) {
    return Consumer<InventoryProvider>(
      builder: (context, provider, child) {
        final isKeramik = provider.currentCategory == 'KERAMIK';
        final isMasukMode = provider.currentMode == 'Masuk';
        final theme = Theme.of(context);

        return Scaffold(
          appBar: AppBar(
            title: Text('INVENTORY - ${provider.currentMode.toUpperCase()}'),
            backgroundColor: isMasukMode ? Colors.teal : theme.colorScheme.secondary,
            centerTitle: true,
            actions: [
              IconButton(
                icon: const Icon(Icons.logout),
                onPressed: () {
                  // Implementasi Logout
                  Fluttertoast.showToast(msg: "Logout Dummmy");
                },
              ),
            ],
          ),
          body: provider.isLoading && provider.inventoryDataCache.isEmpty
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      _buildUserLabel(provider),
                      _buildCategoryButtons(provider, theme),
                      const Divider(),
                      Form(
                        key: _formKey,
                        child: Column(
                          children: [
                            // 1. Lokasi
                            _buildTextField(
                              'Lokasi', Icons.map, _lokasiController, _lokasiFocus, 
                              onChanged: (value) {
                                if (isKeramik) {
                                  // Trigger smart search saat lokasi berubah untuk KERAMIK
                                  setState(() {}); // Untuk me-rebuild ProductSearchList
                                }
                                // Pindah ke Nama Barang saat input selesai (saat enter/submit)
                                if (!isKeramik && value.trim().isNotEmpty) {
                                  _lokasiFocus.nextFocus(); 
                                }
                              },
                              onSubmitted: (_) {
                                isKeramik ? FocusScope.of(context).requestFocus(_namaBarangFocus) : null;
                              },
                            ),

                            // 2. Jenis Produk (Dropdown vs Live Search)
                            isKeramik
                                ? _buildJenisProdukKeramikSearch(provider)
                                : _buildJenisProdukDropdown(provider),
                            
                            // 3. Nama Barang (Otomatis/Live Search/Pilihan Cerdas)
                            isKeramik
                              ? _buildKeramikSmartProductList(provider)
                              : _buildNamaBarangDropdownSearch(provider),
                            
                            // 4. Jumlah
                            _buildNumberField('Jumlah', Icons.format_list_numbered, _jumlahController, _jumlahFocus, _keteranganFocus),

                            // 5. Keterangan
                            _buildTextField('Keterangan', Icons.comment, _keteranganController, _keteranganFocus, 
                              isOptional: true,
                              onSubmitted: (_) => _submitTransaction(provider.currentMode),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      _buildSubmitButton(provider, theme),
                    ],
                  ),
                ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: provider.toggleMode,
            label: Text(
              'Ganti ke ${isMasukMode ? 'KELUAR' : 'MASUK'}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            icon: const Icon(Icons.swap_horiz),
            backgroundColor: isMasukMode ? theme.colorScheme.secondary : Colors.teal,
          ),
        );
      },
    );
  }
  
  // =================================================================
  // WIDGET PEMBANTU
  // =================================================================

  Widget _buildUserLabel(InventoryProvider provider) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 25.0, left: 5),
      child: Text(
        'User Aktif: ${provider.activeUser}',
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: Colors.grey,
        ),
      ),
    );
  }

  Widget _buildCategoryButtons(InventoryProvider provider, ThemeData theme) {
    final categories = provider.inventoryDataCache.keys.toList();
    return Wrap(
      spacing: 8.0,
      runSpacing: 8.0,
      children: categories.map((category) {
        final isActive = provider.currentCategory == category;
        return ActionChip(
          label: Text(category),
          avatar: const Icon(Icons.category, size: 18),
          backgroundColor: isActive ? theme.primaryColor.withOpacity(0.8) : Colors.grey.shade200,
          labelStyle: TextStyle(
            color: isActive ? Colors.white : Colors.black87,
            fontWeight: FontWeight.bold,
          ),
          onPressed: () {
            provider.selectCategory(category);
            _namaBarangController.clear();
            _jenisProdukKeramikController.clear();
            _selectedJenisProdukDropdown = null;
            FocusScope.of(context).requestFocus(_lokasiFocus);
          },
        );
      }).toList(),
    );
  }

  Widget _buildTextField(String label, IconData icon, TextEditingController controller, FocusNode focusNode, {bool isOptional = false, Function(String)? onChanged, Function(String)? onSubmitted}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15.0),
      child: TextFormField(
        controller: controller,
        focusNode: focusNode,
        textCapitalization: TextCapitalization.characters,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon),
          border: const OutlineInputBorder(),
          suffixText: isOptional ? '(Opsional)' : '*',
        ),
        validator: (value) {
          if (!isOptional && (value == null || value.isEmpty)) {
            return '$label wajib diisi.';
          }
          return null;
        },
        onChanged: onChanged,
        onSubmitted: onSubmitted,
        textInputAction: onSubmitted != null ? TextInputAction.send : TextInputAction.next,
      ),
    );
  }

  Widget _buildNumberField(String label, IconData icon, TextEditingController controller, FocusNode focusNode, FocusNode nextFocusNode) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15.0),
      child: TextFormField(
        controller: controller,
        focusNode: focusNode,
        keyboardType: TextInputType.number,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon),
          border: const OutlineInputBorder(),
          suffixText: '*',
        ),
        validator: (value) {
          if (value == null || value.isEmpty) {
            return '$label wajib diisi.';
          }
          if (int.tryParse(value) == null || int.parse(value) <= 0) {
            return 'Masukkan jumlah yang valid (min 1).';
          }
          return null;
        },
        onFieldSubmitted: (_) => FocusScope.of(context).requestFocus(nextFocusNode),
        textInputAction: TextInputAction.next,
      ),
    );
  }

  // 2.1 Dropdown Jenis Produk (Non-Keramik)
  Widget _buildJenisProdukDropdown(InventoryProvider provider) {
    final jenisProdukList = provider.inventoryDataCache[provider.currentCategory]?.keys.toList() ?? [];
    jenisProdukList.sort();

    return Padding(
      padding: const EdgeInsets.only(bottom: 15.0),
      child: DropdownButtonFormField<String>(
        decoration: const InputDecoration(
          labelText: 'Jenis Produk *',
          prefixIcon: Icon(Icons.stream),
          border: OutlineInputBorder(),
        ),
        value: _selectedJenisProdukDropdown,
        items: [
          const DropdownMenuItem(value: null, child: Text('-- Pilih Jenis Produk --')),
          ...jenisProdukList.map((jenis) => DropdownMenuItem(value: jenis, child: Text(jenis))).toList(),
        ],
        onChanged: (value) {
          setState(() {
            _selectedJenisProdukDropdown = value;
            _namaBarangController.clear(); // Reset nama barang
          });
          // Pindah fokus ke Nama Barang
          FocusScope.of(context).requestFocus(_namaBarangFocus);
        },
        validator: (value) => (value == null || value.isEmpty) ? 'Jenis Produk wajib dipilih.' : null,
      ),
    );
  }
  
  // 2.2 Live Search Jenis Produk (Keramik)
  Widget _buildJenisProdukKeramikSearch(InventoryProvider provider) {
    // Kita gunakan TextFormField dengan logika auto-suggest/autocomplete
    return Padding(
      padding: const EdgeInsets.only(bottom: 15.0),
      child: Autocomplete<String>(
        optionsBuilder: (TextEditingValue textEditingValue) {
          if (textEditingValue.text.isEmpty) {
            return const Iterable<String>.empty();
          }
          final allJenis = provider.inventoryDataCache['KERAMIK']?.keys.toList() ?? [];
          return allJenis.where((jenis) =>
              jenis.toUpperCase().contains(textEditingValue.text.toUpperCase()));
        },
        onSelected: (String selection) {
          _jenisProdukKeramikController.text = selection;
          _namaBarangController.clear(); // Reset nama barang
          FocusScope.of(context).requestFocus(_namaBarangFocus);
        },
        fieldViewBuilder: (BuildContext context, TextEditingController textEditingController, FocusNode focusNode, VoidCallback onFieldSubmitted) {
          _jenisProdukKeramikController.text = textEditingController.text; // Sinkronisasi controller
          return TextFormField(
            controller: textEditingController,
            focusNode: focusNode,
            textCapitalization: TextCapitalization.characters,
            decoration: const InputDecoration(
              labelText: 'Jenis Produk KERAMIK (Cari)*',
              prefixIcon: Icon(Icons.search),
              border: OutlineInputBorder(),
            ),
            validator: (value) => (value == null || value.isEmpty) ? 'Jenis Produk wajib diisi.' : null,
            onFieldSubmitted: (_) => FocusScope.of(context).requestFocus(_namaBarangFocus),
            textInputAction: TextInputAction.next,
          );
        },
      ),
    );
  }

  // 3.1 Pilihan Cerdas Nama Barang (Keramik)
  Widget _buildKeramikSmartProductList(InventoryProvider provider) {
    // Tampilkan list produk keramik yang cocok dengan lokasi yang diinput
    final locationInput = _lokasiController.text.trim();
    final matchingProducts = provider.searchProductsByLocation(locationInput);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (locationInput.isEmpty)
           const Text('Masukkan Lokasi di atas untuk mendapatkan Nama Barang Keramik yang sesuai.', style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey)),
        if (locationInput.isNotEmpty && matchingProducts.isEmpty)
           const Text('⚠️ Tidak ditemukan Keramik pada lokasi tersebut.', style: TextStyle(color: Colors.red)),
        if (matchingProducts.isNotEmpty)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.only(top: 8.0),
                child: Text('Daftar Nama Barang (Pilihan Cerdas):', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
              Container(
                constraints: const BoxConstraints(maxHeight: 250), // Batasi tinggi list
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(5)
                ),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: matchingProducts.length.clamp(0, 10), // Maks 10
                  itemBuilder: (context, index) {
                    final product = matchingProducts[index];
                    return ListTile(
                      dense: true,
                      title: Text(product.namaBarang, style: const TextStyle(fontSize: 14)),
                      subtitle: Text('Jenis: ${product.jenisProduk}', style: const TextStyle(fontSize: 12)),
                      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                      onTap: () => _handleProductSelection(product),
                      selected: _namaBarangController.text == product.namaBarang,
                      selectedTileColor: Theme.of(context).primaryColor.withOpacity(0.1),
                    );
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 15),
          // Tetap tampilkan field Nama Barang untuk input manual/display
          _buildTextField('Nama Barang *', Icons.box_open, _namaBarangController, _namaBarangFocus, isOptional: false,
            onSubmitted: (_) => FocusScope.of(context).requestFocus(_jumlahFocus)
          ),
      ],
    );
  }

  // 3.2 Dropdown/Search Nama Barang (Non-Keramik)
  Widget _buildNamaBarangDropdownSearch(InventoryProvider provider) {
    // Untuk non-keramik, gunakan Autocomplete dari daftar produk yang sudah difilter Jenis Produk
    final selectedJenis = _selectedJenisProdukDropdown;
    final productList = (selectedJenis != null && provider.currentCategory.isNotEmpty)
        ? provider.inventoryDataCache[provider.currentCategory]?[selectedJenis] ?? []
        : [];

    return Padding(
      padding: const EdgeInsets.only(bottom: 15.0),
      child: Autocomplete<String>(
        optionsBuilder: (TextEditingValue textEditingValue) {
          if (textEditingValue.text.isEmpty || productList.isEmpty) {
            return const Iterable<String>.empty();
          }
          return productList.where((name) =>
              name.toUpperCase().contains(textEditingValue.text.toUpperCase()));
        },
        onSelected: (String selection) {
          _namaBarangController.text = selection;
          FocusScope.of(context).requestFocus(_jumlahFocus);
        },
        fieldViewBuilder: (BuildContext context, TextEditingController textEditingController, FocusNode focusNode, VoidCallback onFieldSubmitted) {
          _namaBarangController.text = textEditingController.text; // Sinkronisasi controller
          return TextFormField(
            controller: textEditingController,
            focusNode: focusNode,
            enabled: productList.isNotEmpty, // Hanya aktif jika Jenis Produk dipilih
            textCapitalization: TextCapitalization.characters,
            decoration: InputDecoration(
              labelText: 'Nama Barang *',
              prefixIcon: const Icon(Icons.box_open),
              border: const OutlineInputBorder(),
              hintText: productList.isEmpty ? 'Pilih Jenis Produk dulu.' : 'Ketik nama barang...',
            ),
            validator: (value) => (value == null || value.isEmpty) ? 'Nama Barang wajib diisi.' : null,
            onFieldSubmitted: (_) => FocusScope.of(context).requestFocus(_jumlahFocus),
            textInputAction: TextInputAction.next,
          );
        },
      ),
    );
  }

  Widget _buildSubmitButton(InventoryProvider provider, ThemeData theme) {
    final isMasukMode = provider.currentMode == 'Masuk';
    final color = isMasukMode ? Colors.teal : theme.colorScheme.secondary;
    final icon = isMasukMode ? Icons.arrow_circle_up : Icons.arrow_circle_down;

    return Center(
      child: SizedBox(
        width: double.infinity,
        height: 50,
        child: ElevatedButton.icon(
          onPressed: provider.isLoading ? null : () => _submitTransaction(provider.currentMode),
          icon: provider.isLoading ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : Icon(icon),
          label: Text(
            provider.isLoading ? 'MEMPROSES...' : provider.currentMode.toUpperCase(),
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: color,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            elevation: 5,
          ),
        ),
      ),
    );
  }
}
