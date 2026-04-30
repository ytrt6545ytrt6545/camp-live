import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'core/plugin_registry.dart';
import 'core/ui_renderer.dart';
import 'core/base_plugin.dart';
import 'core/services/permission_service.dart';
import 'plugins/startup_wizard_plugin.dart';
import 'plugins/registration_schema_plugin.dart';
import 'plugins/personnel_plugin.dart';
import 'plugins/catering_plugin.dart';
import 'plugins/asset_plugin.dart';
import 'plugins/org_management_plugin.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 初始化 Firebase
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    debugPrint('Firebase 初始化成功');
  } catch (e) {
    debugPrint('Firebase 初始化失敗: $e');
  }

  // 啟動前註冊插件
  final registry = PluginRegistry();
  registry.register(CateringPlugin());
  registry.register(AssetPlugin());
  registry.register(OrgManagementPlugin());
  registry.register(StartupWizardPlugin());
  registry.register(RegistrationSchemaPlugin());
  registry.register(PersonnelPlugin());

  // 初始化權限服務
  await PermissionService.instance.init();

  runApp(const CampLiveApp());
}

class CampLiveApp extends StatelessWidget {
  const CampLiveApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'camp-live',
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF0F172A), // var(--bg-color)
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF6366F1), // indigo
          secondary: Color(0xFFA855F7), // purple
        ),
      ),
      home: const PluginHostPage(),
    );
  }
}

class PluginHostPage extends StatefulWidget {
  const PluginHostPage({super.key});

  @override
  State<PluginHostPage> createState() => _PluginHostPageState();
}

class _PluginHostPageState extends State<PluginHostPage> {
  final Map<String, dynamic> _currentValues = {};
  BasePlugin? _activePlugin;

  @override
  void initState() {
    super.initState();
    final plugins = PluginRegistry().getAllPlugins()
        .where((p) => PermissionService.instance.hasAccess(p.requiredRank))
        .toList();
    _activePlugin = plugins.isNotEmpty ? plugins.first : null;
    if (_activePlugin != null) {
      _initializeValuesForPlugin(_activePlugin!);
    }
  }

  void _initializeValuesForPlugin(BasePlugin plugin) {
    _currentValues.clear();
    for (var prop in plugin.properties) {
      if (prop.defaultValue != null) {
        _currentValues[prop.key] = prop.defaultValue;
      }
    }
  }

  void _switchPlugin(BasePlugin plugin) {
    setState(() {
      _activePlugin = plugin;
      _initializeValuesForPlugin(plugin);
    });
  }

  void _handlePropertyChange(String key, dynamic value) {
    setState(() {
      _currentValues[key] = value;
    });
  }

  void _handleSave() async {
    if (_activePlugin == null) return;
    
    // 呼叫插件原本的 action (處理本地邏輯)
    _activePlugin!.onAction('save', _currentValues);

    // 呼叫雲端儲存
    try {
      await _activePlugin!.saveToCloud(_currentValues);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('已同步 ${_activePlugin!.name} 資料至雲端 Realtime Database')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('雲端儲存失敗: $e'), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  Widget _buildSidebar(List<BasePlugin> plugins, {bool isDrawer = false}) {
    return Container(
      width: 250,
      decoration: BoxDecoration(
        color: isDrawer ? const Color(0xFF0F172A) : Colors.white.withAlpha(8), // Drawer 時使用實底色
        border: Border(
          right: BorderSide(color: Colors.white.withAlpha(20)),
        ),
      ),
      child: SafeArea(
        child: ListView.builder(
          padding: const EdgeInsets.symmetric(vertical: 16),
          itemCount: plugins.length,
          itemBuilder: (context, index) {
            final plugin = plugins[index];
            final isActive = _activePlugin?.id == plugin.id;
            
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: InkWell(
                onTap: () {
                  _switchPlugin(plugin);
                  if (isDrawer) {
                    Navigator.pop(context);
                  }
                },
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: isActive ? const Color(0xFF6366F1).withAlpha(40) : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isActive ? const Color(0xFF6366F1).withAlpha(100) : Colors.transparent,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.extension,
                        color: isActive ? Colors.white : Colors.white54,
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          plugin.name,
                          style: TextStyle(
                            color: isActive ? Colors.white : Colors.white70,
                            fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final plugins = PluginRegistry().getAllPlugins()
        .where((p) => PermissionService.instance.hasAccess(p.requiredRank))
        .toList();

    final bool needsWizard = PermissionService.instance.wizardStep < 4;
    
    // 如果需要引導精靈，強制顯示它
    if (needsWizard) {
      final wizardPlugin = PluginRegistry().getPlugin('startup_wizard');
      return Scaffold(
        body: wizardPlugin != null 
          ? wizardPlugin.buildCustomUI(context, {}, (k, v) => setState(() {})) 
          : const Center(child: Text('系統啟動中...')),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 768;

        return Scaffold(
          appBar: AppBar(
            title: Text(_activePlugin?.name ?? '無存取權限'),
            backgroundColor: Colors.transparent,
            elevation: 0,
            flexibleSpace: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF6366F1), Color(0xFFA855F7)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
            ),
            actions: [
              if (PermissionService.instance.currentUser != null && PermissionService.instance.currentUser!.managedGroups.isNotEmpty)
                PopupMenuButton<String>(
                  icon: const Icon(Icons.switch_account, color: Colors.white),
                  tooltip: '切換身分',
                  color: const Color(0xFF1E293B),
                  onSelected: (String groupId) {
                    setState(() {
                      PermissionService.instance.setActiveGroup(groupId);
                      // 重置 plugin 狀態
                      final updatedPlugins = PluginRegistry().getAllPlugins()
                          .where((p) => PermissionService.instance.hasAccess(p.requiredRank))
                          .toList();
                      if (updatedPlugins.isNotEmpty) {
                        _switchPlugin(updatedPlugins.first);
                      } else {
                        _activePlugin = null;
                        _currentValues.clear();
                      }
                    });
                  },
                  itemBuilder: (BuildContext context) {
                    return PermissionService.instance.currentUser!.managedGroups.map((String group) {
                      final isActive = group == PermissionService.instance.activeGroupId;
                      return PopupMenuItem<String>(
                        value: group,
                        child: Row(
                          children: [
                            Icon(
                              isActive ? Icons.check_circle : Icons.workspaces_outline,
                              color: isActive ? Colors.greenAccent : Colors.white54,
                              size: 20,
                            ),
                            const SizedBox(width: 12),
                            Text(group, style: TextStyle(
                              color: isActive ? Colors.white : Colors.white70,
                              fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                            )),
                          ],
                        ),
                      );
                    }).toList();
                  },
                ),
              const SizedBox(width: 16),
            ],
          ),
          drawer: isMobile ? Drawer(
            child: _buildSidebar(plugins, isDrawer: true),
          ) : null,
          body: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (!isMobile) _buildSidebar(plugins),
              
              // 右側動態內容區
              Expanded(
                child: _activePlugin == null 
                  ? const Center(
                      child: Text(
                        '您目前沒有權限存取任何功能',
                        style: TextStyle(fontSize: 18, color: Colors.white54),
                      ),
                    )
                  : SingleChildScrollView(
                      padding: EdgeInsets.all(isMobile ? 16.0 : 32.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _activePlugin!.buildCustomUI(context, _currentValues, _handlePropertyChange) ??
                          DynamicUIRenderer(
                            properties: _activePlugin!.properties,
                            currentValues: _currentValues,
                            onChanged: _handlePropertyChange,
                          ),
                          const SizedBox(height: 32),
                          ElevatedButton(
                            onPressed: _handleSave,
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              backgroundColor: const Color(0xFF6366F1),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text(
                              '儲存至雲端',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                    ),
              ),
            ],
          ),
        );
      },
    );
  }
}
