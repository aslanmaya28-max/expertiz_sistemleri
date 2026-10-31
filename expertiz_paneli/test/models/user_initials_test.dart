import 'package:flutter_test/flutter_test.dart';
import 'package:yerimebak_sistemleri/models/user_model.dart';

void main() {
  for (final entry in {'': 'U', '   ': 'U', 'Ali': 'A', '  Ali  Aslan  ': 'AA'}.entries) {
    test('avatar initials handle name ${entry.key.length} characters', () {
      final user = UserModel(id: 'test', email: 'test@example.test', fullName: entry.key,
        role: UserRole.admin, createdAt: DateTime(2026));
      expect(user.initials, entry.value);
    });
  }
}
