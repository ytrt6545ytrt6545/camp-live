import 'package:flutter/foundation.dart';
import 'package:firebase_database/firebase_database.dart';
import '../models/role_model.dart';
import '../models/user_model.dart';

class PermissionService {
  // 單例模式
  static final PermissionService _instance = PermissionService._internal();
  static PermissionService get instance => _instance;

  PermissionService._internal();

  UserModel? _currentUser;

  // 預設的角色定義
  final Map<String, RoleModel> _roles = {};
  final List<UserModel> _users = [];

  UserModel? get currentUser => _currentUser;

  int wizardStep = 0;
  bool get isSystemActivated => wizardStep >= 4; // Step 4 代表完全完成引導

  String? activeGroupId;

  /// 應用程式啟動時的初始化邏輯
  Future<void> init() async {
    _initializeDefaultRoles();
    await _syncUsersFromCloud();
    await _syncWizardState();
    debugPrint(
      'PermissionService 初始化完成，當前使用者: ${_currentUser?.name} (Rank: ${_currentUser?.rank}), WizardStep: $wizardStep',
    );
  }

  Future<void> _syncWizardState() async {
    final ref = FirebaseDatabase.instance.ref('wizard_state');
    final snapshot = await ref.get();
    if (snapshot.exists) {
      final data = snapshot.value as Map<dynamic, dynamic>;
      wizardStep = data['step'] as int? ?? 0;
    } else {
      wizardStep = 0;
      await ref.set({'step': 0});
    }
  }

  Future<void> updateWizardStep(int step) async {
    wizardStep = step;
    await FirebaseDatabase.instance.ref('wizard_state').set({'step': step});
    debugPrint('引導精靈進度已更新至: $step');
  }

  void setActiveGroup(String? groupId) {
    activeGroupId = groupId;
    debugPrint('已切換身分至組別: $groupId');
  }

  void _initializeDefaultRoles() {
    final roles = [
      const RoleModel(id: 'admin', name: '系統管理員', rank: 100),
      const RoleModel(id: 'head', name: '總護持', rank: 90),
      const RoleModel(id: 'leader', name: '大組長', rank: 50),
      const RoleModel(id: 'member', name: '一般組員', rank: 10),
      const RoleModel(id: 'guest', name: '訪客', rank: 0),
    ];

    for (var role in roles) {
      _roles[role.id] = role;
    }
  }

  Future<void> _syncUsersFromCloud() async {
    final ref = FirebaseDatabase.instance.ref('users');
    final snapshot = await ref.get();

    if (snapshot.exists) {
      final data = snapshot.value as Map<dynamic, dynamic>;
      _users.clear();
      data.forEach((key, value) {
        final Map<String, dynamic> json = Map<String, dynamic>.from(
          value as Map,
        );
        _users.add(UserModel.fromJson(json));
      });
    } else {
      // 如果雲端沒有資料，寫入預設的測試帳號
      final defaultUsers = [
        const UserModel(
          uid: 'mock_user_123',
          name: '測試大組長',
          roleId: 'leader',
          rank: 50,
          managedGroups: ['CATERING_01', 'CATERING_02'],
        ),
        const UserModel(
          uid: 'admin_1',
          name: '系統管理員',
          roleId: 'admin',
          rank: 100,
          managedGroups: ['GLOBAL'],
        ),
        const UserModel(
          uid: 'member_1',
          name: '王大明',
          roleId: 'member',
          rank: 10,
          managedGroups: [],
        ),
        const UserModel(
          uid: 'member_2',
          name: '李小華',
          roleId: 'member',
          rank: 10,
          managedGroups: [],
        ),
      ];

      _users.addAll(defaultUsers);
      for (var user in defaultUsers) {
        await ref.child(user.uid).set(user.toJson());
      }
    }

    // 為了測試，預設登入 一般組員 (Rank 10)，以便觸發引導精靈
    _currentUser = _users.firstWhere(
      (u) => u.uid == 'member_1',
      orElse: () => _users.first,
    );

    // 初始化 activeGroupId
    if (_currentUser != null && _currentUser!.managedGroups.isNotEmpty) {
      activeGroupId = _currentUser!.managedGroups.first;
    }
  }

  List<UserModel> searchUsers(String query) {
    if (query.isEmpty) return _users;
    return _users.where((u) => u.name.contains(query)).toList();
  }

  Future<void> assignUserToGroup(String uid, String groupPath) async {
    final index = _users.indexWhere((u) => u.uid == uid);
    if (index != -1) {
      final user = _users[index];
      // 指派為負責人，提升 rank 並且加入該組別至 managedGroups
      final updatedGroups = List<String>.from(user.managedGroups);
      if (!updatedGroups.contains(groupPath)) {
        updatedGroups.add(groupPath);
      }

      final updatedUser = UserModel(
        uid: user.uid,
        name: user.name,
        roleId: 'leader',
        rank: 50,
        managedGroups: updatedGroups,
      );

      _users[index] = updatedUser;
      if (_currentUser?.uid == uid) {
        _currentUser = updatedUser;
      }

      // 同步回雲端
      await FirebaseDatabase.instance
          .ref('users/$uid')
          .set(updatedUser.toJson());
      debugPrint('已將使用者 ${user.name} 指派為 $groupPath 的負責人並同步至雲端');
    }
  }

  /// 檢查是否具備存取權限
  /// [requiredRank] 該功能或插件所要求的最低 rank
  /// [targetGroupId] 針對特定組織範圍的過濾 (若有)
  bool hasAccess(int requiredRank, {String? targetGroupId}) {
    if (_currentUser == null) return false;

    // 1. 檢查 Rank (等級)
    if (_currentUser!.rank < requiredRank) {
      return false;
    }

    // 2. 檢查 Scope (範圍)
    if (targetGroupId != null && targetGroupId.isNotEmpty) {
      if (_currentUser!.managedGroups.contains('GLOBAL')) {
        return true; // 具備全域權限
      }
      return _currentUser!.managedGroups.contains(targetGroupId);
    }

    return true; // 未指定特定 Group 或只需 Rank 驗證即過關
  }

  /// 將使用者升級為 Rank 100 (GLOBAL)
  Future<void> upgradeToGlobal(String uid) async {
    final index = _users.indexWhere((u) => u.uid == uid);
    if (index != -1) {
      final user = _users[index];
      final updatedUser = UserModel(
        uid: user.uid,
        name: user.name,
        roleId: 'admin',
        rank: 100,
        managedGroups: ['GLOBAL'],
      );

      _users[index] = updatedUser;
      if (_currentUser?.uid == uid) {
        _currentUser = updatedUser;
        activeGroupId = 'GLOBAL';
      }

      // 同步回雲端
      await FirebaseDatabase.instance
          .ref('users/$uid')
          .set(updatedUser.toJson());
      debugPrint('已將使用者 ${user.name} 提升為 Rank 100 (GLOBAL) 並同步至雲端');
    }
  }
}
