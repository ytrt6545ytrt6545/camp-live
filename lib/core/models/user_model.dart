class UserModel {
  final String uid;
  final String name;
  final String roleId;
  final int rank;
  final List<String> managedGroups;

  const UserModel({
    required this.uid,
    required this.name,
    required this.roleId,
    required this.rank,
    this.managedGroups = const [],
  });

  Map<String, dynamic> toJson() {
    return {
      'uid': uid,
      'name': name,
      'roleId': roleId,
      'rank': rank,
      'managedGroups': managedGroups,
    };
  }

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      uid: json['uid'] as String,
      name: json['name'] as String,
      roleId: json['roleId'] as String,
      rank: json['rank'] as int,
      managedGroups: List<String>.from(json['managedGroups'] ?? []),
    );
  }
}
