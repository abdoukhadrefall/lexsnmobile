import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../services/api_client.dart';
import '../../models/rendezvous_model.dart';
import '../../widgets/common_widgets.dart';
import '../../utils/theme.dart';

final _rdvDetailProv = FutureProvider.family<RendezVousModel, int>((ref, id) async {
  final data = await ref.read(apiClientProvider).getRendezVousDetail(id);
  return RendezVousModel.fromJson(data['data'] as Map<String, dynamic>);
});

class RendezVousDetailScreen extends ConsumerWidget {
  final int rdvId;
  const RendezVousDetailScreen({super.key, required this.rdvId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(_rdvDetailProv(rdvId));

    return async.when(
      loading: () => const Scaffold(body: LexSnLoader()),
      error: (e, _) => Scaffold(
        appBar: AppBar(),
        body: LexSnError(
          message: e is ApiException ? e.userMessage : 'Rendez-vous introuvable',
          onRetry: () => ref.invalidate(_rdvDetailProv(rdvId)),
        ),
      ),
      data: (rdv) => _RdvDetailView(rdv: rdv, ref: ref),
    );
  }
}

class _RdvDetailView extends StatelessWidget {
  final RendezVousModel rdv;
  final WidgetRef ref;
  const _RdvDetailView({required this.rdv, required this.ref});

  Color get _typeColor => switch (rdv.type) {
    'consultation' => LexSnTheme.info,
    'audience'     => LexSnTheme.warning,
    'reunion'      => LexSnTheme.accent,
    'appel'        => LexSnTheme.success,
    _              => const Color(0xFF6B7280),
  };

  @override
  Widget build(BuildContext context) {
    final duree = rdv.fin.difference(rdv.debut);
    final isSameDay = rdv.debut.day == rdv.fin.day &&
        rdv.debut.month == rdv.fin.month &&
        rdv.debut.year == rdv.fin.year;

    return Scaffold(
      backgroundColor: LexSnTheme.background,
      body: CustomScrollView(slivers: [
        // AppBar colorée selon type
        SliverAppBar(
          pinned: true,
          expandedHeight: 160,
          backgroundColor: LexSnTheme.primary,
          foregroundColor: Colors.white,
          actions: [
            if (!rdv.estAnnule && !rdv.estPasse)
              IconButton(
                icon: const Icon(Icons.edit_outlined),
                onPressed: () => context.go('/rendezvous/${rdv.id}/modifier'),
              ),
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert),
              onSelected: (action) => _handleAction(context, action),
              itemBuilder: (_) => [
                if (!rdv.estAnnule)
                  const PopupMenuItem(value: 'annuler',
                      child: Text('Annuler le RDV', style: TextStyle(color: LexSnTheme.danger))),
                const PopupMenuItem(value: 'supprimer',
                    child: Text('Supprimer', style: TextStyle(color: LexSnTheme.danger))),
              ],
            ),
          ],
          flexibleSpace: FlexibleSpaceBar(
            background: Container(
              color: LexSnTheme.primary,
              padding: const EdgeInsets.fromLTRB(20, 90, 20, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Row(children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: _typeColor.withOpacity(0.25),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(rdv.typeLabel,
                          style: TextStyle(
                              fontSize: 11, fontWeight: FontWeight.w600,
                              color: _typeColor == LexSnTheme.warning
                                  ? Colors.orange.shade100
                                  : Colors.white70)),
                    ),
                    const SizedBox(width: 8),
                    _StatutChip(statut: rdv.statut),
                  ]),
                  const SizedBox(height: 8),
                  Text(rdv.titre,
                      style: const TextStyle(
                          fontSize: 17, fontWeight: FontWeight.w700, color: Colors.white),
                      maxLines: 2, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
          ),
        ),

        SliverList(delegate: SliverChildListDelegate([

          // ── Bloc date/heure ───────────────────────────────────────────
          Container(
            color: LexSnTheme.surface,
            padding: const EdgeInsets.all(16),
            child: Row(children: [
              Container(
                width: 56, height: 56,
                decoration: BoxDecoration(
                  color: rdv.dans24h && !rdv.estPasse
                      ? LexSnTheme.dangerBg : LexSnTheme.infoBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(DateFormat('d').format(rdv.debut),
                        style: TextStyle(
                            fontSize: 20, fontWeight: FontWeight.w800,
                            color: rdv.dans24h && !rdv.estPasse
                                ? LexSnTheme.danger : LexSnTheme.primary)),
                    Text(DateFormat('MMM', 'fr_FR').format(rdv.debut).toUpperCase(),
                        style: TextStyle(
                            fontSize: 10,
                            color: rdv.dans24h && !rdv.estPasse
                                ? LexSnTheme.danger : LexSnTheme.info)),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    DateFormat('EEEE d MMMM yyyy', 'fr_FR').format(rdv.debut),
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                  Text(
                    isSameDay
                        ? '${DateFormat('HH:mm').format(rdv.debut)} → ${DateFormat('HH:mm').format(rdv.fin)} (${rdv.dureeFormattee})'
                        : '${DateFormat('HH:mm').format(rdv.debut)} → ${DateFormat('d MMM HH:mm', 'fr_FR').format(rdv.fin)}',
                    style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
                  ),
                  if (rdv.dans24h && !rdv.estPasse)
                    Text('⚡ ${rdv.debut.difference(DateTime.now()).inHours < 1 ? 'Moins d\'une heure' : 'Dans ${rdv.debut.difference(DateTime.now()).inHours}h'}',
                        style: const TextStyle(fontSize: 12, color: LexSnTheme.danger, fontWeight: FontWeight.w600)),
                ],
              )),
            ]),
          ),

          const Divider(height: 0),

          // ── Lieu / Visio ──────────────────────────────────────────────
          if (rdv.lieu != null || rdv.enLigne) ...[
            Container(
              color: LexSnTheme.surface,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: rdv.enLigne
                  ? Row(children: [
                      const Icon(Icons.videocam_outlined, size: 18, color: LexSnTheme.info),
                      const SizedBox(width: 10),
                      const Text('Réunion en ligne', style: TextStyle(fontWeight: FontWeight.w500)),
                      const Spacer(),
                      if (rdv.lienVisio != null)
                        TextButton.icon(
                          icon: const Icon(Icons.open_in_new, size: 14),
                          label: const Text('Rejoindre', style: TextStyle(fontSize: 12)),
                          onPressed: () => _openUrl(rdv.lienVisio!),
                        ),
                    ])
                  : Row(children: [
                      const Icon(Icons.location_on_outlined, size: 18, color: Color(0xFF9CA3AF)),
                      const SizedBox(width: 10),
                      Expanded(child: Text(rdv.lieu!,
                          style: const TextStyle(fontSize: 13))),
                    ]),
            ),
            const Divider(height: 0),
          ],

          // ── Client & Dossier ─────────────────────────────────────────
          if (rdv.client != null) ...[
            const SectionTitle(title: 'Client'),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: LexSnTheme.surface, borderRadius: BorderRadius.circular(12),
                border: Border.all(color: LexSnTheme.border, width: 0.5),
              ),
              child: ListTile(
                leading: AvatarInitiales(
                    initiales: rdv.client!.nom.isNotEmpty ? rdv.client!.nom[0] : 'C'),
                title: Text(rdv.client!.nom,
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: rdv.client!.telephone != null
                    ? Text(rdv.client!.telephone!)
                    : null,
                trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                  if (rdv.client!.telephone != null)
                    IconButton(
                      icon: const Icon(Icons.phone_outlined, size: 18, color: LexSnTheme.success),
                      onPressed: () => _openUrl('tel:${rdv.client!.telephone}'),
                    ),
                  const Icon(Icons.chevron_right, color: Color(0xFF9CA3AF)),
                ]),
                onTap: () => context.go('/clients/${rdv.client!.id}'),
              ),
            ),
          ],

          if (rdv.dossier != null) ...[
            const SectionTitle(title: 'Dossier lié'),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: LexSnTheme.surface, borderRadius: BorderRadius.circular(12),
                border: Border.all(color: LexSnTheme.border, width: 0.5),
              ),
              child: ListTile(
                leading: Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(
                      color: LexSnTheme.infoBg, borderRadius: BorderRadius.circular(8)),
                  child: const Icon(Icons.folder_outlined, color: LexSnTheme.info, size: 18),
                ),
                title: Text(rdv.dossier!.reference,
                    style: const TextStyle(fontFamily: 'monospace', fontSize: 13, color: LexSnTheme.primary)),
                subtitle: Text(rdv.dossier!.intitule, maxLines: 1, overflow: TextOverflow.ellipsis),
                trailing: const Icon(Icons.chevron_right, color: Color(0xFF9CA3AF)),
                onTap: () => context.go('/dossiers/${rdv.dossier!.id}'),
              ),
            ),
          ],

          // ── Description / Notes ───────────────────────────────────────
          if (rdv.description != null && rdv.description!.isNotEmpty) ...[
            const SectionTitle(title: 'Description'),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: LexSnTheme.surface, borderRadius: BorderRadius.circular(12),
                border: Border.all(color: LexSnTheme.border, width: 0.5),
              ),
              child: Text(rdv.description!, style: const TextStyle(fontSize: 13, height: 1.6)),
            ),
          ],

          if (rdv.notes != null && rdv.notes!.isNotEmpty) ...[
            const SectionTitle(title: 'Notes internes'),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: LexSnTheme.warningBg, borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFFCD34D), width: 0.5),
              ),
              child: Text(rdv.notes!, style: const TextStyle(fontSize: 13, height: 1.6)),
            ),
          ],

          // ── Rappel ────────────────────────────────────────────────────
          const SectionTitle(title: 'Rappel'),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: LexSnTheme.surface, borderRadius: BorderRadius.circular(12),
              border: Border.all(color: LexSnTheme.border, width: 0.5),
            ),
            child: InfoRow(
              label: 'Rappel',
              value: RendezVousModel.rappelOptions
                  .firstWhere(
                    (o) => o['value'] == rdv.rappelMinutes,
                    orElse: () => {'label': '${rdv.rappelMinutes} min avant'},
                  )['label'] as String,
              isLast: true,
            ),
          ),

          const SizedBox(height: 32),
        ])),
      ]),

      // FAB : modifier si non terminé/annulé
      floatingActionButton: !rdv.estAnnule && !rdv.estPasse
          ? FloatingActionButton.extended(
              backgroundColor: LexSnTheme.primary,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.edit_outlined, size: 18),
              label: const Text('Modifier', style: TextStyle(fontSize: 13)),
              onPressed: () => context.go('/rendezvous/${rdv.id}/modifier'),
            )
          : null,
    );
  }

  void _handleAction(BuildContext context, String action) async {
    if (action == 'annuler') {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Annuler le rendez-vous ?'),
          content: const Text('Cette action est réversible depuis la modification.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Non')),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Oui, annuler', style: TextStyle(color: LexSnTheme.danger)),
            ),
          ],
        ),
      );
      if (confirm == true) {
        try {
          await ref.read(apiClientProvider).updateRendezVous(rdv.id, {'statut': 'annule'});
          ref.invalidate(_rdvDetailProv(rdv.id));
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Rendez-vous annulé'), backgroundColor: LexSnTheme.warning));
          }
        } catch (e) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Erreur: $e'), backgroundColor: LexSnTheme.danger));
          }
        }
      }
    }

    if (action == 'supprimer') {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Supprimer ?'),
          content: const Text('Cette action est irréversible.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Non')),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Supprimer', style: TextStyle(color: LexSnTheme.danger)),
            ),
          ],
        ),
      );
      if (confirm == true) {
        try {
          await ref.read(apiClientProvider).deleteRendezVous(rdv.id);
          if (context.mounted) {
            context.pop();
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Rendez-vous supprimé'), backgroundColor: LexSnTheme.success));
          }
        } catch (e) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Erreur: $e'), backgroundColor: LexSnTheme.danger));
          }
        }
      }
    }
  }

  void _openUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri != null && await canLaunchUrl(uri)) {
      launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}

class _StatutChip extends StatelessWidget {
  final String statut;
  const _StatutChip({required this.statut});

  @override
  Widget build(BuildContext context) {
    final label = RendezVousModel.statutsLabels[statut] ?? statut;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(label, style: const TextStyle(fontSize: 11, color: Colors.white70)),
    );
  }
}