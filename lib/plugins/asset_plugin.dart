import 'package:flutter/foundation.dart';
import '../core/base_plugin.dart';
import '../core/property_schema.dart';

class AssetPlugin extends BasePlugin {
  @override
  String get name => '資材管理模組';

  @override
  String get id => 'asset_management';

  @override
  int get requiredRank => 50; // 大組長以上可存取

  @override
  List<PluginProperty> get properties => [
    PluginProperty(
      key: 'equipment_id',
      label: '資材編號 (QR)',
      type: PropertyType.qrScanner,
      defaultValue: '',
    ),
    PluginProperty(
      key: 'equipment_name',
      label: '設備名稱',
      type: PropertyType.string,
      defaultValue: '',
    ),
    PluginProperty(
      key: 'quantity',
      label: '數量',
      type: PropertyType.number,
      defaultValue: 1,
    ),
    PluginProperty(
      key: 'is_borrowed',
      label: '是否借出',
      type: PropertyType.boolean,
      defaultValue: false,
    ),
    PluginProperty(
      key: 'borrower_signature',
      label: '領用人簽名',
      type: PropertyType.signature,
      defaultValue: '',
    ),
  ];

  @override
  void onAction(String actionId, Map<String, dynamic> data) {
    if (actionId == 'save') {
      debugPrint('[$name] 執行儲存操作: $data');
      // 未來可在此實作與後端的同步邏輯
    }
  }
}
