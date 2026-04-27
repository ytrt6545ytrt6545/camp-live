import 'package:flutter/material.dart';
import 'property_schema.dart';

/// 動態 UI 產生器，根據屬性定義自動構建高品質配置介面
class DynamicUIRenderer extends StatelessWidget {
  final List<PluginProperty> properties;
  final Map<String, dynamic> currentValues;
  final Function(String key, dynamic value) onChanged;

  const DynamicUIRenderer({
    super.key,
    required this.properties,
    required this.currentValues,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: properties.map((prop) => _buildPropertyItem(context, prop)).toList(),
    );
  }

  Widget _buildPropertyItem(BuildContext context, PluginProperty prop) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(12), // 約 0.05 opacity
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withAlpha(25)), // 約 0.1 opacity
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            prop.label,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          _buildEditor(context, prop),
        ],
      ),
    );
  }

  Widget _buildEditor(BuildContext context, PluginProperty prop) {
    final value = currentValues[prop.key] ?? prop.defaultValue;

    switch (prop.type) {
      case PropertyType.string:
        return TextFormField(
          initialValue: value as String?,
          decoration: _inputDecoration(),
          style: const TextStyle(color: Colors.white),
          onChanged: (val) => onChanged(prop.key, val),
        );
      
      case PropertyType.number:
        final numValue = (value as num).toDouble();
        return Row(
          children: [
            Expanded(
              child: Slider(
                value: numValue,
                min: 0,
                max: 100,
                divisions: 100,
                label: numValue.round().toString(),
                activeColor: Colors.indigoAccent,
                onChanged: (val) => onChanged(prop.key, val),
              ),
            ),
            SizedBox(
              width: 40,
              child: Text(
                numValue.round().toString(),
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                textAlign: TextAlign.end,
              ),
            ),
          ],
        );
      
      case PropertyType.boolean:
        final boolValue = value as bool;
        return InkWell(
          onTap: () => onChanged(prop.key, !boolValue),
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  boolValue ? '開啟' : '關閉',
                  style: const TextStyle(color: Colors.white70, fontSize: 16),
                ),
                Switch(
                  value: boolValue,
                  activeThumbColor: Colors.indigoAccent,
                  activeTrackColor: Colors.indigoAccent.withAlpha(100),
                  onChanged: (val) => onChanged(prop.key, val),
                ),
              ],
            ),
          ),
        );
      
      case PropertyType.color:
        final colorValue = value as Color? ?? Colors.indigoAccent;
        return InkWell(
          onTap: () => _showColorPicker(context, prop.key, colorValue),
          borderRadius: BorderRadius.circular(20),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: colorValue,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white24),
                ),
              ),
              const SizedBox(width: 12),
              const Text('點擊選擇顏色', style: TextStyle(color: Colors.white54)),
            ],
          ),
        );
      
      case PropertyType.options:
        final opts = prop.options ?? [];
        if (opts.length <= 4) {
          // 選項少於等於 4 個使用 SegmentedButton
          return SizedBox(
            width: double.infinity,
            child: SegmentedButton<String>(
              segments: opts.map((opt) => ButtonSegment(value: opt, label: Text(opt))).toList(),
              selected: {value as String},
              onSelectionChanged: (set) => onChanged(prop.key, set.first),
              style: ButtonStyle(
                backgroundColor: WidgetStateProperty.resolveWith((states) {
                  if (states.contains(WidgetState.selected)) {
                    return Colors.indigoAccent;
                  }
                  return Colors.transparent;
                }),
                foregroundColor: WidgetStateProperty.resolveWith((states) {
                  if (states.contains(WidgetState.selected)) {
                    return Colors.white;
                  }
                  return Colors.white70;
                }),
              ),
            ),
          );
        } else {
          // 選項大於 4 個使用 DropdownButton
          return DropdownButtonFormField<String>(
            initialValue: value as String?,
            dropdownColor: const Color(0xFF1E293B),
            isExpanded: true,
            style: const TextStyle(color: Colors.white),
            decoration: _inputDecoration(),
            items: opts.map((opt) {
              return DropdownMenuItem(value: opt, child: Text(opt));
            }).toList(),
            onChanged: (val) => onChanged(prop.key, val),
          );
        }
    }
  }

  void _showColorPicker(BuildContext context, String key, Color currentColor) {
    final colors = [
      Colors.indigoAccent,
      Colors.redAccent,
      Colors.greenAccent,
      Colors.blueAccent,
      Colors.orangeAccent,
      Colors.purpleAccent,
    ];

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text('選擇顏色', style: TextStyle(color: Colors.white)),
        content: Wrap(
          spacing: 12,
          runSpacing: 12,
          children: colors.map((c) => 
            GestureDetector(
              onTap: () {
                onChanged(key, c);
                Navigator.pop(ctx);
              },
              child: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: c,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: currentColor == c ? Colors.white : Colors.transparent,
                    width: 2,
                  ),
                ),
              ),
            )
          ).toList(),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration() {
    return InputDecoration(
      filled: true,
      fillColor: Colors.black26,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    );
  }
}
