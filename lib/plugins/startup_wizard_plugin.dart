import 'dart:ui';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../core/base_plugin.dart';
import '../core/services/permission_service.dart';
import '../core/models/organization_model.dart';
import 'package:firebase_database/firebase_database.dart';

class StartupWizardPlugin extends BasePlugin {
  @override
  String get name => '引導精靈';

  @override
  String get id => 'startup_wizard';

  @override
  int get requiredRank => 0;

  @override
  Widget? buildCustomUI(
    BuildContext context,
    Map<String, dynamic> currentValues,
    Function(String key, dynamic value) onChanged,
  ) {
    final step = PermissionService.instance.wizardStep;

    if (step < 2) {
      return _ActivationScreen(
        onSuccess: () async {
          final service = PermissionService.instance;
          if (service.currentUser != null) {
            await service.upgradeToGlobal(service.currentUser!.uid);
            await service.updateWizardStep(2);
            onChanged('step', 2);
          }
        },
      );
    } else if (step == 2) {
      return _OrgSetupScreen(
        onComplete: () async {
          await PermissionService.instance.updateWizardStep(3);
          onChanged('step', 3);
        },
      );
    }

    else if (step == 3) {
      return _StaffSetupScreen(
        onComplete: () async {
          await PermissionService.instance.updateWizardStep(4);
          onChanged('step', 4);
        },
      );
    }

    return const Center(child: CircularProgressIndicator());
  }
}

class _OrgSetupScreen extends StatefulWidget {
  final VoidCallback onComplete;

  const _OrgSetupScreen({required this.onComplete});

  @override
  State<_OrgSetupScreen> createState() => _OrgSetupScreenState();
}

class _OrgSetupScreenState extends State<_OrgSetupScreen> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  final List<OrganizationModel> _orgs = [];
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 15),
    )..repeat();
    
    // 預設加入一些建議組別
    _orgs.addAll([
      const OrganizationModel(id: 'AV', name: '視聽組', path: 'GLOBAL/AV'),
      const OrganizationModel(id: 'CATERING', name: '餐飲組', path: 'GLOBAL/CATERING'),
      const OrganizationModel(id: 'GENERAL', name: '總務組', path: 'GLOBAL/GENERAL'),
    ]);
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _addOrg() {
    showDialog(
      context: context,
      builder: (context) {
        String name = '';
        String id = '';
        return AlertDialog(
          backgroundColor: const Color(0xFF1E293B),
          title: const Text('新增大組', style: TextStyle(color: Colors.white)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                autofocus: true,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: '組別名稱 (例：法務組)',
                  labelStyle: TextStyle(color: Colors.white70),
                ),
                onChanged: (v) => name = v,
              ),
              const SizedBox(height: 16),
              TextField(
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: '組別 ID (例：DHARMA)',
                  labelStyle: TextStyle(color: Colors.white70),
                ),
                onChanged: (v) => id = v.toUpperCase(),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('取消'),
            ),
            ElevatedButton(
              onPressed: () {
                if (name.isNotEmpty && id.isNotEmpty) {
                  setState(() {
                    _orgs.add(OrganizationModel(
                      id: id,
                      name: name,
                      path: 'GLOBAL/$id',
                    ));
                  });
                  Navigator.pop(context);
                }
              },
              child: const Text('新增'),
            ),
          ],
        );
      },
    );
  }

  void _handleComplete() async {
    setState(() => _isSaving = true);
    
    try {
      final ref = FirebaseDatabase.instance.ref('organizations');
      // 批量寫入
      for (var org in _orgs) {
        await ref.child(org.id).set(org.toJson());
      }
      
      widget.onComplete();
    } catch (e) {
      setState(() => _isSaving = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('儲存失敗: $e'), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: MediaQuery.of(context).size.height,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0F172A), Color(0xFF1E293B), Color(0xFF0F172A)],
        ),
      ),
      child: Stack(
        children: [
          // 動態發光背景
          AnimatedBuilder(
            animation: _animationController,
            builder: (context, child) {
              return Stack(
                children: [
                  _PositionedBlurCircle(
                    color: Colors.indigo.withOpacity(0.2),
                    size: 500,
                    offset: Offset(
                      50 * (1 + 0.5 * (1 + math.sin(_animationController.value * 6.28))),
                      100 * (1 + 0.3 * (1 + math.cos(_animationController.value * 6.28))),
                    ),
                  ),
                ],
              );
            },
          ),
          
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'STEP 2: 組織紮根',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 4,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 40),
                  child: Text(
                    '「組織架構是系統的骨架，請為這次法會立下最穩固的根基。」',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.amberAccent, fontSize: 16, fontStyle: FontStyle.italic),
                  ),
                ),
                const SizedBox(height: 32),
                
                // 玻璃擬態列表容器
                ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                    child: Container(
                      width: 500,
                      height: 400,
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: Colors.white.withOpacity(0.1)),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('待建立的大組清單', style: TextStyle(color: Colors.white70, fontSize: 18, fontWeight: FontWeight.bold)),
                              IconButton(
                                icon: const Icon(Icons.add_circle, color: Colors.greenAccent),
                                onPressed: _addOrg,
                              ),
                            ],
                          ),
                          const Divider(color: Colors.white24, height: 32),
                          Expanded(
                            child: ListView.builder(
                              itemCount: _orgs.length,
                              itemBuilder: (context, index) {
                                final org = _orgs[index];
                                return Container(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.03),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.account_tree, color: Colors.indigoAccent, size: 20),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(org.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                            Text(org.path, style: const TextStyle(color: Colors.white38, fontSize: 12)),
                                          ],
                                        ),
                                      ),
                                      IconButton(
                                        icon: Icon(Icons.remove_circle_outline, color: Colors.redAccent.withOpacity(0.5), size: 20),
                                        onPressed: () => setState(() => _orgs.removeAt(index)),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ),
                          const SizedBox(height: 24),
                          SizedBox(
                            width: double.infinity,
                            height: 50,
                            child: ElevatedButton(
                              onPressed: _isSaving ? null : _handleComplete,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.indigoAccent,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              child: _isSaving 
                                ? const CircularProgressIndicator(color: Colors.white)
                                : const Text('確認並完成初始化', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ActivationScreen extends StatefulWidget {
  final VoidCallback onSuccess;

  const _ActivationScreen({required this.onSuccess});

  @override
  State<_ActivationScreen> createState() => _ActivationScreenState();
}

class _ActivationScreenState extends State<_ActivationScreen> with SingleTickerProviderStateMixin {
  final TextEditingController _controller = TextEditingController();
  late AnimationController _animationController;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    _animationController.dispose();
    super.dispose();
  }

  void _handleActivation() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    // 模擬網路延遲
    await Future.delayed(const Duration(seconds: 1));

    if (_controller.text == 'GENESIS_2026') {
      widget.onSuccess();
    } else {
      setState(() {
        _isLoading = false;
        _errorMessage = '激活碼無效，請重新輸入';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: MediaQuery.of(context).size.height - 100, // 稍微扣除 AppBar 高度
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF0F172A),
            Color(0xFF1E293B),
            Color(0xFF0F172A),
          ],
        ),
      ),
      child: Stack(
        children: [
          // 動態背景發光體
          AnimatedBuilder(
            animation: _animationController,
            builder: (context, child) {
              return Stack(
                children: [
                  _PositionedBlurCircle(
                    color: Colors.indigo.withOpacity(0.3),
                    size: 300,
                    offset: Offset(
                      100 * (1 + 0.5 * (1 + (1 * _animationController.value * 6.28).sign)),
                      200 * (1 + 0.3 * (1 + (1 * _animationController.value * 6.28).sign)),
                    ),
                  ),
                  _PositionedBlurCircle(
                    color: Colors.purple.withOpacity(0.2),
                    size: 400,
                    right: 50,
                    top: 100,
                  ),
                ],
              );
            },
          ),
          
          Center(
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'SYSTEM IGNITION',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 8,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    '請輸入啟動碼以激活全域權限',
                    style: TextStyle(color: Colors.white54, fontSize: 16),
                  ),
                  const SizedBox(height: 48),
                  
                  // 玻璃擬態容器
                  ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                      child: Container(
                        width: 400,
                        padding: const EdgeInsets.all(32),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.1),
                            width: 1,
                          ),
                        ),
                        child: Column(
                          children: [
                            TextField(
                              controller: _controller,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                letterSpacing: 4,
                                fontWeight: FontWeight.bold,
                              ),
                              decoration: InputDecoration(
                                hintText: 'ENTER CODE',
                                hintStyle: TextStyle(
                                  color: Colors.white.withOpacity(0.2),
                                  letterSpacing: 4,
                                ),
                                border: InputBorder.none,
                              ),
                            ),
                            const Divider(color: Colors.white24, height: 32),
                            if (_errorMessage != null)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 16),
                                child: Text(
                                  _errorMessage!,
                                  style: const TextStyle(color: Colors.redAccent),
                                ),
                              ),
                            SizedBox(
                              width: double.infinity,
                              height: 56,
                              child: ElevatedButton(
                                onPressed: _isLoading ? null : _handleActivation,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF6366F1),
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  elevation: 0,
                                ),
                                child: _isLoading
                                    ? const CircularProgressIndicator(color: Colors.white)
                                    : const Text(
                                        '激活系統',
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                              ),
                            ),
                          ],
                        ),
                      ),
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

class _PositionedBlurCircle extends StatelessWidget {
  final Color color;
  final double size;
  final double? top, right;
  final Offset? offset;

  const _PositionedBlurCircle({
    required this.color,
    required this.size,
    this.top,
    this.right,
    this.offset,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: top,
      right: right,
      child: Transform.translate(
        offset: offset ?? Offset.zero,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color,
          ),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 50, sigmaY: 50),
            child: Container(color: Colors.transparent),
          ),
        ),
      ),
    );
  }
}

class _StaffSetupScreen extends StatefulWidget {
  final VoidCallback onComplete;

  const _StaffSetupScreen({required this.onComplete});

  @override
  State<_StaffSetupScreen> createState() => _StaffSetupScreenState();
}

class _StaffSetupScreenState extends State<_StaffSetupScreen> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  final List<OrganizationModel> _orgs = [];
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 15),
    )..repeat();
    _fetchOrgs();
  }

  Future<void> _fetchOrgs() async {
    try {
      final snapshot = await FirebaseDatabase.instance.ref('organizations').get();
      if (snapshot.exists) {
        final data = snapshot.value as Map<dynamic, dynamic>;
        setState(() {
          _orgs.clear();
          data.forEach((key, value) {
            final json = Map<String, dynamic>.from(value as Map);
            _orgs.add(OrganizationModel.fromJson(json));
          });
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      setState(() => _isLoading = false);
      debugPrint('Error fetching orgs: $e');
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _assignStaff(OrganizationModel org) {
    showDialog(
      context: context,
      builder: (context) {
        String name = '';
        String phone = '';
        String role = 'leader'; // default
        
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF1E293B),
              title: Text('指派 ${org.name} 幹部', style: const TextStyle(color: Colors.white)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    autofocus: true,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      labelText: '姓名',
                      labelStyle: TextStyle(color: Colors.white54),
                      enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                      focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.indigoAccent)),
                    ),
                    onChanged: (v) => name = v,
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      labelText: '電話',
                      labelStyle: TextStyle(color: Colors.white54),
                      enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                      focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.indigoAccent)),
                    ),
                    onChanged: (v) => phone = v,
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: role,
                    dropdownColor: const Color(0xFF0F172A),
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      labelText: '職務',
                      labelStyle: TextStyle(color: Colors.white54),
                      enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                      focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.indigoAccent)),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'leader', child: Text('大組長')),
                      DropdownMenuItem(value: 'deputy', child: Text('副組長')),
                    ],
                    onChanged: (v) {
                      if (v != null) setDialogState(() => role = v);
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('取消', style: TextStyle(color: Colors.white54)),
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (name.isEmpty || phone.isEmpty) return;
                    Navigator.pop(context);
                    await _createShadowAccount(name, phone, role, org.path);
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.indigoAccent),
                  child: const Text('指派並發送簡訊', style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          }
        );
      },
    );
  }

  Future<void> _createShadowAccount(String name, String phone, String role, String groupPath) async {
    setState(() => _isSaving = true);
    try {
      final uid = 'user_${DateTime.now().millisecondsSinceEpoch}';
      final rank = role == 'leader' ? 50 : 30; // 假設副組長 rank 30
      
      final userRef = FirebaseDatabase.instance.ref('users/$uid');
      await userRef.set({
        'uid': uid,
        'name': name,
        'phone': phone,
        'roleId': role,
        'rank': rank,
        'managedGroups': [groupPath],
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('已為 $name 建立影子帳號。\n測試邀請連結: https://camp-live.web.app/join?token=$uid'),
            duration: const Duration(seconds: 8),
            backgroundColor: Colors.green.shade800,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('建立失敗: $e'), backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: MediaQuery.of(context).size.height - 100,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF0F172A),
            Color(0xFF1E293B),
            Color(0xFF0F172A),
          ],
        ),
      ),
      child: Stack(
        children: [
          AnimatedBuilder(
            animation: _animationController,
            builder: (context, child) {
              return Stack(
                children: [
                  _PositionedBlurCircle(
                    color: Colors.indigo.withOpacity(0.3),
                    size: 400,
                    offset: Offset(
                      -100 + 50 * math.sin(_animationController.value * 2 * math.pi),
                      100 + 50 * math.cos(_animationController.value * 2 * math.pi),
                    ),
                  ),
                  _PositionedBlurCircle(
                    color: Colors.purple.withOpacity(0.2),
                    size: 300,
                    right: -50,
                    top: 200 + 100 * math.sin(_animationController.value * 2 * math.pi),
                  ),
                ],
              );
            },
          ),
          
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'STEP 3: 幹部指派',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 4,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 40),
                  child: Text(
                    '「組織紮根成功！請為這批核心團隊指派負責人。」',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.amberAccent, fontSize: 16, fontStyle: FontStyle.italic),
                  ),
                ),
                const SizedBox(height: 32),
                
                ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                    child: Container(
                      width: 500,
                      height: 450,
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: Colors.white.withOpacity(0.1)),
                      ),
                      child: Column(
                        children: [
                          const Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('點擊組別進行指派', style: TextStyle(color: Colors.white70, fontSize: 18, fontWeight: FontWeight.bold)),
                            ],
                          ),
                          const Divider(color: Colors.white24, height: 32),
                          Expanded(
                            child: _isLoading 
                              ? const Center(child: CircularProgressIndicator())
                              : _orgs.isEmpty
                                ? const Center(child: Text('目前沒有建立任何組別', style: TextStyle(color: Colors.white54)))
                                : ListView.builder(
                                    itemCount: _orgs.length,
                                    itemBuilder: (context, index) {
                                      final org = _orgs[index];
                                      return InkWell(
                                        onTap: () => _assignStaff(org),
                                        borderRadius: BorderRadius.circular(12),
                                        child: Container(
                                          margin: const EdgeInsets.only(bottom: 8),
                                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                          decoration: BoxDecoration(
                                            color: Colors.white.withOpacity(0.03),
                                            borderRadius: BorderRadius.circular(12),
                                            border: Border.all(color: Colors.white.withOpacity(0.05)),
                                          ),
                                          child: Row(
                                            children: [
                                              const Icon(Icons.person_add, color: Colors.indigoAccent, size: 20),
                                              const SizedBox(width: 12),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Text(org.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                                    Text(org.path, style: const TextStyle(color: Colors.white38, fontSize: 12)),
                                                  ],
                                                ),
                                              ),
                                              const Icon(Icons.chevron_right, color: Colors.white54),
                                            ],
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                          ),
                          const SizedBox(height: 24),
                          SizedBox(
                            width: double.infinity,
                            height: 50,
                            child: ElevatedButton(
                              onPressed: _isSaving ? null : widget.onComplete,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.indigoAccent,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              child: const Text('完成所有指派，進入系統', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
