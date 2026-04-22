import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

const String _baseUrl = 'http://localhost:8000/api'; // ← à configurer

final apiClientProvider = Provider<ApiClient>((ref) => ApiClient());

// ─── Exception métier ────────────────────────────────────────────────────────

class ApiException implements Exception {
  final String message;
  final int? statusCode;

  /// Erreurs de validation Laravel : { 'champ': ['message1', ...] }
  final Map<String, List<String>> validationErrors;

  const ApiException(
    this.message, {
    this.statusCode,
    this.validationErrors = const {},
  });

  bool get isValidation => statusCode == 422;
  bool get isUnauthorized => statusCode == 401;
  bool get isForbidden => statusCode == 403;
  bool get isNotFound => statusCode == 404;

  /// Première erreur d'un champ donné (pour affichage inline dans le formulaire)
  String? fieldError(String field) => validationErrors[field]?.firstOrNull;

  /// Toutes les erreurs concaténées (pour SnackBar)
  String get allErrors => validationErrors.values
      .expand((e) => e)
      .join('\n')
      .trim();

  /// Message lisible pour l'utilisateur
  String get userMessage => isValidation && allErrors.isNotEmpty ? allErrors : message;

  @override
  String toString() => 'ApiException($statusCode): $message';
}

// ─── Client HTTP ─────────────────────────────────────────────────────────────

class ApiClient {
  late final Dio _dio;
  final _storage = const FlutterSecureStorage();

  ApiClient() {
    _dio = Dio(BaseOptions(
      baseUrl: _baseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 30),
      headers: {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      },
    ));

    // Intercepteur Auth
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await _storage.read(key: 'auth_token');
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        return handler.next(options);
      },
      onError: (error, handler) async {
        if (error.response?.statusCode == 401) {
          await _storage.delete(key: 'auth_token');
        }
        return handler.next(error);
      },
    ));

    // Log debug uniquement en mode debug
    if (kDebugMode) {
      _dio.interceptors.add(LogInterceptor(
        requestBody: true,
        responseBody: true,
        logPrint: (obj) => debugPrint(obj.toString()),
      ));
    }
  }

  // ── Conversion DioException → ApiException ──────────────────────────────────
  ApiException _convert(DioException e) {
    final response = e.response;
    final statusCode = response?.statusCode;

    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout ||
        e.type == DioExceptionType.sendTimeout) {
      return const ApiException('La connexion a expiré. Vérifiez votre réseau.');
    }

    if (e.type == DioExceptionType.connectionError) {
      return const ApiException(
          'Impossible de joindre le serveur. Vérifiez votre connexion internet.');
    }

    if (response == null) {
      return ApiException('Erreur réseau: ${e.message}');
    }

    final body = response.data;

    // 422 — Erreurs de validation Laravel
    if (statusCode == 422) {
      final Map<String, List<String>> errors = {};
      if (body is Map && body['errors'] is Map) {
        (body['errors'] as Map).forEach((key, value) {
          if (value is List) {
            errors[key.toString()] = value.map((v) => v.toString()).toList();
          }
        });
      }
      final msg = (body is Map ? body['message'] as String? : null) ??
          'Certains champs sont invalides.';
      return ApiException(msg, statusCode: 422, validationErrors: errors);
    }

    // 401
    if (statusCode == 401) {
      final msg = (body is Map ? body['message'] as String? : null) ??
          'Session expirée. Veuillez vous reconnecter.';
      return ApiException(msg, statusCode: 401);
    }

    // 403
    if (statusCode == 403) {
      final msg = (body is Map ? body['message'] as String? : null) ??
          'Accès non autorisé.';
      return ApiException(msg, statusCode: 403);
    }

    // 404
    if (statusCode == 404) {
      return ApiException('Ressource introuvable.', statusCode: 404);
    }

    // 500+
    if (statusCode != null && statusCode >= 500) {
      return ApiException('Erreur serveur ($statusCode). Réessayez plus tard.',
          statusCode: statusCode);
    }

    final msg = (body is Map ? body['message'] as String? : null) ??
        'Une erreur est survenue ($statusCode).';
    return ApiException(msg, statusCode: statusCode);
  }

  Future<T> _call<T>(Future<Response> Function() fn) async {
    try {
      final res = await fn();
      return res.data as T;
    } on DioException catch (e) {
      throw _convert(e);
    } catch (e) {
      throw ApiException('Erreur inattendue: $e');
    }
  }

  // ── Auth ─────────────────────────────────────────────────────────────────────
  Future<Map<String, dynamic>> login(String email, String password) =>
      _call(() => _dio.post('/auth/login', data: {
            'email': email,
            'password': password,
          }));

  Future<void> logout() async {
    try {
      await _dio.post('/auth/logout');
    } catch (_) {}
    await _storage.delete(key: 'auth_token');
  }

  // ── Dashboard ─────────────────────────────────────────────────────────────────
  Future<Map<String, dynamic>> getDashboard() =>
      _call(() => _dio.get('/dashboard'));

  // ── Dossiers ──────────────────────────────────────────────────────────────────
  Future<Map<String, dynamic>> getDossiers({
    String? q,
    String? statut,
    String? typeAffaire,
    int page = 1,
  }) =>
      _call(() => _dio.get('/dossiers', queryParameters: {
            if (q != null && q.isNotEmpty) 'q': q,
            if (statut != null && statut.isNotEmpty) 'statut': statut,
            if (typeAffaire != null) 'type_affaire': typeAffaire,
            'page': page,
          }));

  Future<Map<String, dynamic>> getDossier(int id) =>
      _call(() => _dio.get('/dossiers/$id'));

  Future<Map<String, dynamic>> createDossier(Map<String, dynamic> data) =>
      _call(() => _dio.post('/dossiers', data: data));

  Future<Map<String, dynamic>> updateDossier(int id, Map<String, dynamic> data) =>
      _call(() => _dio.put('/dossiers/$id', data: data));

  Future<void> deleteDossier(int id) =>
      _call(() => _dio.delete('/dossiers/$id'));

  // ── Audiences ────────────────────────────────────────────────────────────────
  Future<Map<String, dynamic>> getAudiences({String? mois, String? statut}) =>
      _call(() => _dio.get('/audiences', queryParameters: {
            if (mois != null) 'mois': mois,
            if (statut != null) 'statut': statut,
          }));

  Future<Map<String, dynamic>> createAudience(Map<String, dynamic> data) =>
      _call(() => _dio.post('/audiences', data: data));

  Future<Map<String, dynamic>> updateAudience(int id, Map<String, dynamic> data) =>
      _call(() => _dio.put('/audiences/$id', data: data));

  Future<void> updateStatutAudience(int id, String statut) =>
      _call(() => _dio.patch('/audiences/$id/statut', data: {'statut': statut}));

  Future<void> deleteAudience(int id) =>
      _call(() => _dio.delete('/audiences/$id'));

  // ── Clients ──────────────────────────────────────────────────────────────────
  Future<Map<String, dynamic>> getClients({String? q, String? type, int page = 1}) =>
      _call(() => _dio.get('/clients', queryParameters: {
            if (q != null && q.isNotEmpty) 'q': q,
            if (type != null) 'type': type,
            'page': page,
          }));

  Future<Map<String, dynamic>> getClient(int id) =>
      _call(() => _dio.get('/clients/$id'));

  Future<Map<String, dynamic>> createClient(Map<String, dynamic> data) =>
      _call(() => _dio.post('/clients', data: data));

  Future<Map<String, dynamic>> updateClient(int id, Map<String, dynamic> data) =>
      _call(() => _dio.put('/clients/$id', data: data));

  // ── Factures ──────────────────────────────────────────────────────────────────
  Future<Map<String, dynamic>> getFactures({String? statut, int page = 1}) =>
      _call(() => _dio.get('/factures', queryParameters: {
            if (statut != null && statut.isNotEmpty) 'statut': statut,
            'page': page,
          }));

  Future<Map<String, dynamic>> getFacture(int id) =>
      _call(() => _dio.get('/factures/$id'));

  Future<Map<String, dynamic>> ajouterPaiement(
          int factureId, Map<String, dynamic> data) =>
      _call(() => _dio.post('/factures/$factureId/paiements', data: data));

  Future<List<int>> telechargerPdf(int factureId) async {
    try {
      final res = await _dio.get(
        '/factures/$factureId/pdf',
        options: Options(responseType: ResponseType.bytes),
      );
      return res.data as List<int>;
    } on DioException catch (e) {
      throw _convert(e);
    }
  }
 Future<Map<String, dynamic>> getMe() async {
    try {
      final response = await _dio.get('/auth/me');
      return response.data;
    } catch (e) {
      print('Erreur getMe: $e');
      rethrow;
    }
  }
}