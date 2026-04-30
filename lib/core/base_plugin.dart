import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'property_schema.dart';
import 'services/permission_service.dart';

/// 插件的抽象母類別，所有功能模組皆需繼承此類別
abstract class BasePlugin {
  /// 插件的顯示名稱
  String get name;

  /// 插件的唯一識別碼
  String get id;

  /// 插件的版本號
  String get version => '1.0.0';

  /// 存取此插件要求的最低權限等級 (Rank)
  int get requiredRank => 0;

  /// 插件定義的可配置屬性清單
  List<PluginProperty> get properties => [];

  /// 插件載入時的初始化邏輯
  void onLoad() {
    debugPrint('插件載入: $name ($id) v$version');
  }

  /// 插件被解除載入時的生命週期鉤子
  void onUnload() {}

  /// 將資料儲存至雲端資料庫 (RTDB)
  Future<void> saveToCloud(Map<String, dynamic> data) async {
    try {
      final database = FirebaseDatabase.instance;
      final ref = database.ref('plugin_data/$id/submissions').push();
      
      final currentUser = PermissionService.instance.currentUser;
      final uid = currentUser?.uid;
      final groupId = PermissionService.instance.activeGroupId;

      await ref.set({
        ...data,
        if (uid != null) 'uid': uid,
        if (groupId != null) 'groupId': groupId,
        'updatedAt': ServerValue.timestamp,
      });
      debugPrint('[$name] 雲端儲存成功 (RTDB)');
    } catch (e) {
      debugPrint('[$name] 雲端儲存失敗: $e');
      rethrow;
    }
  }

  /// 處理插件動作（例如：按鈕點擊）
  void onAction(String actionId, Map<String, dynamic> data) {
    debugPrint('插件動作 [$actionId]: $data');
  }

  /// 若插件需要特殊的 UI，可覆寫此方法，回傳自訂的 Widget。
  /// 預設為 null，代表使用系統內建的 DynamicUIRenderer。
  Widget? buildCustomUI(
    BuildContext context,
    Map<String, dynamic> currentValues,
    Function(String key, dynamic value) onChanged,
  ) {
    return null;
  }
}
