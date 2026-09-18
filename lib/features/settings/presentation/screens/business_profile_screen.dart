import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../../../core/constants/app_constants.dart';
import '../../data/app_settings_repository.dart';

/// Halaman pengaturan identitas usaha (nama toko, slogan, dan logo).
class BusinessProfileScreen extends StatefulWidget {
  final AppSettingsRepository? repository;

  const BusinessProfileScreen({super.key, this.repository});

  @override
  State<BusinessProfileScreen> createState() => _BusinessProfileScreenState();
}

class _BusinessProfileScreenState extends State<BusinessProfileScreen> {
  late final AppSettingsRepository _repository;
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _taglineController;

  String? _savedLogoPath;
  String? _newSelectedLogoPath;
  bool _clearLogo = false;
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? AppSettingsRepository();
    _nameController = TextEditingController();
    _taglineController = TextEditingController();
    _loadProfile();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _taglineController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    setState(() => _isLoading = true);
    try {
      final profile = await _repository.getBusinessProfile();
      if (mounted) {
        setState(() {
          _nameController.text = profile.name;
          _taglineController.text = profile.tagline;
          _savedLogoPath = profile.logoPath;
          _newSelectedLogoPath = null;
          _clearLogo = false;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal memuat profil usaha: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  /// Memilih file gambar logo baru dari perangkat menggunakan file_picker.
  Future<void> _handlePickLogo() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
      );

      if (result != null && result.files.isNotEmpty) {
        final path = result.files.single.path;
        if (path != null && path.isNotEmpty) {
          setState(() {
            _newSelectedLogoPath = path;
            _clearLogo = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal memilih gambar logo: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  /// Menghapus logo kustom dan kembali ke logo bawaan.
  void _handleRemoveLogo() {
    setState(() {
      _newSelectedLogoPath = null;
      _clearLogo = true;
    });
  }

  /// Menyimpan perubahan identitas usaha.
  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate() || _isSaving) return;

    setState(() => _isSaving = true);
    try {
      await _repository.saveBusinessProfile(
        name: _nameController.text,
        tagline: _taglineController.text,
        newLogoSourcePath: _newSelectedLogoPath,
        clearLogo: _clearLogo,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: Color(0xFF006C4C),
            content: Text('Identitas usaha berhasil disimpan!'),
          ),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Theme.of(context).colorScheme.error,
            content: Text('Gagal menyimpan profil: $e'),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  /// Mengembalikan identitas toko ke bawaan Labana asli.
  Future<void> _handleReset() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reset ke Default?'),
        content: const Text(
          'Nama toko, slogan, dan logo akan dikembalikan ke pengaturan awal bawaan Labana.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Reset'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isSaving = true);
    try {
      await _repository.resetToDefault();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: Color(0xFF006C4C),
            content: Text('Profil berhasil dikembalikan ke bawaan Labana.'),
          ),
        );
        await _loadProfile();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Theme.of(context).colorScheme.error,
            content: Text('Gagal mereset profil: $e'),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Identitas Usaha'),
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 16,
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Banner Informasi
                      _buildInfoBanner(context),
                      const SizedBox(height: 24),

                      // Bagian Logo Usaha
                      Text(
                        'Logo Toko / Usaha',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _buildLogoSection(context),
                      const SizedBox(height: 24),

                      // Input Nama Toko
                      Text(
                        'Nama Toko / Usaha',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _nameController,
                        decoration: InputDecoration(
                          hintText: 'Contoh: Kedai Kopi Berkah',
                          prefixIcon: const Icon(Icons.storefront_outlined),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Nama toko/usaha tidak boleh kosong';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 20),

                      // Input Slogan / Tagline
                      Text(
                        'Slogan / Tagline',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _taglineController,
                        decoration: InputDecoration(
                          hintText: 'Contoh: Rasa Juara, Harga Bersahabat',
                          prefixIcon: const Icon(Icons.short_text_rounded),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                      const SizedBox(height: 32),

                      // Tombol Aksi Simpan & Reset
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: FilledButton.icon(
                          onPressed: _isSaving ? null : _handleSave,
                          icon: _isSaving
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.check_circle_outline),
                          label: Text(
                            _isSaving ? 'Menyimpan...' : 'Simpan Perubahan',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        height: 44,
                        child: OutlinedButton.icon(
                          onPressed: _isSaving ? null : _handleReset,
                          icon: const Icon(Icons.restart_alt_rounded),
                          label: const Text('Reset ke Bawaan Labana'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildInfoBanner(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      elevation: 0,
      color: colorScheme.surfaceContainerHighest.withAlpha(120),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: colorScheme.outlineVariant.withAlpha(80)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.store_outlined,
              color: colorScheme.primary,
              size: 24,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Nama dan logo toko yang Anda atur akan tampil di AppBar utama, halaman pengaturan, serta tercetak otomatis pada header laporan penjualan PDF.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurface.withAlpha(180),
                  height: 1.4,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLogoSection(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    Widget imageWidget;
    bool hasCustom = false;

    if (_newSelectedLogoPath != null) {
      final file = File(_newSelectedLogoPath!);
      if (file.existsSync()) {
        imageWidget = Image.file(file, fit: BoxFit.cover);
        hasCustom = true;
      } else {
        imageWidget = Image.asset(AppConstants.logoIconPath, fit: BoxFit.cover);
      }
    } else if (!_clearLogo && _savedLogoPath != null) {
      final file = File(_savedLogoPath!);
      if (file.existsSync()) {
        imageWidget = Image.file(file, fit: BoxFit.cover);
        hasCustom = true;
      } else {
        imageWidget = Image.asset(AppConstants.logoIconPath, fit: BoxFit.cover);
      }
    } else {
      imageWidget = Image.asset(AppConstants.logoIconPath, fit: BoxFit.cover);
    }

    return Row(
      children: [
        // Preview Logo
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: colorScheme.outlineVariant,
              width: 1.5,
            ),
            color: colorScheme.surfaceContainerHighest.withAlpha(80),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: imageWidget,
          ),
        ),
        const SizedBox(width: 16),

        // Tombol Aksi Logo
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              OutlinedButton.icon(
                onPressed: _handlePickLogo,
                icon: const Icon(Icons.photo_library_outlined, size: 18),
                label: const Text('Pilih Gambar Logo'),
              ),
              if (hasCustom) ...[
                const SizedBox(height: 4),
                TextButton.icon(
                  onPressed: _handleRemoveLogo,
                  style: TextButton.styleFrom(
                    foregroundColor: colorScheme.error,
                  ),
                  icon: const Icon(Icons.delete_outline_rounded, size: 18),
                  label: const Text('Hapus Logo Kustom'),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
