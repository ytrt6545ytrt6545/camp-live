/// 定義插件屬性的類型
enum PropertyType {
  string,
  number,
  boolean,
  color,
  options,
}

/// 插件屬性定義類別
class PluginProperty {
  final String key;
  final String label;
  final PropertyType type;
  final dynamic defaultValue;
  final List<String>? options; // 僅用於 PropertyType.options

  PluginProperty({
    required this.key,
    required this.label,
    required this.type,
    this.defaultValue,
    this.options,
  });
}
