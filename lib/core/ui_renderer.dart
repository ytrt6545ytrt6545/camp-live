import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:signature/signature.dart';
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
        
      case PropertyType.qrScanner:
        return _QRScannerField(
          initialValue: value as String?,
          onChanged: (val) => onChanged(prop.key, val),
        );
      
      case PropertyType.signature:
        return _SignatureField(
          initialBase64: value as String?,
          onChanged: (val) => onChanged(prop.key, val),
        );
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

class _QRScannerField extends StatefulWidget {
  final String? initialValue;
  final ValueChanged<String> onChanged;
  
  const _QRScannerField({this.initialValue, required this.onChanged});

  @override
  State<_QRScannerField> createState() => _QRScannerFieldState();
}

class _QRScannerFieldState extends State<_QRScannerField> {
  late TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.initialValue);
  }

  void _openScanner() async {
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => const _QRScannerDialog(),
    );
    if (result != null && result.isNotEmpty) {
      setState(() {
        _ctrl.text = result;
      });
      widget.onChanged(result);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: TextFormField(
            controller: _ctrl,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              filled: true,
              fillColor: Colors.black26,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
            onChanged: widget.onChanged,
          ),
        ),
        const SizedBox(width: 8),
        IconButton(
          icon: const Icon(Icons.qr_code_scanner, color: Colors.indigoAccent),
          onPressed: _openScanner,
          tooltip: '掃描 QR Code',
        ),
      ],
    );
  }
}

class _QRScannerDialog extends StatefulWidget {
  const _QRScannerDialog();

  @override
  State<_QRScannerDialog> createState() => _QRScannerDialogState();
}

class _QRScannerDialogState extends State<_QRScannerDialog> {
  final MobileScannerController _controller = MobileScannerController();
  bool _isError = false;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF1E293B),
      title: const Text('掃描 QR Code', style: TextStyle(color: Colors.white)),
      content: SizedBox(
        width: 300,
        height: 300,
        child: _isError
            ? const Center(
                child: Text(
                  '無法存取相機。\n如果您在網頁版，請確認已允許相機權限且在 HTTPS 或 localhost 環境下。',
                  style: TextStyle(color: Colors.redAccent),
                  textAlign: TextAlign.center,
                ),
              )
            : ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: MobileScanner(
                  controller: _controller,
                  onDetect: (capture) {
                    final List<Barcode> barcodes = capture.barcodes;
                    if (barcodes.isNotEmpty) {
                      final code = barcodes.first.rawValue;
                      if (code != null) {
                        _controller.stop();
                        Navigator.pop(context, code);
                      }
                    }
                  },
                ),
              ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            _controller.stop();
            Navigator.pop(context);
          },
          child: const Text('取消', style: TextStyle(color: Colors.white70)),
        ),
      ],
    );
  }
}

class _SignatureField extends StatefulWidget {
  final String? initialBase64;
  final ValueChanged<String> onChanged;

  const _SignatureField({this.initialBase64, required this.onChanged});

  @override
  State<_SignatureField> createState() => _SignatureFieldState();
}

class _SignatureFieldState extends State<_SignatureField> {
  late SignatureController _controller;

  @override
  void initState() {
    super.initState();
    _controller = SignatureController(
      penStrokeWidth: 3,
      penColor: Colors.white,
      exportBackgroundColor: Colors.transparent,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _clear() {
    _controller.clear();
    widget.onChanged('');
  }

  void _saveSignature() async {
    if (_controller.isEmpty) return;
    
    // 匯出為 PNG 格式的 bytes
    final Uint8List? data = await _controller.toPngBytes();
    if (data != null) {
      final base64String = base64Encode(data);
      widget.onChanged(base64String);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('簽名已確認並轉換')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          decoration: BoxDecoration(
            color: Colors.black26, // 玻璃擬態風格底色
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white24),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Signature(
              controller: _controller,
              height: 200,
              backgroundColor: Colors.transparent, // 背景透明搭配 Container 的底色
            ),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TextButton.icon(
              onPressed: _clear,
              icon: const Icon(Icons.clear, color: Colors.white54),
              label: const Text('清除', style: TextStyle(color: Colors.white54)),
            ),
            const SizedBox(width: 8),
            ElevatedButton.icon(
              onPressed: _saveSignature,
              icon: const Icon(Icons.check, color: Colors.white),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.indigoAccent,
              ),
              label: const Text('確認簽名', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
        if (widget.initialBase64 != null && widget.initialBase64!.isNotEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 8.0),
            child: Text('✅ 已有儲存的簽名資料', style: TextStyle(color: Colors.greenAccent, fontSize: 12)),
          ),
      ],
    );
  }
}

