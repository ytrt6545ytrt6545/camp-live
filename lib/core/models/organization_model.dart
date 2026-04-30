class OrganizationModel {
  final String id;
  final String name;
  final String path;

  const OrganizationModel({
    required this.id,
    required this.name,
    required this.path,
  });

  Map<String, dynamic> toJson() {
    return {'id': id, 'name': name, 'path': path};
  }

  factory OrganizationModel.fromJson(Map<String, dynamic> json) {
    return OrganizationModel(
      id: json['id'] as String,
      name: json['name'] as String,
      path: json['path'] as String,
    );
  }
}
