import 'package:flutter/foundation.dart';
import '../core/base_plugin.dart';
import '../core/property_schema.dart';

/// 餐飲管理模組插件
class CateringPlugin extends BasePlugin {
  @override
  String get name => '餐飲管理模組';

  @override
  String get id => 'catering_management';

  @override
  int get requiredRank => 10; // 一般組員以上可存取

  @override
  List<PluginProperty> get properties => [
        PluginProperty(
          key: 'volunteer_name',
          label: '義工姓名',
          type: PropertyType.string,
          defaultValue: '',
        ),
        PluginProperty(
          key: 'meal_type',
          label: '用餐類型',
          type: PropertyType.options,
          options: ['葷', '全素', '蛋奶素'],
          defaultValue: '葷',
        ),
        PluginProperty(
          key: 'pickup_location',
          label: '取餐地點',
          type: PropertyType.string,
          defaultValue: '',
        ),
        PluginProperty(
          key: 'is_picked_up',
          label: '是否已取餐',
          type: PropertyType.boolean,
          defaultValue: false,
        ),
      ];

  @override
  void onAction(String actionId, Map<String, dynamic> data) {
    if (actionId == 'save') {
      debugPrint('==== [$name] 儲存資料 ====');
      data.forEach((key, value) {
        debugPrint('$key: $value');
      });
      debugPrint('========================');
    } else {
      super.onAction(actionId, data);
    }
  }
}
