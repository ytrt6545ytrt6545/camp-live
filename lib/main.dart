import 'package:flutter/material.dart';
import 'core/plugin_registry.dart';
import 'core/ui_renderer.dart';
import 'core/base_plugin.dart';
import 'plugins/catering_plugin.dart';
import 'plugins/asset_plugin.dart';

void main() {
  // 啟動前註冊插件
  final registry = PluginRegistry();
  registry.register(CateringPlugin());
  registry.register(AssetPlugin());

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
  late BasePlugin _activePlugin;

  @override
  void initState() {
    super.initState();
    final plugins = PluginRegistry().getAllPlugins();
    _activePlugin = plugins.isNotEmpty ? plugins.first : CateringPlugin();
    _initializeValuesForPlugin(_activePlugin);
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

  void _handleSave() {
    _activePlugin.onAction('save', _currentValues);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('已儲存 ${_activePlugin.name} 的資料（請查看 Console）')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final plugins = PluginRegistry().getAllPlugins();

    return Scaffold(
      appBar: AppBar(
        title: Text(_activePlugin.name),
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
      ),
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 左側導航列 (Sidebar)
          Container(
            width: 250,
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(8), // Glassmorphism 背景
              border: Border(
                right: BorderSide(color: Colors.white.withAlpha(20)),
              ),
            ),
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 16),
              itemCount: plugins.length,
              itemBuilder: (context, index) {
                final plugin = plugins[index];
                final isActive = _activePlugin.id == plugin.id;
                
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  child: InkWell(
                    onTap: () => _switchPlugin(plugin),
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
          
          // 右側動態內容區
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(32.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  DynamicUIRenderer(
                    properties: _activePlugin.properties,
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
                      '儲存',
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
  }
}
