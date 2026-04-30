import 'package:flutter/material.dart';
import '../core/base_plugin.dart';
import '../core/models/organization_model.dart';
import '../core/services/permission_service.dart';
import 'package:firebase_database/firebase_database.dart';

class OrgManagementPlugin extends BasePlugin {
  @override
  String get name => '組織管理';

  @override
  String get id => 'org_management';

  @override
  int get requiredRank => 100; // 系統管理員

  @override
  Widget? buildCustomUI(BuildContext context, Map<String, dynamic> currentValues, Function(String, dynamic) onChanged) {
    return _OrgManagementUI(pluginId: id);
  }
}

class _OrgManagementUI extends StatefulWidget {
  final String pluginId;
  const _OrgManagementUI({required this.pluginId});

  @override
  State<_OrgManagementUI> createState() => _OrgManagementUIState();
}

class _OrgManagementUIState extends State<_OrgManagementUI> {
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref('organizations');
  List<OrganizationModel> _organizations = [];

  final TextEditingController _newOrgNameCtrl = TextEditingController();
  String? _selectedParentPath;

  @override
  void initState() {
    super.initState();
    _loadOrganizations();
  }

  void _loadOrganizations() {
    _dbRef.onValue.listen((event) {
      final data = event.snapshot.value as Map<dynamic, dynamic>?;
      if (data != null) {
        final List<OrganizationModel> loaded = [];
        data.forEach((key, value) {
          loaded.add(OrganizationModel.fromJson(Map<String, dynamic>.from(value)));
        });
        loaded.sort((a, b) => a.path.compareTo(b.path));
        if (mounted) {
          setState(() {
            _organizations = loaded;
          });
        }
      } else {
        _initializeDefaultOrganization();
      }
    });
  }

  void _initializeDefaultOrganization() async {
    final defaultOrg = const OrganizationModel(id: 'org_global', name: '全域', path: 'GLOBAL');
    await _dbRef.child(defaultOrg.id).set(defaultOrg.toJson());
  }

  void _addOrganization() async {
    final name = _newOrgNameCtrl.text.trim();
    if (name.isEmpty) return;

    final parentPath = _selectedParentPath ?? 'GLOBAL';
    final path = parentPath == 'GLOBAL' ? 'GLOBAL/$name' : '$parentPath/$name';
    final id = DateTime.now().millisecondsSinceEpoch.toString();
    
    final newOrg = OrganizationModel(id: id, name: name, path: path);
    await _dbRef.child(id).set(newOrg.toJson());

    if (mounted) {
      setState(() {
        _newOrgNameCtrl.clear();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('已建立組織: $path')),
      );
    }
  }

  void _assignUserDialog(String orgPath) {
    showDialog(
      context: context,
      builder: (ctx) {
        return _AssignUserDialog(orgPath: orgPath);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('組織樹狀結構', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withAlpha(12),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withAlpha(25)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: _organizations.map((org) {
              final indent = org.path.split('/').length - 1;
              return Padding(
                padding: EdgeInsets.only(left: indent * 20.0, bottom: 8.0),
                child: Row(
                  children: [
                    const Icon(Icons.account_tree, color: Colors.indigoAccent, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${org.name} (${org.path})',
                        style: const TextStyle(color: Colors.white70, fontSize: 16),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.person_add, color: Colors.greenAccent),
                      tooltip: '指派負責人',
                      onPressed: () => _assignUserDialog(org.path),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 32),
        const Text('新增組織', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withAlpha(12),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withAlpha(25)),
          ),
          child: Row(
            children: [
              Expanded(
                flex: 2,
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: '父組織',
                    labelStyle: TextStyle(color: Colors.white54),
                    filled: true,
                    fillColor: Colors.black26,
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      dropdownColor: const Color(0xFF1E293B),
                      style: const TextStyle(color: Colors.white),
                      value: _selectedParentPath,
                      isDense: true,
                      isExpanded: true, // 新增此行以防止長文字溢出
                      items: [
                        const DropdownMenuItem(value: null, child: Text('無 (GLOBAL)')),
                        ..._organizations.map((o) => DropdownMenuItem(value: o.path, child: Text(o.path))),
                      ],
                      onChanged: (val) => setState(() => _selectedParentPath = val),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                flex: 3,
                child: TextField(
                  controller: _newOrgNameCtrl,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: '新組織代號 (如: IT)',
                    labelStyle: TextStyle(color: Colors.white54),
                    filled: true,
                    fillColor: Colors.black26,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              ElevatedButton(
                onPressed: _addOrganization,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.indigoAccent,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
                ),
                child: const Text('新增', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _AssignUserDialog extends StatefulWidget {
  final String orgPath;
  const _AssignUserDialog({required this.orgPath});

  @override
  State<_AssignUserDialog> createState() => _AssignUserDialogState();
}

class _AssignUserDialogState extends State<_AssignUserDialog> {
  final TextEditingController _searchCtrl = TextEditingController();
  List<dynamic> _searchResults = [];

  void _search() {
    final query = _searchCtrl.text.trim();
    setState(() {
      _searchResults = PermissionService.instance.searchUsers(query);
    });
  }

  void _assign(String uid) {
    PermissionService.instance.assignUserToGroup(uid, widget.orgPath);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF1E293B),
      title: Text('指派負責人 - ${widget.orgPath}', style: const TextStyle(color: Colors.white)),
      content: SizedBox(
        width: 400,
        height: 300,
        child: Column(
          children: [
            TextField(
              controller: _searchCtrl,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: '輸入使用者名稱...',
                hintStyle: const TextStyle(color: Colors.white54),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.search, color: Colors.white70),
                  onPressed: _search,
                ),
                filled: true,
                fillColor: Colors.black26,
              ),
              onSubmitted: (_) => _search(),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView.builder(
                itemCount: _searchResults.length,
                itemBuilder: (ctx, index) {
                  final user = _searchResults[index];
                  return ListTile(
                    title: Text(user.name, style: const TextStyle(color: Colors.white)),
                    subtitle: Text('${user.roleId} (Rank: ${user.rank})', style: const TextStyle(color: Colors.white54)),
                    trailing: ElevatedButton(
                      onPressed: () => _assign(user.uid),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.greenAccent),
                      child: const Text('指派', style: TextStyle(color: Colors.black)),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消', style: TextStyle(color: Colors.white70)),
        ),
      ],
    );
  }
}
