import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:csv/csv.dart';
import 'package:universal_html/html.dart' as html;
import 'dart:convert';
import '../core/base_plugin.dart';

class PersonnelPlugin extends BasePlugin {
  @override
  String get name => '人員總表與報名';

  @override
  String get id => 'personnel_master';

  @override
  int get requiredRank => 10;

  @override
  Widget? buildCustomUI(
    BuildContext context,
    Map<String, dynamic> currentValues,
    Function(String key, dynamic value) onChanged,
  ) {
    return const _PersonnelDashboard();
  }
}

class _PersonnelDashboard extends StatefulWidget {
  const _PersonnelDashboard();

  @override
  State<_PersonnelDashboard> createState() => _PersonnelDashboardState();
}

class _PersonnelDashboardState extends State<_PersonnelDashboard> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TabBar(
          controller: _tabController,
          indicatorColor: Colors.cyanAccent,
          labelColor: Colors.cyanAccent,
          unselectedLabelColor: Colors.white54,
          tabs: const [
            Tab(icon: Icon(Icons.person_add), text: '新增報名'),
            Tab(icon: Icon(Icons.people), text: '人員總表'),
          ],
        ),
        const SizedBox(height: 16),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: const [
              _RegistrationFormTab(),
              _PersonnelListTab(),
            ],
          ),
        ),
      ],
    );
  }
}

class _RegistrationFormTab extends StatefulWidget {
  const _RegistrationFormTab();

  @override
  State<_RegistrationFormTab> createState() => _RegistrationFormTabState();
}

class _RegistrationFormTabState extends State<_RegistrationFormTab> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = true;
  bool _isSubmitting = false;
  
  List<Map<String, dynamic>> _schemaFields = [];
  final Map<String, dynamic> _formData = {};

  final TextEditingController _nameCtrl = TextEditingController();
  final TextEditingController _phoneCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadSchema();
  }

  Future<void> _loadSchema() async {
    try {
      final snap = await FirebaseDatabase.instance.ref('schemas/registration/master').get();
      if (snap.exists) {
        final data = snap.value as Map<dynamic, dynamic>;
        if (data['fields'] != null) {
          final fieldsList = data['fields'] as List<dynamic>;
          setState(() {
            _schemaFields = fieldsList.map((f) => Map<String, dynamic>.from(f as Map)).toList();
            // Initialize form data
            for (var f in _schemaFields) {
              if (f['type'] == 'boolean') {
                _formData[f['key']] = false;
              } else {
                _formData[f['key']] = '';
              }
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

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() => _isSubmitting = true);
    
    try {
      final name = _nameCtrl.text.trim();
      final phone = _phoneCtrl.text.trim();

      // Shadow Account checking
      final usersRef = FirebaseDatabase.instance.ref('users');
      final usersSnap = await usersRef.get();
      
      String? existingUid;
      Map<dynamic, dynamic>? existingData;

      if (usersSnap.exists) {
        final allUsers = usersSnap.value as Map<dynamic, dynamic>;
        for (var entry in allUsers.entries) {
          final uData = entry.value as Map<dynamic, dynamic>;
          if (uData['phone'] == phone) {
            existingUid = entry.key as String;
            existingData = uData;
            break;
          }
        }
      }

      final targetUid = existingUid ?? 'user_${DateTime.now().millisecondsSinceEpoch}';
      
      // Merge data
      final Map<String, dynamic> finalData = {
        'name': name,
        'phone': phone,
        'registeredAt': ServerValue.timestamp,
        'status': 'registered',
      };
      
      // Add dynamic fields
      _formData.forEach((k, v) {
        finalData[k] = v;
      });

      // Keep shadow account properties if exist
      if (existingData != null) {
        if (existingData['rank'] != null) finalData['rank'] = existingData['rank'];
        if (existingData['managedGroups'] != null) finalData['managedGroups'] = existingData['managedGroups'];
      }

      await FirebaseDatabase.instance.ref('users/$targetUid').update(finalData);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('報名成功！'), backgroundColor: Colors.green),
        );
        _formKey.currentState!.reset();
        _nameCtrl.clear();
        _phoneCtrl.clear();
        setState(() {
          for (var f in _schemaFields) {
            if (f['type'] == 'boolean') {
              _formData[f['key']] = false;
            } else {
              _formData[f['key']] = '';
            }
          }
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('報名失敗: $e'), backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                '基本資料 (固定欄位)',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.cyanAccent),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _nameCtrl,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(labelText: '姓名', labelStyle: TextStyle(color: Colors.white54)),
                validator: (v) => v == null || v.isEmpty ? '請輸入姓名' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _phoneCtrl,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(labelText: '電話號碼 (影子帳號識別鍵)', labelStyle: TextStyle(color: Colors.white54)),
                validator: (v) => v == null || v.isEmpty ? '請輸入電話' : null,
              ),
              
              if (_schemaFields.isNotEmpty) ...[
                const SizedBox(height: 32),
                const Text(
                  '大會動態欄位',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.cyanAccent),
                ),
                const SizedBox(height: 16),
                ..._schemaFields.map(_buildDynamicField).toList(),
              ],

              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: _isSubmitting ? null : _submitForm,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: Colors.cyan.shade700,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: _isSubmitting
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text('送出報名', style: TextStyle(fontSize: 18, color: Colors.white)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDynamicField(Map<String, dynamic> field) {
    final key = field['key'] as String;
    final label = field['label'] as String;
    final type = field['type'] as String;
    final isRequired = field['required'] == true;

    if (type == 'text') {
      return Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: TextFormField(
          initialValue: _formData[key],
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(labelText: label, labelStyle: const TextStyle(color: Colors.white54)),
          validator: isRequired ? (v) => v == null || v.isEmpty ? '請輸入$label' : null : null,
          onChanged: (v) => _formData[key] = v,
        ),
      );
    } else if (type == 'dropdown') {
      final optionsStr = field['options'] as String? ?? '';
      final options = optionsStr.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
      
      // Ensure initial value is in options if not empty
      String? currentValue = _formData[key];
      if (currentValue == null || currentValue.isEmpty || !options.contains(currentValue)) {
         currentValue = options.isNotEmpty ? options.first : null;
         _formData[key] = currentValue;
      }

      return Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: DropdownButtonFormField<String>(
          value: currentValue,
          dropdownColor: const Color(0xFF1E293B),
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(labelText: label, labelStyle: const TextStyle(color: Colors.white54)),
          validator: isRequired ? (v) => v == null || v.isEmpty ? '請選擇$label' : null : null,
          items: options.map((opt) => DropdownMenuItem(value: opt, child: Text(opt))).toList(),
          onChanged: (v) {
            if (v != null) setState(() => _formData[key] = v);
          },
        ),
      );
    } else if (type == 'boolean') {
      return Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Row(
          children: [
            Checkbox(
              value: _formData[key] == true,
              onChanged: (v) {
                setState(() => _formData[key] = v ?? false);
              },
              fillColor: MaterialStateProperty.resolveWith((states) => Colors.cyanAccent),
            ),
            Text(label, style: const TextStyle(color: Colors.white)),
          ],
        ),
      );
    }
    
    return const SizedBox.shrink();
  }
}

class _PersonnelListTab extends StatefulWidget {
  const _PersonnelListTab();

  @override
  State<_PersonnelListTab> createState() => _PersonnelListTabState();
}

class _PersonnelListTabState extends State<_PersonnelListTab> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _allUsers = [];
  List<Map<String, dynamic>> _filteredUsers = [];
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    try {
      final snap = await FirebaseDatabase.instance.ref('users').get();
      if (snap.exists) {
        final data = snap.value as Map<dynamic, dynamic>;
        final List<Map<String, dynamic>> users = [];
        for (var entry in data.entries) {
          final uMap = Map<String, dynamic>.from(entry.value as Map);
          uMap['uid'] = entry.key as String;
          users.add(uMap);
        }
        setState(() {
          _allUsers = users;
          _filteredUsers = users;
        });
      }
    } catch (e) {
      debugPrint('Error loading users: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _filterUsers(String query) {
    setState(() {
      _searchQuery = query.toLowerCase();
      _filteredUsers = _allUsers.where((u) {
        // Search across all string values in the user map
        return u.values.any((val) => val.toString().toLowerCase().contains(_searchQuery));
      }).toList();
    });
  }

  void _exportCSV() {
    if (_allUsers.isEmpty) return;

    // Collect all unique keys from all users to form columns
    final Set<String> allKeys = {'uid', 'name', 'phone', 'rank', 'managedGroups', 'status'};
    for (var u in _allUsers) {
      allKeys.addAll(u.keys);
    }
    final columns = allKeys.toList();

    List<List<dynamic>> rows = [];
    // Header
    rows.add(columns);
    
    // Data
    for (var u in _allUsers) {
      final row = columns.map((col) => u[col] ?? '').toList();
      rows.add(row);
    }

    String csvData = Csv().encode(rows);
    // Add UTF-8 BOM for Excel
    final bytes = utf8.encode(csvData);
    final bom = [0xEF, 0xBB, 0xBF];
    final bomBytes = [...bom, ...bytes];

    final blob = html.Blob([bomBytes], 'text/csv;charset=utf-8');
    final url = html.Url.createObjectUrlFromBlob(blob);
    final anchor = html.AnchorElement(href: url)
      ..setAttribute("download", "personnel_export_${DateTime.now().millisecondsSinceEpoch}.csv")
      ..click();
    html.Url.revokeObjectUrl(url);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search, color: Colors.white54),
                  hintText: '搜尋姓名、電話、車牌...',
                  hintStyle: const TextStyle(color: Colors.white54),
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.05),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
                onChanged: _filterUsers,
              ),
            ),
            const SizedBox(width: 16),
            ElevatedButton.icon(
              onPressed: _exportCSV,
              icon: const Icon(Icons.download),
              label: const Text('匯出 CSV'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green.shade600,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Expanded(
          child: ListView.builder(
            itemCount: _filteredUsers.length,
            itemBuilder: (context, index) {
              final u = _filteredUsers[index];
              final name = u['name'] ?? '未知';
              final phone = u['phone'] ?? '未知';
              final rank = u['rank']?.toString() ?? '1';
              final groups = u['managedGroups']?.toString() ?? '';

              return Card(
                color: Colors.white.withOpacity(0.05),
                margin: const EdgeInsets.only(bottom: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.cyan.withOpacity(0.2),
                    child: Text(name.toString().substring(0, 1), style: const TextStyle(color: Colors.cyanAccent)),
                  ),
                  title: Text('$name ($phone)', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  subtitle: Text('權限等級: $rank | 負責群組: $groups', style: const TextStyle(color: Colors.white54)),
                  trailing: const Icon(Icons.chevron_right, color: Colors.white54),
                  onTap: () {
                    // Show full info dialog
                    showDialog(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        backgroundColor: const Color(0xFF1E293B),
                        title: Text('$name 的詳細資料', style: const TextStyle(color: Colors.white)),
                        content: SingleChildScrollView(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: u.entries.map((e) => Padding(
                              padding: const EdgeInsets.only(bottom: 8.0),
                              child: Text('${e.key}: ${e.value}', style: const TextStyle(color: Colors.white70)),
                            )).toList(),
                          ),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx),
                            child: const Text('關閉', style: TextStyle(color: Colors.cyanAccent)),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
