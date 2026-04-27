import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
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

  /// 插件被解除載入時的生命週期鉤子
  void onUnload() {}

  /// 將資料儲存至 Firestore 雲端資料庫
  Future<void> saveToCloud(Map<String, dynamic> data) async {
    try {
      final timestamp = FieldValue.serverTimestamp();
      final finalData = Map<String, dynamic>.from(data);
      finalData['updatedAt'] = timestamp;

      await FirebaseFirestore.instance
          .collection('plugin_data')
          .doc(id)
          .collection('submissions')
          .add(finalData);
          
      debugPrint('[$name] 資料已成功同步至雲端 Firestore');
    } catch (e) {
      debugPrint('[$name] 雲端同步失敗: $e');
      rethrow;
    }
  }

  /// 處理插件動作（例如：按鈕點擊）
  void onAction(String actionId, Map<String, dynamic> data) {
    debugPrint('插件動作 [$actionId]: $data');
  }
}
