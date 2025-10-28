// lib/inventory_provider.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

// Data struktur untuk menampung seluruh produk (Mirip inventoryDataCache di JS)
typedef ProductMap = Map<String, Map<String, List<String>>>;

class InventoryProvider extends ChangeNotifier {
  // GANTI DENGAN SCRIPT_URL DEPLOYMENT APPS SCRIPT ANDA
  static const String SCRIPT_URL = 'https://script.google.com/macros/s/AKfycbxe9383u4mdfV475xdHX99RIe6DWsA31q4jW-SVsDwbK4bzwBCf3pbaUO9DuQcFtTtS/exec';

  // State Global
  ProductMap _inventoryDataCache = {};
  String? _selectedCategory;
  String? _selectedJenisProduk;
  List<String> _productNamesCache = []; 
  bool _isMasukMode = true; 
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
    final options = _inventoryDataCache[_selectedCategory]!.keys.toList();
    options.sort();
    return options;
  }

  InventoryProvider() {
    fetchProductData();
  }

  // Menggantikan fungsi JS: fetchProductDataFromAppsScript()
  Future<void> fetchProductData() async {
    _isLoadingData = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // Menggunakan GET request ke Apps Script
      final response = await http.get(Uri.parse('$SCRIPT_URL?action=getProducts'));

      if (response.statusCode == 200) {
        final Map<String, dynamic> result = json.decode(response.body);

        if (result['status'] == 'ok' && result['data'] != null) {
          _inventoryDataCache = _transformDataToUppercase(result['data'] as Map<String, dynamic>);
          _errorMessage = null; 
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

  void setSelectedCategory(String? category) {
    _selectedCategory = category;
    _selectedJenisProduk = null;
    _productNamesCache = [];
    notifyListeners();
  }

  void setSelectedJenisProduk(String? jenis) {
    _selectedJenisProduk = jenis;
    _productNamesCache = [];

    if (jenis != null && _selectedCategory != null) {
      final rawList = _inventoryDataCache[_selectedCategory]![jenis] ?? [];
      _productNamesCache = _cleanProductList(rawList);
    }
    notifyListeners();
  }

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
    final searchTokens = upperQuery.split(RegExp(r'\s+')).where((t) => t.isNotEmpty).toList();

    return _productNamesCache.where((name) {
      return searchTokens.every((token) => name.contains(token));
    }).take(10);
  }

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
    
    // Validasi Lokasi (hanya wajib saat Masuk)
    if (lokasi.isEmpty && _isMasukMode) {
      return {'status': 'error', 'error': 'Lokasi wajib diisi untuk transaksi Masuk.'};
    }

    final dataToSend = {
      'action': 'submit', // Tambahkan action eksplisit untuk Apps Script
      'kategori': _selectedCategory!.toUpperCase(),
      'jenisProduk': _selectedJenisProduk!.toUpperCase(),
      'namaBarang': namaBarang.toUpperCase(),
      'checker': activeUser, 
      'lokasi': lokasi.toUpperCase(), 
      'formatSimpan': keterangan.toUpperCase(), 
      'masukIn': _isMasukMode ? jumlah.toString() : '',
      'keluarOut': !_isMasukMode ? jumlah.toString() : '',
    };

    try {
      final response = await http.post(
        Uri.parse(SCRIPT_URL),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: dataToSend, 
      );

      final result = json.decode(response.body);
      return result;
    } catch (e) {
      return {'status': 'error', 'error': 'Terjadi kesalahan jaringan/Apps Script. $e'};
    }
  }
}
