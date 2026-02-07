import 'package:flutter_test/flutter_test.dart';
// ✅ Import your specific project package
import 'package:spendwise/models/user_model.dart';

void main() {
  group('User Model', () {
    
    // --- 1. JSON Deserialization Tests ---

    test('fromJson creates a valid user from standard JSON', () {
      final json = {
        'id': 'u123',
        'email': 'test@test.com',
        'username': 'testuser',
        'avatar': 'avatar.png'
      };

      final user = User.fromJson(json);

      expect(user.id, 'u123');
      expect(user.email, 'test@test.com');
      expect(user.username, 'testuser');
      expect(user.avatar, 'avatar.png');
    });

    test('fromJson prioritizes MongoDB "_id" over standard "id"', () {
      // Scenario: Backend sends both (common in migrations)
      // Logic: id = json['_id'] ?? json['id']
      final json = {
        '_id': 'mongo_id_priority', 
        'id': 'simple_id_ignored',
        'email': 'test@test.com',
        'username': 'test',
        'avatar': 'img.png'
      };

      final user = User.fromJson(json);

      // It should pick '_id' and ignore 'id'
      expect(user.id, 'mongo_id_priority');
      expect(user.id, isNot('simple_id_ignored'));
    });

    test('fromJson falls back to "id" if "_id" is missing', () {
      final json = {
        // '_id': missing
        'id': 'fallback_id',
        'email': 'test@test.com',
        'username': 'test',
        'avatar': 'img.png'
      };

      final user = User.fromJson(json);

      expect(user.id, 'fallback_id');
    });

    test('fromJson handles missing or null fields safely', () {
      // Scenario: API returns a partial or empty object
      final Map<String, dynamic> json = {}; 

      final user = User.fromJson(json);

      // Should default to empty strings per your model logic
      expect(user.id, '');
      expect(user.email, '');
      expect(user.username, '');
      expect(user.avatar, '');
    });

    // --- 2. CopyWith Tests ---

    test('copyWith updates specific fields and keeps others', () {
      final user = User(
        id: '1', 
        email: 'original@test.com', 
        username: 'OldName', 
        avatar: 'old.png'
      );

      // Act: Change only the username and avatar
      final updatedUser = user.copyWith(
        username: 'NewName',
        avatar: 'new.png'
      );

      // Assert: Changed fields are updated
      expect(updatedUser.username, 'NewName');
      expect(updatedUser.avatar, 'new.png');
      
      // Assert: Unchanged fields remain the same
      expect(updatedUser.id, '1');
      expect(updatedUser.email, 'original@test.com');
    });

    test('copyWith returns identical object if no arguments provided', () {
      final user = User(
        id: '1', 
        email: 'test@test.com', 
        username: 'User', 
        avatar: 'img.png'
      );

      final sameUser = user.copyWith();

      expect(sameUser.id, user.id);
      expect(sameUser.email, user.email);
      expect(sameUser.username, user.username);
      expect(sameUser.avatar, user.avatar);
    });
  });
}