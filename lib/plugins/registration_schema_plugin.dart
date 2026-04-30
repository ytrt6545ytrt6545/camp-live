import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import '../core/base_plugin.dart';

class RegistrationSchemaPlugin extends BasePlugin {
  @override
  String get name => '報名表單設定';

  @override
  String get id => 'registration_schema';

  @override
  int get requiredRank => 90;

  @override
  Widget? buildCustomUI(
    BuildContext context,
    Map<String, dynamic> currentValues,
    Function(String key, dynamic value) onChanged,
  ) {
    return _SchemaEditor(pluginId: id);
  }
}

class _SchemaEditor extends StatefulWidget {
  final String pluginId;

  const _SchemaEditor({required this.pluginId});

  @override
  State<_SchemaEditor> createState() => _SchemaEditorState();
}

class _SchemaEditorState extends State<_SchemaEditor> {
  final List<Map<String, dynamic>> _fields = [];
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadSchema();
  }

  Future<void> _loadSchema() async {
    try {
      final snapshot = await FirebaseDatabase.instance.ref('schemas/registration/master').get();
      if (snapshot.exists) {
        final data = snapshot.value as Map<dynamic, dynamic>;
        if (data['fields'] != null) {
          final fieldsList = data['fields'] as List<dynamic>;
          setState(() {
            _fields.clear();
            for (var f in fieldsList) {
              _fields.add(Map<String, dynamic>.from(f as Map));
            }
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading schema: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _saveSchema() async {
    setState(() => _isSaving = true);
    try {
      await FirebaseDatabase.instance.ref('schemas/registration/master').set({
        'fields': _fields,
        'updatedAt': ServerValue.timestamp,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('表單架構儲存成功'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('儲存失敗: $e'), backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _addField() {
    setState(() {
      _fields.add({
        'key': 'field_${DateTime.now().millisecondsSinceEpoch}',
        'label': '新欄位',
        'type': 'text',
        'required': false,
        'options': '',
      });
    });
  }

  void _removeField(int index) {
    setState(() {
      _fields.removeAt(index);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              '大會標準表單定義 (Schema Master)',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            ElevatedButton.icon(
              onPressed: _addField,
              icon: const Icon(Icons.add),
              label: const Text('新增欄位'),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.indigoAccent),
            ),
          ],
        ),
        const SizedBox(height: 8),
        const Text(
          '注意：「姓名」與「電話」為系統底層固定欄位，不需在此新增。此處請定義額外的動態欄位（如車牌、葷素）。',
          style: TextStyle(color: Colors.white54),
        ),
        const SizedBox(height: 24),
        
        if (_fields.isEmpty)
          const Padding(
            padding: EdgeInsets.all(32.0),
            child: Center(child: Text('目前沒有自訂欄位', style: TextStyle(color: Colors.white54))),
          ),
          
        for (int i = 0; i < _fields.length; i++)
          _buildFieldEditor(i),
          
        const SizedBox(height: 32),
        ElevatedButton(
          onPressed: _isSaving ? null : _saveSchema,
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
            backgroundColor: Colors.green.shade600,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: _isSaving 
            ? const CircularProgressIndicator(color: Colors.white)
            : const Text('儲存全域表單設定', style: TextStyle(fontSize: 18, color: Colors.white)),
        ),
      ],
    );
  }

  Widget _buildFieldEditor(int index) {
    final field = _fields[index];
    
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  initialValue: field['key'],
                  decoration: const InputDecoration(
                    labelText: '欄位識別碼 (Key, 英文)',
                    labelStyle: TextStyle(color: Colors.white54),
                  ),
                  style: const TextStyle(color: Colors.white),
                  onChanged: (v) => field['key'] = v,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: TextFormField(
                  initialValue: field['label'],
                  decoration: const InputDecoration(
                    labelText: '顯示名稱 (Label)',
                    labelStyle: TextStyle(color: Colors.white54),
                  ),
                  style: const TextStyle(color: Colors.white),
                  onChanged: (v) => field['label'] = v,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.delete, color: Colors.redAccent),
                onPressed: () => _removeField(index),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: field['type'],
                  dropdownColor: const Color(0xFF1E293B),
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: '輸入類型 (Type)',
                    labelStyle: TextStyle(color: Colors.white54),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'text', child: Text('文字輸入')),
                    DropdownMenuItem(value: 'dropdown', child: Text('下拉選單')),
                    DropdownMenuItem(value: 'boolean', child: Text('勾選框 (是/否)')),
                  ],
                  onChanged: (v) {
                    if (v != null) setState(() => field['type'] = v);
                  },
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Row(
                  children: [
                    Checkbox(
                      value: field['required'] ?? false,
                      onChanged: (v) {
                        setState(() => field['required'] = v ?? false);
                      },
                      fillColor: MaterialStateProperty.resolveWith((states) => Colors.indigoAccent),
                    ),
                    const Text('必填欄位', style: TextStyle(color: Colors.white)),
                  ],
                ),
              ),
            ],
          ),
          if (field['type'] == 'dropdown') ...[
            const SizedBox(height: 16),
            TextFormField(
              initialValue: field['options'],
              decoration: const InputDecoration(
                labelText: '選項清單 (以逗號分隔，例如: 葷,素)',
                labelStyle: TextStyle(color: Colors.white54),
              ),
              style: const TextStyle(color: Colors.white),
              onChanged: (v) => field['options'] = v,
            ),
          ]
        ],
      ),
    );
  }
}
