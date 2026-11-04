import 'package:flutter_secure_storage/flutter_secure_storage.dart';

abstract interface class TokenStore {
  Future<String?> read();
  Future<void> write(String value);
  Future<void> clear();
}

class SecureTokenStore implements TokenStore {
  static const _key = 'yerimebak_session';
  final FlutterSecureStorage storage;
  const SecureTokenStore([this.storage = const FlutterSecureStorage()]);
  @override
  Future<String?> read() => storage.read(key: _key);
  @override
  Future<void> write(String value) => storage.write(key: _key, value: value);
  @override
  Future<void> clear() => storage.delete(key: _key);
}
