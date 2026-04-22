import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lexsn_mobile/screens/dossiers/dossier_params.dart';

import '../../services/api_client.dart';
import '../../models/dossier_model.dart';
import '../../widgets/common_widgets.dart';
import '../../utils/theme.dart';

final dossiersProvider =
    FutureProvider.family<List<DossierModel>, DossierParams>(
  (ref, params) async {
    final data = await ref.read(apiClientProvider).getDossiers(
          q: params.q,
          statut: params.statut,
        );

    final items = data['data'] as List<dynamic>? ?? [];

    return items.map((e) {
      try {
        return DossierModel.fromJson(e as Map<String, dynamic>);
      } catch (err) {
        print('Erreur parsing dossier: $err');
        rethrow;
      }
    }).toList();
  },
);
class DossiersListScreen extends ConsumerStatefulWidget {
  const DossiersListScreen({super.key});

  @override
  ConsumerState<DossiersListScreen> createState() => _DossiersListScreenState();
}

class _DossiersListScreenState extends ConsumerState<DossiersListScreen> {
  final _searchCtrl = TextEditingController();
  String _statut = '';
  String _query = '';
  Timer? _debounce;

DossierParams get _params => DossierParams(
  q: _query.isEmpty ? null : _query,
  statut: _statut.isEmpty ? null : _statut,
);

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(_onSearchChanged);
  }

  void _onSearchChanged() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 450), () {
      if (mounted) setState(() => _query = _searchCtrl.text.trim());
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl
      ..removeListener(_onSearchChanged)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dossiers = ref.watch(dossiersProvider(_params));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dossiers'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => context.go('/dossiers/nouveau'),
          ),
        ],
      ),
      body: Column(children: [
        // Barre de recherche
        Container(
          color: LexSnTheme.surface,
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          child: TextField(
            controller: _searchCtrl,
            decoration: InputDecoration(
              hintText: 'Rechercher par référence, intitulé, client...',
              prefixIcon: const Icon(Icons.search, size: 18),
              suffixIcon: _query.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 16),
                      onPressed: () {
                        _searchCtrl.clear();
                        setState(() => _query = '');
                      },
                    )
                  : null,
            ),
          ),
        ),

        // Filtres statut
        Container(
          color: LexSnTheme.surface,
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: [
              _FilterChip(label: 'Tous', value: '', selected: _statut == '',
                  onTap: () => setState(() => _statut = '')),
              const SizedBox(width: 8),
              _FilterChip(label: 'Ouvert', value: 'ouvert', selected: _statut == 'ouvert',
                  onTap: () => setState(() => _statut = 'ouvert')),
              const SizedBox(width: 8),
              _FilterChip(label: 'En cours', value: 'en_cours', selected: _statut == 'en_cours',
                  onTap: () => setState(() => _statut = 'en_cours')),
              const SizedBox(width: 8),
              _FilterChip(label: 'Suspendu', value: 'suspendu', selected: _statut == 'suspendu',
                  onTap: () => setState(() => _statut = 'suspendu')),
              const SizedBox(width: 8),
              _FilterChip(label: 'Clos', value: 'clos', selected: _statut == 'clos',
                  onTap: () => setState(() => _statut = 'clos')),
            ]),
          ),
        ),

        const Divider(height: 0),

        // Liste des dossiers
        Expanded(
          child: dossiers.when(
            loading: () => const LexSnLoader(),
            error: (e, _) => LexSnError(
              message: 'Impossible de charger les dossiers',
              onRetry: () => ref.invalidate(dossiersProvider(_params)),
            ),
            data: (list) {
              if (list.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.folder_off_outlined, size: 48, color: Color(0xFFD1D5DB)),
                      const SizedBox(height: 12),
                      Text(
                        _query.isNotEmpty || _statut.isNotEmpty
                            ? 'Aucun dossier pour ces filtres'
                            : 'Aucun dossier pour le moment',
                        style: const TextStyle(color: Color(0xFF9CA3AF)),
                      ),
                      const SizedBox(height: 16),
                      if (_query.isEmpty && _statut.isEmpty)
                        OutlinedButton.icon(
                          icon: const Icon(Icons.add, size: 16),
                          label: const Text('Créer un dossier'),
                          onPressed: () => context.go('/dossiers/nouveau'),
                        ),
                    ],
                  ),
                );
              }

              return RefreshIndicator(
                color: LexSnTheme.primary,
                onRefresh: () async {
                  ref.invalidate(dossiersProvider(_params));
                  await Future.delayed(const Duration(milliseconds: 300));
                },
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  itemCount: list.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 6),
                  itemBuilder: (_, i) => _DossierCard(dossier: list[i]),
                ),
              );
            },
          ),
        ),
      ]),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final String value;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.value,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? LexSnTheme.primary : LexSnTheme.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? LexSnTheme.primary : LexSnTheme.border),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: selected ? Colors.white : const Color(0xFF374151),
          ),
        ),
      ),
    );
  }
}

class _DossierCard extends StatelessWidget {
  final DossierModel dossier;
  const _DossierCard({required this.dossier});

  @override
  Widget build(BuildContext context) {
    final prochaineAudience = dossier.prochaineAudience;
    bool estDans48h = false;
    
    if (prochaineAudience != null) {
      final now = DateTime.now();
      final difference = prochaineAudience.dateHeure.difference(now);
      estDans48h = difference.inHours >= 0 && difference.inHours <= 48;
    }

    return GestureDetector(
      onTap: () => context.go('/dossiers/${dossier.id}'),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: LexSnTheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: LexSnTheme.border, width: 0.5),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Référence + statut
          Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFFF3F4F6),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                dossier.reference,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: LexSnTheme.primary,
                  fontFamily: 'monospace',
                ),
              ),
            ),
            const Spacer(),
            StatutBadge(statut: dossier.statut, styles: dossierStatutStyles),
          ]),

          const SizedBox(height: 8),

          // Intitulé
          Text(
            dossier.intitule,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: LexSnTheme.primary,
            ),
          ),

          const SizedBox(height: 8),

          // Client + type
          Row(children: [
            AvatarInitiales(
              initiales: dossier.client.initiales,
              size: 24,
              bg: LexSnTheme.successBg,
              fg: LexSnTheme.success,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                dossier.client.nomComplet,
                style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFFF3F4F6),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                dossier.typeLabel,
                style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280)),
              ),
            ),
          ]),

          // Prochaine audience
          if (prochaineAudience != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: estDans48h ? LexSnTheme.dangerBg : LexSnTheme.infoBg,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(children: [
                Icon(
                  Icons.calendar_today,
                  size: 12,
                  color: estDans48h ? LexSnTheme.danger : LexSnTheme.info,
                ),
                const SizedBox(width: 5),
                Expanded(
                  child: Text(
                    '${prochaineAudience.objet} · ${formatDateHeure(prochaineAudience.dateHeure)}',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: estDans48h ? LexSnTheme.danger : LexSnTheme.info,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ]),
            ),
          ],
        ]),
      ),
    );
  }
}