import 'package:flutter/material.dart';

import '../../models/ingredient.dart';

/// Modal Bottom Sheet untuk form Tambah dan Edit nama bahan mentah.
class IngredientFormSheet extends StatefulWidget {
  final Ingredient? initialIngredient;
  final Future<void> Function(String name) onSave;

  const IngredientFormSheet({
    super.key,
    this.initialIngredient,
    required this.onSave,
  });

  /// Helper untuk menampilkan sheet secara rapi dan fokus keyboard otomatis.
  static Future<bool?> show(
    BuildContext context, {
    Ingredient? initialIngredient,
    required Future<void> Function(String name) onSave,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => IngredientFormSheet(
        initialIngredient: initialIngredient,
        onSave: onSave,
      ),
    );
  }

  @override
  State<IngredientFormSheet> createState() => _IngredientFormSheetState();
}

class _IngredientFormSheetState extends State<IngredientFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  bool _isSaving = false;
  String? _errorMessage;

  bool get _isEditMode => widget.initialIngredient != null;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(
      text: widget.initialIngredient?.name ?? '',
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    if (_isSaving) return;

    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      await widget.onSave(_nameController.text.trim());
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSaving = false;
          _errorMessage = e.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 20,
        bottom: 24 + keyboardHeight,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle Bar
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: colorScheme.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Title
            Text(
              _isEditMode ? 'Edit Bahan Mentah' : 'Tambah Bahan Mentah',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
                color: colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _isEditMode
                  ? 'Perbarui nama bahan yang digunakan dalam resep.'
                  : 'Masukkan nama bahan mentah dasar yang digunakan.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurface.withAlpha(160),
              ),
            ),
            const SizedBox(height: 20),

            // Error Banner (jika duplikat / error validasi)
            if (_errorMessage != null) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colorScheme.error.withAlpha(20),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: colorScheme.error.withAlpha(60)),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.error_outline_rounded,
                      size: 20,
                      color: colorScheme.error,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colorScheme.error,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Input Nama Bahan
            TextFormField(
              controller: _nameController,
              autofocus: true,
              enabled: !_isSaving,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Nama bahan',
                hintText: 'Contoh: Gula Pasir, Susu UHT',
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Nama bahan wajib diisi.';
                }
                return null;
              },
              onFieldSubmitted: (_) => _handleSubmit(),
            ),
            const SizedBox(height: 24),

            // Actions
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton(
                  onPressed: _isSaving
                      ? null
                      : () => Navigator.of(context).pop(false),
                  child: const Text('Batal'),
                ),
                const SizedBox(width: 12),
                FilledButton(
                  onPressed: _isSaving ? null : _handleSubmit,
                  child: Text(
                    _isSaving
                        ? 'Menyimpan...'
                        : (_isEditMode ? 'Simpan Perubahan' : 'Simpan'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

