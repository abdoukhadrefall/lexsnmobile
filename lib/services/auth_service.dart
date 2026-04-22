import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../models/user_model.dart';
import 'api_client.dart';

final authStateProvider = AsyncNotifierProvider<AuthNotifier, UserModel?>(() {
  return AuthNotifier();
});

class AuthNotifier extends AsyncNotifier<UserModel?> {
  final _storage = const FlutterSecureStorage();

  @override
  Future<UserModel?> build() async {
    // FIX: Vérifier le token en lisant /auth/me au lieu du dashboard
    // Evite le chargement infini si le dashboard est lent
    final token = await _storage.read(key: 'auth_token');
    if (token == null) return null;

    try {
      final api = ref.read(apiClientProvider);
      final data = await api.getMe();
      if (data['user'] != null) {
        return UserModel.fromJson(data['user'] as Map<String, dynamic>);
      }
    } on ApiException catch (e) {
      // 401 = token expiré → déconnexion silencieuse
      if (e.isUnauthorized) {
        await _storage.delete(key: 'auth_token');
      }
    } catch (_) {
      // Erreur réseau → garder l'état déconnecté sans crasher
      await _storage.delete(key: 'auth_token');
    }
    return null;
  }

  Future<void> login(String email, String password) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final api = ref.read(apiClientProvider);
      final data = await api.login(email, password);

      final token = data['token'] as String?;
      if (token == null) throw const ApiException('Token manquant dans la réponse.');

      await _storage.write(key: 'auth_token', value: token);

      return UserModel.fromJson(data['user'] as Map<String, dynamic>);
    });
  }

  Future<void> logout() async {
    // FIX: Ne pas crasher si la déconnexion API échoue (ex: réseau coupé)
    try {
      final api = ref.read(apiClientProvider);
      await api.logout();
    } catch (_) {}
    await _storage.delete(key: 'auth_token');
    state = const AsyncData(null);
  }
}