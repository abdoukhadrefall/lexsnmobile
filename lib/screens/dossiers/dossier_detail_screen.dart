import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:lexsn_mobile/screens/dossiers/dossier_params.dart';

import '../../services/api_client.dart';
import '../../models/dossier_model.dart';
import '../../models/audience_model.dart';
import '../../widgets/common_widgets.dart';
import '../../utils/theme.dart';
final dossierDetailProvider =
    FutureProvider.family<Map<String, dynamic>, int>((ref, id) async {
  return ref.read(apiClientProvider).getDossier(id);
});
final dossiersProvider =
    FutureProvider.family<List<DossierModel>, DossierParams>((ref, params) async {
  final data = await ref.read(apiClientProvider).getDossiers(
    q: params.q,
    statut: params.statut,
  );

  final items = data['data'] as List<dynamic>? ?? [];

  return items
      .map((e) => DossierModel.fromJson(e as Map<String, dynamic>))
      .toList();
});

class DossierDetailScreen extends ConsumerStatefulWidget {
  final int dossierId;
  const DossierDetailScreen({super.key, required this.dossierId});

  @override
  ConsumerState<DossierDetailScreen> createState() => _DossierDetailScreenState();
}

class _DossierDetailScreenState extends ConsumerState<DossierDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final data = ref.watch(dossierDetailProvider(widget.dossierId));

    return data.when(
      loading: () => const Scaffold(body: LexSnLoader()),
      error: (e, _) => Scaffold(
        appBar: AppBar(),
        body: LexSnError(message: 'Dossier introuvable',
          onRetry: () => ref.invalidate(dossierDetailProvider(widget.dossierId))),
      ),
      data: (raw) {
        // FIX: L'API retourne soit {data: {...}} soit directement {...}
        final dossierData = (raw.containsKey('data') && raw['data'] is Map<String, dynamic>)
            ? raw['data'] as Map<String, dynamic>
            : raw;
        final dossier = DossierModel.fromJson(dossierData);
        // Les audiences/documents/factures sont dans le même niveau que data
        final detailData = dossierData;

        return Scaffold(
          backgroundColor: LexSnTheme.background,
          body: NestedScrollView(
            headerSliverBuilder: (_, __) => [
              SliverAppBar(
                pinned: true,
                expandedHeight: 180,
                backgroundColor: LexSnTheme.primary,
                foregroundColor: Colors.white,
                actions: [
                  IconButton(
                    icon: const Icon(Icons.edit_outlined),
                    onPressed: () => context.go('/dossiers/${dossier.id}/modifier'),
                  ),
                ],
                flexibleSpace: FlexibleSpaceBar(
                  background: Container(
                    color: LexSnTheme.primary,
                    padding: const EdgeInsets.fromLTRB(20, 100, 20, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Row(children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(dossier.reference, style: const TextStyle(
                              fontSize: 11, color: Colors.white70, fontFamily: 'monospace',
                            )),
                          ),
                          const SizedBox(width: 8),
                          StatutBadge(statut: dossier.statut, styles: dossierStatutStyles),
                        ]),
                        const SizedBox(height: 6),
                        Text(dossier.intitule, style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white,
                        ), maxLines: 2, overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  ),
                ),
                bottom: TabBar(
                  controller: _tabs,
                  labelColor: Colors.white,
                  unselectedLabelColor: Colors.white54,
                  indicatorColor: LexSnTheme.accent,
                  indicatorWeight: 3,
                  labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                  tabs: const [
                    Tab(text: 'Infos'),
                    Tab(text: 'Audiences'),
                    Tab(text: 'Documents'),
                    Tab(text: 'Honoraires'),
                  ],
                ),
              ),
            ],
            body: TabBarView(
              controller: _tabs,
              children: [
                _InfoTab(dossier: dossier),
               _AudiencesTab(dossierId: dossier.id, data: dossierData),
                _DocumentsTab(dossierId: dossier.id, data: raw),
                _HonorairesTab(data: raw),
              ],
            ),
          ),
          floatingActionButton: FloatingActionButton.extended(
            backgroundColor: LexSnTheme.accent,
            foregroundColor: Colors.white,
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Audience', style: TextStyle(fontSize: 13)),
            onPressed: () => context.go('/dossiers/${dossier.id}/audience'),
          ),
        );
      },
    );
  }
}

// ─── Tab Infos ───────────────────────────────────────────────────────────────

class _InfoTab extends StatelessWidget {
  final DossierModel dossier;
  const _InfoTab({required this.dossier});

  @override
  Widget build(BuildContext context) {
    return ListView(padding: const EdgeInsets.only(bottom: 80), children: [

      const SectionTitle(title: 'Client'),
      Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: LexSnTheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: LexSnTheme.border, width: 0.5),
        ),
        child: ListTile(
          leading: AvatarInitiales(initiales: dossier.client.initiales),
          title: Text(dossier.client.nomComplet, style: const TextStyle(fontWeight: FontWeight.w600)),
          subtitle: dossier.client.telephone != null
              ? Text(dossier.client.telephone!)
              : null,
          trailing: const Icon(Icons.chevron_right, color: Color(0xFF9CA3AF)),
          onTap: () => context.go('/clients/${dossier.client.id}'),
        ),
      ),

      const SectionTitle(title: 'Informations'),
      Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: LexSnTheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: LexSnTheme.border, width: 0.5),
        ),
        child: Column(children: [
          InfoRow(label: 'Type', value: dossier.typeLabel),
          InfoRow(label: 'Avocat', value: dossier.avocat.nomComplet),
          InfoRow(label: 'Ouvert le', value: formatDate(dossier.dateOuverture)),
          if (dossier.juridiction != null)
            InfoRow(label: 'Juridiction', value: dossier.juridiction!.replaceAll('_', ' ')),
          if (dossier.numeroParquet != null)
            InfoRow(label: 'N° parquet', value: dossier.numeroParquet!),
          if (dossier.honorairesPrevus != null)
            InfoRow(label: 'Honoraires prévus', value: formatMontant(dossier.honorairesPrevus!), isLast: true),
        ]),
      ),

      if (dossier.description != null) ...[
        const SectionTitle(title: 'Description'),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: LexSnTheme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: LexSnTheme.border, width: 0.5),
          ),
          child: Text(dossier.description!, style: const TextStyle(fontSize: 13, height: 1.6)),
        ),
      ],

      if (dossier.partiesAdverses != null) ...[
        const SectionTitle(title: 'Parties adverses'),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: LexSnTheme.dangerBg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFFCA5A5), width: 0.5),
          ),
          child: Text(dossier.partiesAdverses!, style: const TextStyle(fontSize: 13, height: 1.6)),
        ),
      ],
    ]);
  }
}

// ─── Tab Audiences ───────────────────────────────────────────────────────────
class _AudiencesTab extends StatelessWidget {
  final int dossierId;
  final Map<String, dynamic> data;
  const _AudiencesTab({required this.dossierId, required this.data});

  @override
  Widget build(BuildContext context) {
    // ✅ Utilisez data au lieu de detailData
    final audiences = (data['audiences'] as List<dynamic>? ?? [])
    .map((e) => AudienceModel.fromJson(e))
    .toList();

    if (audiences.isEmpty) {
      return Center(child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.calendar_today_outlined, size: 48, color: Color(0xFFD1D5DB)),
          const SizedBox(height: 12),
          const Text('Aucune audience', style: TextStyle(color: Color(0xFF9CA3AF))),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            icon: const Icon(Icons.add, size: 16),
            label: const Text('Planifier'),
            onPressed: () => context.go('/dossiers/$dossierId/audience'),
          ),
        ],
      ));
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: audiences.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, i) {
        final a = audiences[i];
        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: LexSnTheme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: a.estDansLes48h ? const Color(0xFFFCA5A5) : LexSnTheme.border,
              width: a.estDansLes48h ? 1 : 0.5,
            ),
          ),
          child: Row(children: [
            Container(
              width: 48, height: 48,
              decoration: BoxDecoration(
                color: a.estPassee ? const Color(0xFFF3F4F6) : LexSnTheme.infoBg,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(DateFormat('d').format(a.dateHeure),
                    style: TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w700,
                      color: a.estPassee ? const Color(0xFF9CA3AF) : LexSnTheme.primary,
                    )),
                  Text(DateFormat('MMM', 'fr_FR').format(a.dateHeure).toUpperCase(),
                    style: TextStyle(
                      fontSize: 9,
                      color: a.estPassee ? const Color(0xFF9CA3AF) : LexSnTheme.info,
                    )),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(a.objet, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                Text('${DateFormat('HH:mm').format(a.dateHeure)}${a.salle != null ? ' · ${a.salle}' : ''}',
                  style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
                if (a.resultat != null)
                  Text(a.resultat!, maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 11, color: Color(0xFF9CA3AF))),
              ],
            )),
            const SizedBox(width: 8),
            StatutBadge(statut: a.statut, styles: audienceStatutStyles),
          ]),
        );
      },
    );
  }
}
// ─── Tab Documents ───────────────────────────────────────────────────────────
class _DocumentsTab extends StatelessWidget {
  final int dossierId;
  final Map<String, dynamic> data;
  const _DocumentsTab({required this.dossierId, required this.data});

  @override
  Widget build(BuildContext context) {
    // ✅ Utilisez data au lieu de detailData
    final docs = data['documents'] as List<dynamic>? ?? [];

    if (docs.isEmpty) {
      return const Center(child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.attach_file_outlined, size: 48, color: Color(0xFFD1D5DB)),
          SizedBox(height: 12),
          Text('Aucun document', style: TextStyle(color: Color(0xFF9CA3AF))),
        ],
      ));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: docs.length,
      itemBuilder: (_, i) {
        final doc = docs[i] as Map<String, dynamic>;
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: LexSnTheme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: LexSnTheme.border, width: 0.5),
          ),
          child: Row(children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: LexSnTheme.infoBg,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.description_outlined, color: LexSnTheme.info, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(doc['nom'] as String? ?? '', style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13)),
                Text(doc['categorie'] as String? ?? '', style: const TextStyle(fontSize: 11, color: Color(0xFF9CA3AF))),
              ],
            )),
            IconButton(
              icon: const Icon(Icons.download_outlined, size: 18, color: LexSnTheme.primary),
              onPressed: () {/* download */},
            ),
          ]),
        );
      },
    );
  }
}
// ─── Tab Honoraires ──────────────────────────────────────────────────────────

class _HonorairesTab extends StatelessWidget {
  final Map<String, dynamic> data;
  const _HonorairesTab({required this.data});

  @override
  Widget build(BuildContext context) {
    // ✅ Utilisez data au lieu de detailData
    final factures = data['factures'] as List<dynamic>? ?? [];

    if (factures.isEmpty) {
      return const Center(child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.receipt_long_outlined, size: 48, color: Color(0xFFD1D5DB)),
          SizedBox(height: 12),
          Text('Aucune facture', style: TextStyle(color: Color(0xFF9CA3AF))),
        ],
      ));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: factures.length,
      itemBuilder: (_, i) {
        final f = factures[i] as Map<String, dynamic>;
        final montantTtc  = (f['montant_ttc'] as num?)?.toDouble() ?? 0;
        final montantPaye = (f['montant_paye'] as num?)?.toDouble() ?? 0;

        return GestureDetector(
          onTap: () => context.go('/factures/${f['id']}'),
          child: Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: LexSnTheme.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: LexSnTheme.border, width: 0.5),
            ),
            child: Row(children: [
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(f['numero'] as String? ?? '', style: const TextStyle(
                    fontWeight: FontWeight.w600, fontSize: 13,
                    fontFamily: 'monospace', color: LexSnTheme.primary,
                  )),
                  Text(formatMontant(montantTtc), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                  if (montantPaye < montantTtc)
                    Text('Reste: ${formatMontant(montantTtc - montantPaye)}',
                      style: const TextStyle(fontSize: 11, color: LexSnTheme.danger)),
                ],
              )),
              StatutBadge(statut: f['statut'] as String? ?? '', styles: factureStatutStyles),
            ]),
          ),
        );
      },
    );
  }
}