import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../services/auth_service.dart';
import '../screens/splash_screen.dart';
import '../screens/auth/login_screen.dart';
import '../screens/dashboard/dashboard_screen.dart';
import '../screens/dossiers/dossiers_list_screen.dart';
import '../screens/dossiers/dossier_detail_screen.dart';
import '../screens/dossiers/dossier_form_screen.dart';
import '../screens/audiences/audiences_screen.dart';
import '../screens/audiences/audiences_form_screen.dart';
import '../screens/clients/clients_screen.dart';
import '../screens/clients/client_detail_screen.dart';
import '../screens/clients/client_form_screen.dart';
import '../screens/factures/factures_screen.dart';
import '../screens/factures/facture_detail_screen.dart';
import '../widgets/main_shell.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authStateProvider);

  return GoRouter(
    initialLocation: '/splash',
    debugLogDiagnostics: false,
    redirect: (context, state) {
      final location = state.matchedLocation;

      // Pendant le chargement initial → rester sur splash
      if (authState.isLoading) {
        return location == '/splash' ? null : '/splash';
      }

      // Erreur d'auth → traiter comme non-connecté
      final isLoggedIn = authState.hasValue && authState.value != null;
      final isSplash   = location == '/splash';
      final isLogin    = location == '/login';

      // Non connecté → login
      if (!isLoggedIn && !isLogin) return '/login';

      // Connecté → ne pas rester sur splash ou login
      if (isLoggedIn && (isSplash || isLogin)) return '/dashboard';

      return null;
    },
    routes: [
      // Splash
      GoRoute(
        path: '/splash',
        builder: (_, __) => const SplashScreen(),
      ),

      // Auth
      GoRoute(
        path: '/login',
        name: 'login',
        builder: (_, __) => const LoginScreen(),
      ),

      // Shell avec navigation bar
      ShellRoute(
        builder: (context, state, child) => MainShell(child: child),
        routes: [
          // Dashboard
          GoRoute(
            path: '/dashboard',
            name: 'dashboard',
            builder: (_, __) => const DashboardScreen(),
          ),

          // Dossiers
          GoRoute(
            path: '/dossiers',
            name: 'dossiers',
            builder: (_, __) => const DossiersListScreen(),
            routes: [
              GoRoute(
                path: 'nouveau',
                name: 'dossier-nouveau',
                builder: (_, __) => const DossierFormScreen(),
              ),
              GoRoute(
                path: ':id',
                name: 'dossier-detail',
                builder: (_, s) => DossierDetailScreen(
                  dossierId: int.parse(s.pathParameters['id']!),
                ),
                routes: [
                  GoRoute(
                    path: 'modifier',
                    name: 'dossier-modifier',
                    builder: (_, s) => DossierFormScreen(
                      dossierId: int.parse(s.pathParameters['id']!),
                    ),
                  ),
                  GoRoute(
                    path: 'audience',
                    name: 'audience-nouveau',
                    builder: (_, s) => AudienceFormScreen(
                      dossierId: int.parse(s.pathParameters['id']!),
                    ),
                  ),
                ],
              ),
            ],
          ),

          // Audiences
          GoRoute(
            path: '/audiences',
            name: 'audiences',
            builder: (_, __) => const AudiencesScreen(),
            routes: [
              GoRoute(
                path: ':id/modifier',
                name: 'audience-modifier',
                builder: (_, s) => AudienceFormScreen(
                  audienceId: int.parse(s.pathParameters['id']!),
                ),
              ),
            ],
          ),

          // Clients
          GoRoute(
            path: '/clients',
            name: 'clients',
            builder: (_, __) => const ClientsScreen(),
            routes: [
              GoRoute(
                path: 'nouveau',
                name: 'client-nouveau',
                builder: (_, __) => const ClientFormScreen(),
              ),
              GoRoute(
                path: ':id',
                name: 'client-detail',
                builder: (_, s) => ClientDetailScreen(
                  clientId: int.parse(s.pathParameters['id']!),
                ),
              ),
            ],
          ),

          // Factures
          GoRoute(
            path: '/factures',
            name: 'factures',
            builder: (_, __) => const FacturesScreen(),
            routes: [
              GoRoute(
                path: ':id',
                name: 'facture-detail',
                builder: (_, s) => FactureDetailScreen(
                  factureId: int.parse(s.pathParameters['id']!),
                ),
              ),
            ],
          ),
        ],
      ),
    ],

    errorBuilder: (context, state) => Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 16),
            Text('Page introuvable : ${state.matchedLocation}'),
            TextButton(
              onPressed: () => context.go('/dashboard'),
              child: const Text('Retour au tableau de bord'),
            ),
          ],
        ),
      ),
    ),
  );
});