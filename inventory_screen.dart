// lib/inventory_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'inventory_provider.dart';
import 'user_provider.dart';

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  // Controllers
  final _formKey = GlobalKey<FormState>();
  // Menggunakan TextControllers untuk input form
  final _namaBarangController = TextEditingController(); 
  final _lokasiController = TextEditingController();
  final _jumlahController = TextEditingController();
  final _keteranganController = TextEditingController();

  @override
  void dispose() {
    _namaBarangController.dispose();
    _lokasiController.dispose();
    _jumlahController.dispose();
    _keteranganController.dispose();
    super.dispose();
  }

  // Menggantikan fungsi JS: displayMessage()
  void _showSnackbar(String message, {bool isError = false, bool isLoading = false}) {
    final snackBar = SnackBar(
      content: Text(
        message,
        style: TextStyle(color: isLoading ? Colors.black : Colors.white),
      ),
      backgroundColor: isLoading ? Colors.yellow : (isError ? Colors.red : Colors.green),
      duration: isLoading ? const Duration(minutes: 1) : const Duration(seconds: 4),
    );
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(snackBar);
  }

  // Menggantikan fungsi JS: handleFormSubmit()
  void _submitForm(InventoryProvider provider, String activeUser) async {
    // Memastikan Nama Barang sudah diisi (TextEditingController tidak terikat langsung ke Autocomplete)
    if (_namaBarangController.text.isEmpty) {
      _showSnackbar("Nama Barang wajib diisi.", isError: true);
      return;
    }
    
    if (!_formKey.currentState!.validate()) return;
    
    // Pastikan Jenis Produk sudah dipilih
    if (provider.selectedJenisProduk == null) {
      _showSnackbar("Jenis Produk wajib diisi.", isError: true);
      return;
    }

    final int jumlah = int.tryParse(_jumlahController.text) ?? 0;
    if (jumlah <= 0) {
      _showSnackbar("Jumlah harus lebih besar dari 0.", isError: true);
      return;
    }

    _showSnackbar("⏳ Mengirim data Barang ${provider.isMasukMode ? 'MASUK' : 'KELUAR'}...", isLoading: true);

    // Kirim data
    final result = await provider.submitTransaction(
      activeUser: activeUser,
      namaBarang: _namaBarangController.text,
      lokasi: _lokasiController.text,
      jumlah: jumlah,
      keterangan: _keteranganController.text,
    );

    ScaffoldMessenger.of(context).hideCurrentSnackBar();

    // Handle respons
    if (result['status'] == 'success') {
      _showSnackbar('✅ Data berhasil disimpan!', isError: false);
      
      // PENGOSONGAN FORM SETELAH AMBIL DATA (Logika yang sama di JS)
      _jumlahController.clear();
      _keteranganController.clear();
      _lokasiController.clear();
      _namaBarangController.clear();
      
      // Reset Kategori, yang akan mereset Jenis Produk dan Autocomplete Cache
      provider.setSelectedCategory(null); 

    } else {
      _showSnackbar('❌ Gagal menyimpan data: ${result['error']}', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Ambil user aktif dari UserProvider
    final userProvider = Provider.of<UserProvider>(context);
    final activeUser = userProvider.activeUser ?? 'N/A';
    
    // Jika tidak ada user, redirect ke halaman login (asumsi telah dibuat)
    if (userProvider.activeUser == null) {
        // Logika untuk kembali ke login (misalnya: Navigator.pushReplacementNamed(context, '/login');)
        // Untuk demo ini, kita akan menggunakan Text sederhana.
        return const Scaffold(body: Center(child: Text("Sesi berakhir. Silakan login kembali.")));
    }


    return Consumer<InventoryProvider>(
      builder: (context, provider, child) {
        // Tema warna dinamis (Menggantikan body.mode-masuk/mode-keluar)
        final modeColor = provider.isMasukMode ? Colors.green[700] : Colors.red[700];

        return Scaffold(
          backgroundColor: Colors.grey[50],

          // AppBar Disesuaikan (Menggantikan .app-title)
          appBar: AppBar(
            automaticallyImplyLeading: false, 
            backgroundColor: modeColor,
            title: Row(
              children: [
                // Ganti dengan Image.asset('assets/depo.png') jika Anda punya
                const Icon(Icons.inventory_2, color: Colors.white), 
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('DEPO SUMBER BANGUNAN', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800)),
                    Text(
                      'INVENTORY - ${provider.isMasukMode ? 'MASUK' : 'KELUAR'}',
                      style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ],
            ),
            actions: [
              // Tombol LOGOUT (Menggantikan logoutButton di JS)
              IconButton(
                icon: const Icon(Icons.logout, color: Colors.white),
                onPressed: userProvider.logout, // Panggil fungsi logout
                tooltip: 'Ganti User',
              ),
            ],
          ),

          body: provider.isLoadingData 
            ? const Center(child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  Padding(
                    padding: EdgeInsets.all(15.0),
                    child: Text("Mengambil data produk...", style: TextStyle(fontStyle: FontStyle.italic)),
                  )
                ],
              ))
            : SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      // User Aktif (Menggantikan .user-label di JS)
                      _buildActiveUserDisplay(activeUser, modeColor),
                      
                      // Kategori (Menggantikan .category-buttons)
                      _buildCategoryButtons(provider, modeColor),
                      const SizedBox(height: 20),

                      // Jenis Produk (Dropdown)
                      _buildDropdownInput(
                        label: 'Jenis Produk',
                        icon: Icons.stream,
                        value: provider.selectedJenisProduk,
                        items: provider.jenisProdukOptions,
                        onChanged: provider.setSelectedJenisProduk,
                        enabled: provider.selectedCategory != null,
                      ),
                      const SizedBox(height: 20),
                      
                      // Nama Barang (Autocomplete/Live Search)
                      _buildAutocompleteInput(provider),
                      const SizedBox(height: 20),

                      // Lokasi (Visibility)
                      Visibility(
                        visible: provider.isMasukMode, // Logika Lokasi wajib diisi saat Masuk
                        child: _buildTextInput(
                          controller: _lokasiController,
                          label: 'Lokasi',
                          icon: Icons.location_on,
                          keyboardType: TextInputType.text,
                          required: provider.isMasukMode,
                          enabled: provider.selectedJenisProduk != null,
                        ),
                      ),
                      if (!provider.isMasukMode) const SizedBox(height: 20), // Jarak tambahan jika Lokasi disembunyikan

                      // Jumlah
                      _buildTextInput(
                        controller: _jumlahController,
                        label: 'Jumlah',
                        icon: Icons.onetwothree,
                        keyboardType: TextInputType.number,
                        required: true,
                        enabled: provider.selectedJenisProduk != null,
                      ),
                      
                      // Keterangan (Checker/Keterangan di JS)
                      _buildTextInput(
                        controller: _keteranganController,
                        label: 'Keterangan',
                        icon: Icons.comment,
                        keyboardType: TextInputType.text,
                        required: false,
                        enabled: provider.selectedJenisProduk != null,
                      ),
                      const SizedBox(height: 30),

                      // Submit Buttons
                      _buildSubmitButtons(provider, activeUser, modeColor),
                      
                      // Footer
                      Padding(
                        padding: const EdgeInsets.only(top: 20.0),
                        child: Center(
                          child: Text(
                            '© ${DateTime.now().year} Depo Sumber Bangunan', 
                            style: TextStyle(fontSize: 11, color: Colors.grey[600])
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          
          // FAB Toggle Mode (Menggantikan fabToggle di JS)
          floatingActionButton: FloatingActionButton.extended(
            onPressed: provider.toggleMode,
            label: Text('Ganti ke ${provider.isMasukMode ? 'KELUAR' : 'MASUK'}'),
            icon: const Icon(Icons.swap_horiz),
            backgroundColor: provider.isMasukMode ? Colors.red : Colors.green, // Warna dinamis
          ),
          floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
        );
      },
    );
  }

  // --- Helper Widgets ---

  Widget _buildActiveUserDisplay(String activeUser, Color? modeColor) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 15),
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: modeColor?.withOpacity(0.1) ?? Colors.blue[50], 
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: modeColor?.withOpacity(0.3) ?? Colors.blue[100]!),
      ),
      child: Center(
        child: Text.rich(
          TextSpan(
            text: 'User Aktif: ',
            style: TextStyle(color: Colors.black87, fontSize: 13, fontWeight: FontWeight.w600),
            children: [
              TextSpan(
                text: activeUser,
                style: TextStyle(color: modeColor, fontWeight: FontWeight.w800),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryButtons(InventoryProvider provider, Color? modeColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Kategori Barang', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF00897b))),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8.0,
          runSpacing: 8.0,
          children: provider.categoryOptions.map((category) {
            final isSelected = provider.selectedCategory == category;
            return ActionChip(
              label: Text(category),
              avatar: Icon(_getCategoryIcon(category), size: 18),
              backgroundColor: isSelected ? modeColor : Colors.grey[200],
              labelStyle: TextStyle(
                color: isSelected ? Colors.white : Colors.black87,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              ),
              onPressed: provider.isLoadingData ? null : () => provider.setSelectedCategory(category),
              side: isSelected ? BorderSide(color: modeColor!) : null,
            );
          }).toList(),
        ),
      ],
    );
  }

  // Custom Dropdown Widget
  Widget _buildDropdownInput({
    required String label,
    required IconData icon,
    required String? value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
    required bool enabled,
  }) {
    return DropdownButtonFormField<String>(
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: Colors.grey),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 15),
      ),
      value: value,
      isExpanded: true,
      hint: Text(enabled ? '-- Pilih $label --' : '-- Pilih Kategori Dulu --'),
      items: items.map((String item) {
        return DropdownMenuItem<String>(
          value: item,
          child: Text(item, style: const TextStyle(fontWeight: FontWeight.w600)),
        );
      }).toList(),
      onChanged: enabled ? onChanged : null,
      validator: (v) {
        if (!enabled) return null; // Tidak perlu validasi jika disabled
        return (v == null || v.isEmpty) ? '$label wajib dipilih.' : null;
      },
    );
  }

  // Custom Autocomplete Widget
  Widget _buildAutocompleteInput(InventoryProvider provider) {
    return Autocomplete<String>(
      key: ValueKey(provider.selectedJenisProduk), // Key untuk mereset state Autocomplete saat Jenis Produk berubah
      fieldViewBuilder: (context, textEditingController, focusNode, onFieldSubmitted) {
        // Sinkronisasi controller utama dengan controller internal Autocomplete
        _namaBarangController.text = textEditingController.text;
        
        return TextFormField(
          controller: textEditingController,
          focusNode: focusNode,
          textCapitalization: TextCapitalization.characters, // Uppercase
          decoration: InputDecoration(
            labelText: 'Nama Barang',
            prefixIcon: const Icon(Icons.box_open, color: Colors.grey),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 15),
          ),
          onFieldSubmitted: (value) => onFieldSubmitted(),
          validator: (value) => (value == null || value.isEmpty) ? 'Nama Barang wajib diisi.' : null,
          enabled: provider.selectedJenisProduk != null, // Disabled jika Jenis Produk belum dipilih
        );
      },
      optionsBuilder: (TextEditingValue textEditingValue) {
        return provider.filterSuggestions(textEditingValue.text);
      },
      onSelected: (String selection) {
        // Update controller saat item dipilih
        _namaBarangController.text = selection;
        // Opsional: Focus ke input selanjutnya
        FocusScope.of(context).nextFocus();
      },
      // Menggantikan fungsi JS Highlighting
      optionsViewBuilder: (context, onSelected, options) {
          return Align(
              alignment: Alignment.topLeft,
              child: Material(
                  elevation: 4.0,
                  child: Container(
                      width: MediaQuery.of(context).size.width - 40, // Lebar sesuai form
                      constraints: const BoxConstraints(maxHeight: 200),
                      child: ListView.builder(
                          padding: EdgeInsets.zero,
                          shrinkWrap: true,
                          itemCount: options.length,
                          itemBuilder: (context, index) {
                              final option = options.elementAt(index);
                              final query = _namaBarangController.text.toUpperCase();
                              return InkWell(
                                  onTap: () => onSelected(option),
                                  child: Container(
                                      padding: const EdgeInsets.all(10),
                                      child: RichText(
                                          text: TextSpan(
                                              style: DefaultTextStyle.of(context).style,
                                              children: _buildHighlightedText(option, query),
                                          ),
                                      ),
                                  ),
                              );
                          },
                      ),
                  ),
              ),
          );
      },
    );
  }

  // Menggantikan logika JS Highlighting
  List<TextSpan> _buildHighlightedText(String text, String query) {
    if (query.isEmpty) return [TextSpan(text: text)];

    final List<TextSpan> spans = [];
    final searchTokens = query.split(RegExp(r'\s+')).where((t) => t.isNotEmpty).toList();

    // Untuk kesederhanaan, kita hanya highlight token pertama yang ditemukan
    String currentText = text;
    final String token = searchTokens.isNotEmpty ? searchTokens[0] : '';
    final int index = currentText.indexOf(token);

    if (index == -1 || token.isEmpty) {
      return [TextSpan(text: text)];
    }

    spans.add(TextSpan(text: currentText.substring(0, index)));
    spans.add(TextSpan(
      text: currentText.substring(index, index + token.length),
      style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue), // Highlight style
    ));
    spans.add(TextSpan(text: currentText.substring(index + token.length)));

    return spans;
  }

  // Input Teks umum
  Widget _buildTextInput({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required TextInputType keyboardType,
    required bool required,
    required bool enabled,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15.0),
      child: TextFormField(
        controller: controller,
        enabled: enabled,
        textCapitalization: TextCapitalization.characters, // Uppercase (setupUppercaseListeners di JS)
        keyboardType: keyboardType,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, color: Colors.grey),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 15),
        ),
        validator: (value) {
          if (required && (value == null || value.isEmpty)) {
            return 'Bidang $label wajib diisi.';
          }
          return null;
        },
      ),
    );
  }

  // Tombol Submit (Menggantikan masukButton/keluarButton di JS)
  Widget _buildSubmitButtons(InventoryProvider provider, String activeUser, Color? modeColor) {
    final bool canSubmit = provider.selectedJenisProduk != null;
    final Color buttonColor = provider.isMasukMode ? Colors.green : Colors.red;

    return Center(
      child: Container(
        width: double.infinity,
        child: ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: buttonColor,
            padding: const EdgeInsets.all(15),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            elevation: 5,
          ),
          icon: Icon(
            provider.isMasukMode ? Icons.arrow_upward : Icons.arrow_downward, 
            color: Colors.white
          ),
          label: Text(
            provider.isMasukMode ? 'MASUK' : 'KELUAR', 
            style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)
          ),
          onPressed: canSubmit ? () => _submitForm(provider, activeUser) : null,
        ),
      ),
    );
  }

  // Helper untuk Icon Kategori
  IconData _getCategoryIcon(String category) {
    switch (category.toUpperCase()) {
      case 'BESI': return Icons.gavel;
      case 'KERAMIK': return Icons.tile_sharp;
      case 'LT 2': return Icons.layers;
      case 'GM': return Icons.local_shipping;
      default: return Icons.category;
    }
  }
}
