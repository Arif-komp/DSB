// lib/inventory_provider.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

// Data struktur untuk menampung seluruh produk (Mirip inventoryDataCache di JS)
typedef ProductMap = Map<String, Map<String, List<String>>>;

class InventoryProvider extends ChangeNotifier {
  // SCRIPT_URL HARUS mengarah ke URL deployment Apps Script (doPost) Anda.
  static const String SCRIPT_URL = 'https://script.google.com/macros/s/AKfycbzDoa9mv0loGwHWCgzHrSUmD7fhaTwPd2Q6Z6hJ7hDTGVaS1d4avnfZ6-GW8y1A-5A/exec';

  // State Global
  ProductMap _inventoryDataCache = {};
  String? _selectedCategory;
  String? _selectedJenisProduk;
  List<String> _productNamesCache = []; // productNamesCache di JS
  bool _isMasukMode = true; // currentMode di JS
  bool _isLoadingData = false;
  String? _errorMessage;

  // Getters
  ProductMap get inventoryDataCache => _inventoryDataCache;
  String? get selectedCategory => _selectedCategory;
  String? get selectedJenisProduk => _selectedJenisProduk;
  bool get isMasukMode => _isMasukMode;
  bool get isLoadingData => _isLoadingData;
  String? get errorMessage => _errorMessage;

  List<String> get categoryOptions => _inventoryDataCache.keys.toList();

  List<String> get jenisProdukOptions {
    if (_selectedCategory == null || !_inventoryDataCache.containsKey(_selectedCategory)) {
      return [];
    }
    // Sort keys before returning
    final options = _inventoryDataCache[_selectedCategory]!.keys.toList();
    options.sort();
    return options;
  }

  // Constructor
  InventoryProvider() {
    fetchProductData();
  }

  // Menggantikan fungsi JS: fetchProductDataFromAppsScript()
  Future<void> fetchProductData() async {
    _isLoadingData = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // Menggunakan GET request ke Apps Script dengan parameter action=getProducts
      final response = await http.get(Uri.parse('$SCRIPT_URL?action=getProducts'));

      if (response.statusCode == 200) {
        // Karena Apps Script JSONP tidak diperlukan di Flutter, kita hanya parsing JSON
        final Map<String, dynamic> result = json.decode(response.body);

        if (result['status'] == 'ok' && result['data'] != null) {
          // Menggantikan transformDataToUppercase(response.data)
          _inventoryDataCache = _transformDataToUppercase(result['data'] as Map<String, dynamic>);
          _errorMessage = null; // Reset error
        } else {
          _errorMessage = 'Gagal memuat data produk: ${result['error']}';
        }
      } else {
        _errorMessage = 'Gagal memuat data: HTTP ${response.statusCode}';
      }
    } catch (e) {
      _errorMessage = 'Kesalahan jaringan: $e';
    } finally {
      _isLoadingData = false;
      notifyListeners();
    }
  }

  // Menggantikan fungsi JS: transformDataToUppercase()
  ProductMap _transformDataToUppercase(Map<String, dynamic> data) {
    final Map<String, Map<String, List<String>>> transformed = {};
    data.forEach((catKey, typeMap) {
      final String upperCatKey = catKey.toUpperCase();
      transformed[upperCatKey] = {};

      if (typeMap is Map) {
        typeMap.forEach((typeKey, productList) {
          final String upperTypeKey = typeKey.toUpperCase();
          if (productList is List) {
            transformed[upperCatKey]![upperTypeKey] = productList.map((name) => name.toString().toUpperCase()).toList();
          }
        });
      }
    });
    return transformed;
  }

  // Menggantikan logika Category Button Clicks
  void setSelectedCategory(String? category) {
    _selectedCategory = category;
    _selectedJenisProduk = null;
    _productNamesCache = [];
    notifyListeners();
  }

  // Menggantikan logika jenisProdukSelect.addEventListener('change')
  void setSelectedJenisProduk(String? jenis) {
    _selectedJenisProduk = jenis;
    _productNamesCache = [];

    if (jenis != null && _selectedCategory != null) {
      final rawList = _inventoryDataCache[_selectedCategory]![jenis] ?? [];
      // Menggantikan cleanProductList()
      _productNamesCache = _cleanProductList(rawList);
    }
    notifyListeners();
  }

  // Menggantikan fungsi JS: cleanProductList()
  List<String> _cleanProductList(List<String> productList) {
    const excludedKeywords = [
      'STP/', 'DBL/', 'DEL/', 'F/', 'D/',
      'TIDAK DIPAKAI', 'TIDAK DIGUNAKAN', 'NON AKTIF'
    ];

    return productList.where((productName) {
      final isExcluded = excludedKeywords.any((keyword) => productName.contains(keyword));
      return !isExcluded;
    }).toList();
  }

  // Menggantikan logika JS untuk Autocomplete/Live Search (flexibleSearch)
  Iterable<String> filterSuggestions(String query) {
    if (query.isEmpty) return const Iterable.empty();

    final upperQuery = query.toUpperCase().trim();
    // Memisahkan query berdasarkan spasi (seperti di JS: split(/\s+/))
    final searchTokens = upperQuery.split(RegExp(r'\s+')).where((t) => t.isNotEmpty).toList();

    return _productNamesCache.where((name) {
      // Logika flexibleSearch: memastikan setiap token ada di nama produk
      return searchTokens.every((token) => name.contains(token));
    }).take(10);
  }

  // Menggantikan fungsi JS: toggleMode() dan updateUIMode()
  void toggleMode() {
    _isMasukMode = !_isMasukMode;
    notifyListeners();
  }

  // Menggantikan fungsi JS: handleFormSubmit()
  Future<Map<String, dynamic>> submitTransaction({
    required String activeUser,
    required String namaBarang,
    required String lokasi,
    required int jumlah,
    String keterangan = '',
  }) async {
    if (_selectedCategory == null || _selectedJenisProduk == null) {
      return {'status': 'error', 'error': 'Kategori atau Jenis Produk belum dipilih.'};
    }
    
    // Logika validasi Lokasi (hanya wajib saat Masuk)
    if (lokasi.isEmpty && _isMasukMode) {
      return {'status': 'error', 'error': 'Lokasi wajib diisi untuk transaksi Masuk.'};
    }

    final dataToSend = {
      'kategori': _selectedCategory!.toUpperCase(),
      'jenisProduk': _selectedJenisProduk!.toUpperCase(),
      'namaBarang': namaBarang.toUpperCase(),
      'checker': activeUser, // User Aktif
      'lokasi': lokasi.toUpperCase(), // Lokasi
      'formatSimpan': keterangan.toUpperCase(), // Keterangan (sekarang sebagai formatSimpan di Apps Script)
      'masukIn': _isMasukMode ? jumlah.toString() : '',
      'keluarOut': !_isMasukMode ? jumlah.toString() : '',
    };

    try {
      final response = await http.post(
        Uri.parse(SCRIPT_URL),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: dataToSend, // http.post otomatis melakukan url-encoding (menggantikan urlEncodedData di JS)
      );

      final result = json.decode(response.body);
      return result;
    } catch (e) {
      return {'status': 'error', 'error': 'Terjadi kesalahan jaringan. Cek koneksi Apps Script. $e'};
    }
  }
}
