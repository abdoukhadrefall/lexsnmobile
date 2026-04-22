import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../services/api_client.dart';
import '../../widgets/common_widgets.dart';
import '../../utils/theme.dart';
double parseDouble(dynamic v) {
  if (v == null) return 0;
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v) ?? 0;
  return 0;
}
final _facturesListProvider = FutureProvider.family<Map<String, dynamic>, String>(
  (ref, statut) async {
    return ref.read(apiClientProvider).getFactures(
      statut: statut.isEmpty ? null : statut,
    );
  },
);

class FacturesScreen extends ConsumerStatefulWidget {
  const FacturesScreen({super.key});

  @override
  ConsumerState<FacturesScreen> createState() => _FacturesScreenState();
}

class _FacturesScreenState extends ConsumerState<FacturesScreen> {
  String _statut = '';

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(_facturesListProvider(_statut));

    return Scaffold(
      appBar: AppBar(title: const Text('Honoraires')),
      body: Column(children: [

        // Filtres
        Container(
          color: LexSnTheme.surface,
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: [
              _Chip(label: 'Toutes', value: '', selected: _statut == '',
                  onTap: () => setState(() => _statut = '')),
              const SizedBox(width: 8),
              _Chip(label: 'Envoyées', value: 'envoyee', selected: _statut == 'envoyee',
                  onTap: () => setState(() => _statut = 'envoyee')),
              const SizedBox(width: 8),
              _Chip(label: 'Partielles', value: 'partiellement_payee', selected: _statut == 'partiellement_payee',
                  onTap: () => setState(() => _statut = 'partiellement_payee')),
              const SizedBox(width: 8),
              _Chip(label: 'Payées', value: 'payee', selected: _statut == 'payee',
                  onTap: () => setState(() => _statut = 'payee')),
            ]),
          ),
        ),
        const Divider(height: 0),

        // Stats rapides
        async.maybeWhen(
          data: (data) {
            final meta = data['meta'] as Map<String, dynamic>? ?? {};
            if (meta.isEmpty) return const SizedBox.shrink();
            return Container(
              color: LexSnTheme.surface,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(children: [
                _MiniStat(
                  label: 'Total TTC',
                  value: formatMontant((meta['ca_total'] as num?)?.toDouble() ?? 0),
                  color: LexSnTheme.primary,
                ),
                const SizedBox(width: 1, child: ColoredBox(color: LexSnTheme.border, child: SizedBox(height: 36))),
                _MiniStat(
                  label: 'Encaissé',
                  value: formatMontant((meta['encaisse'] as num?)?.toDouble() ?? 0),
                  color: LexSnTheme.success,
                ),
                const SizedBox(width: 1, child: ColoredBox(color: LexSnTheme.border, child: SizedBox(height: 36))),
                _MiniStat(
                  label: 'Impayés',
                  value: formatMontant((meta['en_attente'] as num?)?.toDouble() ?? 0),
                  color: LexSnTheme.danger,
                ),
              ]),
            );
          },
          orElse: () => const SizedBox.shrink(),
        ),

        // Liste
        Expanded(
          child: async.when(
            loading: () => const LexSnLoader(),
            error: (e, _) => LexSnError(
              message: 'Impossible de charger les factures',
              onRetry: () => ref.invalidate(_facturesListProvider(_statut)),
            ),
            data: (data) {
              final items = data['data'] as List<dynamic>? ?? [];
              if (items.isEmpty) {
                return const Center(child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.receipt_long_outlined, size: 48, color: Color(0xFFD1D5DB)),
                    SizedBox(height: 12),
                    Text('Aucune facture', style: TextStyle(color: Color(0xFF9CA3AF))),
                  ],
                ));
              }

              return RefreshIndicator(
                color: LexSnTheme.primary,
                onRefresh: () async => ref.invalidate(_facturesListProvider(_statut)),
                child: ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (_, i) => _FactureCard(data: items[i] as Map<String, dynamic>),
                ),
              );
            },
          ),
        ),
      ]),
    );
  }
}

class _FactureCard extends StatelessWidget {
  final Map<String, dynamic> data;
  const _FactureCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final montantTtc  = parseDouble(data['montant_ttc']);
    final montantPaye = parseDouble(data['montant_paye']);
    final reste       = montantTtc - montantPaye;
    final statut      = data['statut'] as String? ?? '';
    final pct         = montantTtc > 0 ? (montantPaye / montantTtc) : 0.0;

    final client  = data['client'] as Map<String, dynamic>? ?? {};
    final dossier = data['dossier'] as Map<String, dynamic>? ?? {};

    final clientNom = (client['nom'] as String? ?? '')
        .replaceAll('\n', ' ')
        .trim();

    return GestureDetector(
      onTap: () => context.go('/factures/${data['id']}'),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: LexSnTheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: statut == 'payee'
                ? const Color(0xFF6EE7B7)
                : LexSnTheme.border,
            width: 0.5,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            // HEADER
            Row(children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFF3F4F6),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  data['numero'] as String? ?? '',
                  style: const TextStyle(
                    fontSize: 11,
                    fontFamily: 'monospace',
                    color: LexSnTheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const Spacer(),
              StatutBadge(statut: statut, styles: factureStatutStyles),
            ]),

            const SizedBox(height: 8),

            // CLIENT
            Text(
              clientNom,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 15,
                color: LexSnTheme.primary,
              ),
            ),

            // DOSSIER
            Text(
              dossier['reference'] as String? ?? '',
              style: const TextStyle(
                fontSize: 11,
                color: Color(0xFF9CA3AF),
                fontFamily: 'monospace',
              ),
            ),

            const SizedBox(height: 10),

            // MONTANTS
            Row(children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    formatMontant(montantTtc),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (reste > 0)
                    Text(
                      'Reste: ${formatMontant(reste)}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: LexSnTheme.danger,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                ],
              ),
              const Spacer(),
              Text(
                formatDate(DateTime.tryParse(data['date_emission'] ?? '') ?? DateTime.now()),
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF9CA3AF),
                ),
              ),
            ]),

            // PROGRESS BAR
            if (statut != 'brouillon' && statut != 'annulee') ...[
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: LinearProgressIndicator(
                  value: pct.clamp(0.0, 1.0),
                  backgroundColor: const Color(0xFFF3F4F6),
                  color: statut == 'payee'
                      ? LexSnTheme.success
                      : LexSnTheme.accent,
                  minHeight: 4,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
class _Chip extends StatelessWidget {
  final String label;
  final String value;
  final bool selected;
  final VoidCallback onTap;
  const _Chip({required this.label, required this.value, required this.selected, required this.onTap});

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
        child: Text(label, style: TextStyle(
          fontSize: 13, fontWeight: FontWeight.w500,
          color: selected ? Colors.white : const Color(0xFF374151),
        )),
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _MiniStat({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Column(children: [
        Text(label, style: const TextStyle(fontSize: 10, color: Color(0xFF9CA3AF))),
        const SizedBox(height: 2),
        Text(value, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: color),
          overflow: TextOverflow.ellipsis),
      ]),
    ));
  }
}