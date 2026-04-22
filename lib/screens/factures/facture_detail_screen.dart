import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:lexsn_mobile/models/paiement_model.dart';

import '../../services/api_client.dart';
import '../../widgets/common_widgets.dart';
import '../../utils/theme.dart';

final _factureDetailProv = FutureProvider.family<Map<String, dynamic>, int>((ref, id) async {
  return ref.read(apiClientProvider).getFacture(id);
});

class FactureDetailScreen extends ConsumerWidget {
  final int factureId;
  const FactureDetailScreen({super.key, required this.factureId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(_factureDetailProv(factureId));

    return async.when(
      loading: () => const Scaffold(body: LexSnLoader()),
      error: (e, _) => Scaffold(
        appBar: AppBar(),
        body: LexSnError(message: 'Facture introuvable',
          onRetry: () => ref.invalidate(_factureDetailProv(factureId))),
      ),
      data: (data) {
        final numero      = data['numero'] as String? ?? '';
        final statut      = data['statut'] as String? ?? '';
        final montantTtc  = (data['montant_ttc'] as num?)?.toDouble() ?? 0;
        final montantPaye = (data['montant_paye'] as num?)?.toDouble() ?? 0;
        final montantHt   = (data['montant_ht'] as num?)?.toDouble() ?? 0;
        final tva         = (data['tva'] as num?)?.toDouble() ?? 18;
        final reste       = montantTtc - montantPaye;
        final pct         = montantTtc > 0 ? (montantPaye / montantTtc) : 0.0;
        final client      = data['client'] as Map<String, dynamic>? ?? {};
        final dossier     = data['dossier'] as Map<String, dynamic>? ?? {};
        final paiements   = data['paiements'] as List<dynamic>? ?? [];
        final notes       = data['notes'] as String?;
        final dateEmission = DateTime.tryParse(data['date_emission'] as String? ?? '');
        final dateEcheance = data['date_echeance'] != null
            ? DateTime.tryParse(data['date_echeance'] as String)
            : null;

        return Scaffold(
          backgroundColor: LexSnTheme.background,
          body: CustomScrollView(slivers: [

            // AppBar
            SliverAppBar(
              pinned: true,
              backgroundColor: LexSnTheme.primary,
              foregroundColor: Colors.white,
              expandedHeight: 140,
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
                          child: Text(numero, style: const TextStyle(
                            fontSize: 12, color: Colors.white70, fontFamily: 'monospace',
                          )),
                        ),
                        const SizedBox(width: 8),
                        StatutBadge(statut: statut, styles: factureStatutStyles),
                      ]),
                      const SizedBox(height: 4),
                      Text(formatMontant(montantTtc), style: const TextStyle(
                        fontSize: 22, fontWeight: FontWeight.w700, color: Colors.white,
                      )),
                    ],
                  ),
                ),
              ),
              actions: [
                if (statut != 'payee' && statut != 'annulee')
                  IconButton(
                    icon: const Icon(Icons.add_circle_outline),
                    tooltip: 'Enregistrer un paiement',
                    onPressed: () => _showPaiementModal(context, ref, data),
                  ),
              ],
            ),

            SliverList(delegate: SliverChildListDelegate([

              // Barre de progression
              if (statut != 'brouillon' && statut != 'annulee')
                Container(
                  color: LexSnTheme.surface,
                  padding: const EdgeInsets.all(16),
                  child: Column(children: [
                    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                      Text('${(pct * 100).round()}% encaissé',
                        style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
                      Text(formatMontant(montantPaye),
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: LexSnTheme.success)),
                    ]),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: pct.clamp(0.0, 1.0),
                        backgroundColor: const Color(0xFFE5E7EB),
                        color: statut == 'payee' ? LexSnTheme.success : LexSnTheme.accent,
                        minHeight: 8,
                      ),
                    ),
                    if (reste > 0) ...[
                      const SizedBox(height: 4),
                      Align(
                        alignment: Alignment.centerRight,
                        child: Text('Reste: ${formatMontant(reste)}',
                          style: const TextStyle(fontSize: 12, color: LexSnTheme.danger, fontWeight: FontWeight.w600)),
                      ),
                    ],
                  ]),
                ),

              const Divider(height: 0),

              // Infos client & dossier
              const SectionTitle(title: 'Facturé à'),
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: LexSnTheme.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: LexSnTheme.border, width: 0.5),
                ),
                child: Column(children: [
                  ListTile(
                    leading: AvatarInitiales(
                      initiales: (client['nom'] as String? ?? 'X').substring(0, 1),
                    ),
                    title: Text(client['nom'] as String? ?? '', style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: client['telephone'] != null ? Text(client['telephone'] as String) : null,
                    onTap: () => context.go('/clients/${client['id']}'),
                    trailing: const Icon(Icons.chevron_right, color: Color(0xFF9CA3AF)),
                  ),
                  const Divider(height: 0),
                  ListTile(
                    leading: Container(
                      width: 40, height: 40,
                      decoration: BoxDecoration(
                        color: LexSnTheme.infoBg,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.folder_outlined, color: LexSnTheme.info, size: 18),
                    ),
                    title: Text(dossier['reference'] as String? ?? '',
                      style: const TextStyle(fontFamily: 'monospace', fontSize: 13, color: LexSnTheme.primary)),
                    subtitle: Text(dossier['intitule'] as String? ?? '',
                      maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12)),
                    onTap: () => context.go('/dossiers/${dossier['id']}'),
                    trailing: const Icon(Icons.chevron_right, color: Color(0xFF9CA3AF)),
                  ),
                ]),
              ),

              // Détail montants
              const SectionTitle(title: 'Détail'),
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: LexSnTheme.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: LexSnTheme.border, width: 0.5),
                ),
                child: Column(children: [
                  InfoRow(label: 'Date émission', value: dateEmission != null ? formatDate(dateEmission) : '—'),
                  if (dateEcheance != null)
                    InfoRow(label: 'Échéance', value: formatDate(dateEcheance),),
                  InfoRow(label: 'Montant HT', value: formatMontant(montantHt)),
                  InfoRow(label: 'TVA (${tva.round()}%)', value: formatMontant(montantTtc - montantHt)),
                  InfoRow(label: 'Total TTC', value: formatMontant(montantTtc)),
                  if (notes != null && notes.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.all(14),
                      child: Text(notes, style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280), height: 1.5)),
                    ),
                ]),
              ),

              // Paiements reçus
              SectionTitle(
                title: 'Paiements reçus (${paiements.length})',
                trailing: statut != 'payee' && statut != 'annulee'
                    ? TextButton.icon(
                        icon: const Icon(Icons.add, size: 14),
                        label: const Text('Ajouter', style: TextStyle(fontSize: 12)),
                        onPressed: () => _showPaiementModal(context, ref, data),
                      )
                    : null,
              ),

              if (paiements.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Center(child: Text('Aucun paiement enregistré',
                    style: TextStyle(fontSize: 13, color: Color(0xFF9CA3AF)))),
                )
              else
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: LexSnTheme.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: LexSnTheme.border, width: 0.5),
                  ),
                  child: Column(
                    children: paiements.asMap().entries.map((entry) {
                      final i = entry.key;
                      final p = entry.value as Map<String, dynamic>;
                      final montant = (p['montant'] as num?)?.toDouble() ?? 0;
                      final mode    = PaiementModel.modesLabels[p['mode'] as String? ?? ''] ?? '';
                      final datePaie = DateTime.tryParse(p['date_paiement'] as String? ?? '');

                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          border: i < paiements.length - 1
                              ? const Border(bottom: BorderSide(color: LexSnTheme.border, width: 0.5))
                              : null,
                        ),
                        child: Row(children: [
                          Container(
                            width: 36, height: 36,
                            decoration: BoxDecoration(
                              color: LexSnTheme.successBg,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.check, color: LexSnTheme.success, size: 18),
                          ),
                          const SizedBox(width: 12),
                          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(formatMontant(montant),
                              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: LexSnTheme.success)),
                            Text(mode, style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
                          ])),
                          Text(datePaie != null ? formatDate(datePaie) : '',
                            style: const TextStyle(fontSize: 12, color: Color(0xFF9CA3AF))),
                        ]),
                      );
                    }).toList(),
                  ),
                ),

              const SizedBox(height: 32),
            ])),
          ]),
        );
      },
    );
  }

  void _showPaiementModal(BuildContext context, WidgetRef ref, Map<String, dynamic> facture) {
    final montantCtrl = TextEditingController(
      text: ((facture['montant_ttc'] as num? ?? 0) - (facture['montant_paye'] as num? ?? 0))
          .round().toString(),
    );
    String mode = 'wave';
    DateTime date = DateTime.now();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModal) => Container(
          margin: const EdgeInsets.all(16),
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
            top: 20, left: 20, right: 20,
          ),
          decoration: BoxDecoration(
            color: LexSnTheme.surface,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Enregistrer un paiement', style: TextStyle(
              fontSize: 18, fontWeight: FontWeight.w700, color: LexSnTheme.primary,
            )),
            const SizedBox(height: 16),

            TextFormField(
              controller: montantCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Montant (FCFA)', suffixText: 'FCFA'),
            ),
            const SizedBox(height: 12),

            DropdownButtonFormField<String>(
              value: mode,
              decoration: const InputDecoration(labelText: 'Mode de paiement'),
              items: PaiementModel.modesLabels.entries.map((e) =>
                DropdownMenuItem(value: e.key, child: Text(e.value))
              ).toList(),
              onChanged: (v) => setModal(() => mode = v ?? 'wave'),
            ),
            const SizedBox(height: 12),

            GestureDetector(
              onTap: () async {
                final d = await showDatePicker(
                  context: ctx,
                  initialDate: date,
                  firstDate: DateTime(2020),
                  lastDate: DateTime.now(),
                  locale: const Locale('fr'),
                );
                if (d != null) setModal(() => date = d);
              },
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: LexSnTheme.background,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: LexSnTheme.border),
                ),
                child: Row(children: [
                  const Icon(Icons.calendar_today_outlined, size: 16, color: Color(0xFF9CA3AF)),
                  const SizedBox(width: 8),
                  Text(DateFormat('dd MMMM yyyy', 'fr_FR').format(date),
                    style: const TextStyle(fontSize: 14)),
                ]),
              ),
            ),
            const SizedBox(height: 20),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () async {
                  final montant = double.tryParse(montantCtrl.text) ?? 0;
                  if (montant <= 0) return;

                  try {
                    await ref.read(apiClientProvider).ajouterPaiement(facture['id'] as int, {
                      'montant': montant,
                      'date_paiement': DateFormat('yyyy-MM-dd').format(date),
                      'mode': mode,
                    });
                    ref.invalidate(_factureDetailProv(facture['id'] as int));
                    if (ctx.mounted) Navigator.pop(ctx);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Paiement de ${formatMontant(montant)} enregistré'),
                          backgroundColor: LexSnTheme.success),
                      );
                    }
                  } catch (e) {
                    if (ctx.mounted) {
                      ScaffoldMessenger.of(ctx).showSnackBar(
                        SnackBar(content: Text('Erreur: $e'), backgroundColor: LexSnTheme.danger),
                      );
                    }
                  }
                },
                child: const Text('Enregistrer le paiement'),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}