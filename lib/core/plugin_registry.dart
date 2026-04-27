import 'package:flutter/foundation.dart';
import 'base_plugin.dart';

/// 插件註冊中心 (單例模式)
class PluginRegistry {
  // 私有建構子
  PluginRegistry._internal();

  // 單例實例
  static final PluginRegistry _instance = PluginRegistry._internal();

  // 工廠建構子
  factory PluginRegistry() => _instance;

  // 已註冊的插件清單
  final Map<String, BasePlugin> _plugins = {};

  /// 註冊插件
  void register(BasePlugin plugin) {
    if (_plugins.containsKey(plugin.id)) {
      debugPrint('警告: 插件 ID ${plugin.id} 已存在，正在覆蓋...');
    }
    _plugins[plugin.id] = plugin;
    plugin.onLoad();
  }

  /// 註銷插件
  void unregister(String id) {
    final plugin = _plugins.remove(id);
    plugin?.onUnload();
  }

  /// 取得所有已註冊插件
  List<BasePlugin> getAllPlugins() => _plugins.values.toList();

  /// 根據 ID 取得特定插件
  BasePlugin? getPlugin(String id) => _plugins[id];
}
