class RoleModel {
  final String id;
  final String name;
  final int rank;

  const RoleModel({
    required this.id,
    required this.name,
    required this.rank,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'rank': rank,
    };
  }

  factory RoleModel.fromJson(Map<String, dynamic> json) {
    return RoleModel(
      id: json['id'] as String,
      name: json['name'] as String,
      rank: json['rank'] as int,
    );
  }
}
