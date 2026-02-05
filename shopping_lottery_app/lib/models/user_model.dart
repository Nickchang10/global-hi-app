class UserModel {
  final String id;
  final String name;
  final String avatarUrl;
  final String bio;
  bool isMatched;

  UserModel({
    required this.id,
    required this.name,
    required this.avatarUrl,
    required this.bio,
    this.isMatched = false,
  });
}
