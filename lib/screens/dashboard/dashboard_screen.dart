import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../services/auth_service.dart';
import '../../services/api_client.dart';
import '../../widgets/common_widgets.dart';
import '../../utils/theme.dart';

final dashboardProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  return ref.read(apiClientProvider).getDashboard();
});

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user  = ref.watch(authStateProvider).value;
    final dash  = ref.watch(dashboardProvider);

    return Scaffold(
      backgroundColor: LexSnTheme.background,
      body: SafeArea(
        child: RefreshIndicator(
          color: LexSnTheme.primary,
          onRefresh: () async => ref.invalidate(dashboardProvider),
          child: CustomScrollView(slivers: [

            // AppBar custom
            SliverToBoxAdapter(
              child: Container(
                color: LexSnTheme.surface,
                padding: const EdgeInsets.fromLTRB(20, 16, 16, 16),
                child: Row(children: [
                  Expanded(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Bonjour, ${user?.prenom ?? ''} 👋',
                        style: const TextStyle(
                          fontSize: 20, fontWeight: FontWeight.w700,
                          color: LexSnTheme.primary,
                        ),
                      ),
                      Text(
                        user?.cabinetNom ?? '',
                        style: const TextStyle(fontSize: 12, color: Color(0xFF9CA3AF)),
                      ),
                    ],
                  )),
                  GestureDetector(
                    onTap: () => _showMenu(context, ref),
                    child: AvatarInitiales(
                      initiales: user?.initiales ?? 'AV',
                      size: 42,
                    ),
                  ),
                ]),
              ),
            ),

            // Contenu
            dash.when(
              loading: () => const SliverFillRemaining(child: LexSnLoader()),
              error: (e, _) => SliverFillRemaining(
                child: LexSnError(
                  message: 'Impossible de charger le tableau de bord',
                  onRetry: () => ref.invalidate(dashboardProvider),
                ),
              ),
              data: (data) {
                final stats     = data['stats'] as Map<String, dynamic>? ?? {};
                final audiences = (data['prochaines_audiences'] as List<dynamic>?) ?? [];
                final dossiers  = (data['derniers_dossiers'] as List<dynamic>?) ?? [];

                return SliverList(delegate: SliverChildListDelegate([

                  // Stats
                  const SectionTitle(title: 'Vue d\'ensemble'),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(children: [
                      Row(children: [
                        Expanded(child: StatCard(
                          label: 'Dossiers actifs',
                          value: '${stats['dossiers_actifs'] ?? 0}',
                          icon: Icons.folder_open,
                          iconBg: LexSnTheme.infoBg,
                          iconColor: LexSnTheme.info,
                        )),
                        const SizedBox(width: 12),
                        Expanded(child: StatCard(
                          label: 'Audiences / semaine',
                          value: '${stats['audiences_semaine'] ?? 0}',
                          icon: Icons.calendar_today,
                          iconBg: LexSnTheme.warningBg,
                          iconColor: LexSnTheme.warning,
                        )),
                      ]),
                      const SizedBox(height: 12),
                      Row(children: [
                        Expanded(child: StatCard(
                          label: 'Clients',
                          value: '${stats['clients_total'] ?? 0}',
                          icon: Icons.people,
                          iconBg: LexSnTheme.successBg,
                          iconColor: LexSnTheme.success,
                        )),
                        const SizedBox(width: 12),
                        Expanded(child: StatCard(
                          label: 'Impayés',
                          value: formatMontant((stats['factures_impayees'] as num?)?.toDouble() ?? 0),
                          icon: Icons.receipt_long,
                          iconBg: LexSnTheme.dangerBg,
                          iconColor: LexSnTheme.danger,
                        )),
                      ]),
                    ]),
                  ),

                  // Prochaines audiences
                  SectionTitle(
                    title: 'Prochaines audiences',
                    trailing: TextButton(
                      onPressed: () => context.go('/audiences'),
                      child: const Text('Voir tout', style: TextStyle(fontSize: 12)),
                    ),
                  ),
                  if (audiences.isEmpty)
                    const _EmptyState(
                      icon: Icons.calendar_today_outlined,
                      message: 'Aucune audience cette semaine',
                    )
                  else
                    ...audiences.map((a) => _AudienceItem(data: a as Map<String, dynamic>)),

                  // Derniers dossiers
                  SectionTitle(
                    title: 'Derniers dossiers',
                    trailing: TextButton(
                      onPressed: () => context.go('/dossiers'),
                      child: const Text('Voir tout', style: TextStyle(fontSize: 12)),
                    ),
                  ),
                  if (dossiers.isEmpty)
                    const _EmptyState(
                      icon: Icons.folder_outlined,
                      message: 'Aucun dossier pour le moment',
                    )
                  else
                    ...dossiers.map((d) => _DossierItem(data: d as Map<String, dynamic>)),

                  const SizedBox(height: 24),
                ]));
              },
            ),
          ]),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: LexSnTheme.primary,
        foregroundColor: Colors.white,
        onPressed: () => context.go('/dossiers/nouveau'),
        child: const Icon(Icons.add),
      ),
    );
  }

  void _showMenu(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(
            leading: const Icon(Icons.logout, color: LexSnTheme.danger),
            title: const Text('Déconnexion', style: TextStyle(color: LexSnTheme.danger)),
            onTap: () async {
              Navigator.pop(context);
              await ref.read(authStateProvider.notifier).logout();
            },
          ),
        ]),
      ),
    );
  }
}

class _AudienceItem extends StatelessWidget {
  final Map<String, dynamic> data;
  const _AudienceItem({required this.data});

  @override
  Widget build(BuildContext context) {
    final dossier = data['dossier'] as Map<String, dynamic>? ?? {};
    final client  = dossier['client'] as Map<String, dynamic>? ?? {};
    final dateStr = data['date_heure'] as String? ?? '';
    final date    = dateStr.isNotEmpty ? DateTime.tryParse(dateStr) : null;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: LexSnTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: LexSnTheme.border, width: 0.5),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        leading: Container(
          width: 44, height: 44,
          decoration: BoxDecoration(
            color: LexSnTheme.infoBg,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                date != null ? DateFormat('d').format(date) : '--',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: LexSnTheme.primary),
              ),
              Text(
                date != null ? DateFormat('MMM', 'fr_FR').format(date).toUpperCase() : '',
                style: const TextStyle(fontSize: 9, color: LexSnTheme.info),
              ),
            ],
          ),
        ),
        title: Text(
          client['nom'] as String? ?? 'Client',
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          maxLines: 1, overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          '${data['objet']} · ${date != null ? DateFormat('HH:mm').format(date) : ''}',
          style: const TextStyle(fontSize: 12, color: Color(0xFF9CA3AF)),
        ),
        trailing: StatutBadge(statut: data['statut'] as String? ?? '', styles: audienceStatutStyles),
        onTap: () => context.go('/dossiers/${dossier['id']}'),
      ),
    );
  }
}

class _DossierItem extends StatelessWidget {
  final Map<String, dynamic> data;
  const _DossierItem({required this.data});

  @override
  Widget build(BuildContext context) {
    final client = data['client'] as Map<String, dynamic>? ?? {};

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: LexSnTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: LexSnTheme.border, width: 0.5),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        leading: AvatarInitiales(
          initiales: (client['nom'] as String? ?? 'X').substring(0, 1),
        ),
        title: Text(
          data['intitule'] as String? ?? '',
          maxLines: 1, overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
        ),
        subtitle: Text(
          '${data['reference']} · ${client['nom']}',
          style: const TextStyle(fontSize: 12, color: Color(0xFF9CA3AF)),
        ),
        trailing: StatutBadge(statut: data['statut'] as String? ?? '', styles: dossierStatutStyles),
        onTap: () => context.go('/dossiers/${data['id']}'),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String message;
  const _EmptyState({required this.icon, required this.message});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      child: Center(child: Column(children: [
        Icon(icon, size: 36, color: const Color(0xFFD1D5DB)),
        const SizedBox(height: 8),
        Text(message, style: const TextStyle(fontSize: 13, color: Color(0xFF9CA3AF))),
      ])),
    );
  }
}