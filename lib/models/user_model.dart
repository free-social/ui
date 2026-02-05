class User {
  final String id; 
  final String email;
  final String username;
  final String avatar; 

  User({
    required this.id,
    required this.email,
    required this.username,
    required this.avatar,
  });

  // ✅ copyWith allows us to update the name/avatar in the Provider state
  User copyWith({
    String? id,
    String? email,
    String? username,
    String? avatar,
  }) {
    return User(
      id: id ?? this.id,
      email: email ?? this.email,
      username: username ?? this.username,
      avatar: avatar ?? this.avatar,
    );
  }

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['_id'] ?? json['id'] ?? '', 
      email: json['email'] ?? '',
      username: json['username'] ?? '',
      avatar: json['avatar'] ?? '', 
    );
  }
}