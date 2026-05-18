/// ADMIN ANNOTATION DIALOG
/// 
/// FAZ-6.0 / Step 2 - Smart Annotation System
/// 
/// 🎯 PURPOSE:
/// Admin'in reddedilen rapora spesifik notlar ekleyebileceği
/// batch selection destekli dialog widget'ı.
/// 
/// 🪨 PRINCIPLE:
/// "Hata Payı Sıfırlanır - Personel tam olarak neyi düzeltmesi gerektiğini görür"

library;

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/admin_annotation.dart';
import '../../services/admin_annotation_service.dart';

/// Admin Annotation Dialog
/// 
/// Allows admin to add annotations to specific fields of a report.
/// Supports batch selection and multiple annotation types.
class AdminAnnotationDialog extends StatefulWidget {
  final String reportId;
  final List<FieldOption> availableFields;
  final String adminId;
  final String adminName;
  final Function(List<AdminAnnotation>) onAnnotationsAdded;

  const AdminAnnotationDialog({
    super.key,
    required this.reportId,
    required this.availableFields,
    required this.adminId,
    required this.adminName,
    required this.onAnnotationsAdded,
  });

  @override
  State<AdminAnnotationDialog> createState() => _AdminAnnotationDialogState();
}

class _AdminAnnotationDialogState extends State<AdminAnnotationDialog> {
  final _formKey = GlobalKey<FormState>();
  final _messageController = TextEditingController();
  
  AnnotationType _selectedType = AnnotationType.error;
  AnnotationSeverity _selectedSeverity = AnnotationSeverity.medium;
  
  final Set<String> _selectedFields = {};
  bool _isSubmitting = false;

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _submitAnnotations() async {
    if (!_formKey.currentState!.validate() || _selectedFields.isEmpty) {
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final annotations = widget.availableFields
          .where((field) => _selectedFields.contains(field.key))
          .map((field) => AnnotationData(
                fieldKey: field.key,
                fieldLabel: field.label,
                message: _messageController.text.trim(),
                type: _selectedType,
                severity: _selectedSeverity,
              ))
          .toList();

      final service = AdminAnnotationService(
        client: widget.adminId.isEmpty ? 
          throw Exception('Supabase client required') : 
          Supabase.instance.client,
      );

      final addedAnnotations = await service.addBatchAnnotations(
        reportId: widget.reportId,
        annotations: annotations,
        adminId: widget.adminId,
        adminName: widget.adminName,
      );

      if (addedAnnotations.isNotEmpty) {
        widget.onAnnotationsAdded(addedAnnotations);
        
        if (mounted) {
          Navigator.of(context).pop(true);
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${addedAnnotations.length} not başarıyla eklendi'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Not eklenirken hata oluştu'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Hata: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return AlertDialog(
      title: const Text('Admin Notu Ekle'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Field Selection
              _buildSectionTitle('Hatalı Alanları Seçin'),
              const SizedBox(height: 8),
              _buildFieldSelector(isDark),
              
              const SizedBox(height: 16),
              
              // Annotation Type
              _buildSectionTitle('Not Türü'),
              const SizedBox(height: 8),
              _buildTypeSelector(isDark),
              
              const SizedBox(height: 16),
              
              // Severity
              _buildSectionTitle('Önem Derecesi'),
              const SizedBox(height: 8),
              _buildSeveritySelector(isDark),
              
              const SizedBox(height: 16),
              
              // Message
              _buildSectionTitle('Açıklama'),
              const SizedBox(height: 8),
              TextFormField(
                controller: _messageController,
                maxLines: 4,
                decoration: InputDecoration(
                  hintText: 'Hata veya düzeltme talimatını yazın...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  filled: true,
                  fillColor: isDark 
                      ? Colors.grey[800] 
                      : Colors.grey[100],
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Lütfen açıklama girin';
                  }
                  return null;
                },
              ),
              
              const SizedBox(height: 16),
              
              // Selected Fields Summary
              if (_selectedFields.isNotEmpty)
                _buildSelectedFieldsSummary(isDark),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSubmitting ? null : () => Navigator.pop(context),
          child: const Text('İptal'),
        ),
        ElevatedButton(
          onPressed: _isSubmitting || _selectedFields.isEmpty
              ? null
              : _submitAnnotations,
          style: ElevatedButton.styleFrom(
            backgroundColor: _selectedType.colorHex.toColor(),
          ),
          child: _isSubmitting
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : Text('Ekle (${_selectedFields.length})'),
        ),
      ],
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  Widget _buildFieldSelector(bool isDark) {
    return Container(
      constraints: const BoxConstraints(maxHeight: 150),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: ListView.builder(
        shrinkWrap: true,
        itemCount: widget.availableFields.length,
        itemBuilder: (context, index) {
          final field = widget.availableFields[index];
          final isSelected = _selectedFields.contains(field.key);
          
          return CheckboxListTile(
            title: Text(field.label),
            value: isSelected,
            onChanged: (bool? value) {
              setState(() {
                if (value == true) {
                  _selectedFields.add(field.key);
                } else {
                  _selectedFields.remove(field.key);
                }
              });
            },
            controlAffinity: ListTileControlAffinity.leading,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 8,
              vertical: 4,
            ),
          );
        },
      ),
    );
  }

  Widget _buildTypeSelector(bool isDark) {
    return Row(
      children: AnnotationType.values.map((type) {
        final isSelected = _selectedType == type;
        return Expanded(
          child: GestureDetector(
            onTap: () => setState(() => _selectedType = type),
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 4),
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: isSelected 
                    ? type.colorHex.toColor() 
                    : (isDark ? Colors.grey[800] : Colors.grey[200]),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isSelected 
                      ? type.colorHex.toColor() 
                      : Colors.grey.shade300,
                ),
              ),
              child: Text(
                type.displayName,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: isSelected ? Colors.white : null,
                  fontWeight: isSelected ? FontWeight.bold : null,
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildSeveritySelector(bool isDark) {
    return Row(
      children: AnnotationSeverity.values.map((severity) {
        final isSelected = _selectedSeverity == severity;
        return Expanded(
          child: GestureDetector(
            onTap: () => setState(() => _selectedSeverity = severity),
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 4),
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: isSelected 
                    ? _getSeverityColor(severity) 
                    : (isDark ? Colors.grey[800] : Colors.grey[200]),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isSelected 
                      ? _getSeverityColor(severity) 
                      : Colors.grey.shade300,
                ),
              ),
              child: Text(
                severity.displayName,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: isSelected ? Colors.white : null,
                  fontWeight: isSelected ? FontWeight.bold : null,
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildSelectedFieldsSummary(bool isDark) {
    final selectedLabels = widget.availableFields
        .where((f) => _selectedFields.contains(f.key))
        .map((f) => f.label)
        .toList();

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[800] : Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Seçilen Alanlar:',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: selectedLabels.map((label) {
              return Chip(
                label: Text(
                  label,
                  style: const TextStyle(fontSize: 11),
                ),
                backgroundColor: _selectedType.colorHex.toColor().withValues(alpha: 0.2),
                deleteIcon: const Icon(Icons.close, size: 16),
                onDeleted: () {
                  final field = widget.availableFields.firstWhere(
                    (f) => f.label == label,
                  );
                  setState(() => _selectedFields.remove(field.key));
                },
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Color _getSeverityColor(AnnotationSeverity severity) {
    switch (severity) {
      case AnnotationSeverity.low:
        return Colors.blue;
      case AnnotationSeverity.medium:
        return Colors.orange;
      case AnnotationSeverity.high:
        return Colors.red;
    }
  }
}

/// Field option for selection
class FieldOption {
  final String key;
  final String label;
  final String? category;

  const FieldOption({
    required this.key,
    required this.label,
    this.category,
  });
}

/// Extension to convert hex string to Color
extension ColorExtension on String {
  Color toColor() {
    final hex = replaceFirst('#', '');
    return Color(int.parse('FF$hex', radix: 16));
  }
}

/// Show annotation dialog
Future<bool> showAdminAnnotationDialog({
  required BuildContext context,
  required String reportId,
  required List<FieldOption> availableFields,
  required String adminId,
  required String adminName,
  required Function(List<AdminAnnotation>) onAnnotationsAdded,
}) {
  return showDialog<bool>(
    context: context,
    builder: (context) => AdminAnnotationDialog(
      reportId: reportId,
      availableFields: availableFields,
      adminId: adminId,
      adminName: adminName,
      onAnnotationsAdded: onAnnotationsAdded,
    ),
  ).then((result) => result ?? false);
}