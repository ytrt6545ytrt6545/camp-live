import 'package:flutter/foundation.dart';
import 'property_schema.dart';

/// 插件的抽象母類別，所有功能模組皆需繼承此類別
abstract class BasePlugin {
  /// 插件的顯示名稱
  String get name;

  /// 插件的唯一識別碼
  String get id;

  /// 插件的版本號
  String get version => '1.0.0';

  /// 插件定義的可配置屬性清單
  List<PluginProperty> get properties => [];

  /// 插件載入時的初始化邏輯
  void onLoad() {
    debugPrint('插件載入: $name ($id) v$version');
  }

  /// 插件卸載時的清理邏輯
  void onUnload() {
    debugPrint('插件卸載: $name ($id)');
  }

  /// 處理插件動作（例如：按鈕點擊）
  void onAction(String actionId, Map<String, dynamic> data) {
    debugPrint('插件動作 [$actionId]: $data');
  }
}
