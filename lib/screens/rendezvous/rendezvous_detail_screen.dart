import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../services/api_client.dart';
import '../../models/rendezvous_model.dart';
import '../../widgets/common_widgets.dart';
import '../../utils/theme.dart';

final rdvDetailProvider = FutureProvider.family<RendezVousModel, int>((ref, id) async {
  final data = await ref.read(apiClientProvider).getRendezVousDetail(id);
  return RendezVousModel.fromJson(data);
});

class RendezVousDetailScreen extends ConsumerWidget {
  final int rendezVousId;
  const RendezVousDetailScreen({super.key, required this.rendezVousId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rdvAsync = ref.watch(rdvDetailProvider(rendezVousId));

    return Scaffold(
      backgroundColor: LexSnTheme.background,
      appBar: AppBar(
        title: const Text('Rendez-vous'),
        actions: [
          rdvAsync.whenOrNull(
            data: (rdv) => Row(children: [
              IconButton(
                icon: const Icon(Icons.edit_outlined),
                onPressed: () => context.go('/rendezvous/$rendezVousId/modifier'),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline, color: LexSnTheme.danger),
                onPressed: () => _confirmDelete(context, ref, rdv),
              ),
            ]),
          ) ?? const SizedBox.shrink(),
        ],
      ),
      body: rdvAsync.when(
        loading: () => const LexSnLoader(),
        error: (e, _) => LexSnError(
          message: 'Impossible de charger le rendez-vous',
          onRetry: () => ref.invalidate(rdvDetailProvider(rendezVousId)),
        ),
        data: (rdv) => RefreshIndicator(
          color: LexSnTheme.primary,
          onRefresh: () async => ref.invalidate(rdvDetailProvider(rendezVousId)),
          child: ListView(padding: const EdgeInsets.all(16), children: [

            // En-tête
            _HeaderCard(rdv: rdv),
            const SizedBox(height: 12),

            // Dates
            _DatesCard(rdv: rdv),
            const SizedBox(height: 12),

            // Lieu / Visio
            if (rdv.enLigne && rdv.lienVisio != null) ...[
              _VisioCard(lien: rdv.lienVisio!),
              const SizedBox(height: 12),
            ] else if (rdv.lieu != null && rdv.lieu!.isNotEmpty) ...[
              _InfoRow(icon: Icons.location_on_outlined, label: 'Lieu', value: rdv.lieu!),
              const SizedBox(height: 12),
            ],

            // Description
            if (rdv.description != null && rdv.description!.isNotEmpty) ...[
              _TextCard(icon: Icons.notes, label: 'Ordre du jour', text: rdv.description!),
              const SizedBox(height: 12),
            ],

            // Notes privées
            if (rdv.notes != null && rdv.notes!.isNotEmpty) ...[
              _TextCard(
                icon: Icons.lock_outline,
                label: 'Notes privées',
                text: rdv.notes!,
                bg: const Color(0xFFFEFCE8),
                borderColor: const Color(0xFFFEF08A),
              ),
              const SizedBox(height: 12),
            ],

            // Client
            if (rdv.client != null) ...[
              _LinkedCard(
                icon: Icons.person_outline,
                title: rdv.client!.nom,
                subtitle: rdv.client!.telephone ?? 'Aucun téléphone',
                onTap: () {},
              ),
              const SizedBox(height: 12),
            ],

            // Dossier
            if (rdv.dossier != null) ...[
              _LinkedCard(
                icon: Icons.folder_outlined,
                title: rdv.dossier!.reference,
                subtitle: rdv.dossier!.intitule,
                onTap: () => context.go('/dossiers/${rdv.dossier!.id}'),
              ),
              const SizedBox(height: 12),
            ],

            // Changer statut
            _StatutSelector(rdv: rdv, onStatutChanged: (s) async {
              await ref.read(apiClientProvider).updateStatutRendezVous(rdv.id, s);
              ref.invalidate(rdvDetailProvider(rendezVousId));
            }),

            const SizedBox(height: 24),
          ]),
        ),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref, RendezVousModel rdv) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Supprimer le rendez-vous'),
        content: Text('Supprimer « ${rdv.titre} » ?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Supprimer', style: TextStyle(color: LexSnTheme.danger)),
          ),
        ],
      ),
    );
    if (ok == true && context.mounted) {
      await ref.read(apiClientProvider).deleteRendezVous(rdv.id);
      if (context.mounted) context.go('/rendezvous');
    }
  }
}

// ── Widgets ──────────────────────────────────────────────────────────────────

class _HeaderCard extends StatelessWidget {
  final RendezVousModel rdv;
  const _HeaderCard({required this.rdv});

  Color get _typeColor => switch (rdv.type) {
    'consultation'     => const Color(0xFF1B3A5C),
    'suivi'            => const Color(0xFF3B82F6),
    'signature'        => const Color(0xFF8B5CF6),
    'remise_documents' => const Color(0xFFF59E0B),
    'telephone'        => const Color(0xFF10B981),
    'expertise'        => const Color(0xFFEF4444),
    _                  => const Color(0xFF6B7280),
  };

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: LexSnTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: LexSnTheme.border, width: 0.5),
      ),
      child: Row(children: [
        Container(
          width: 48, height: 48,
          decoration: BoxDecoration(color: _typeColor.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
          child: Icon(_typeIcon, color: _typeColor, size: 22),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(rdv.titre, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: LexSnTheme.primary)),
          const SizedBox(height: 3),
          Text(rdv.typeLabel, style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
        ])),
        _StatutPill(statut: rdv.statut, label: rdv.statutLabel),
      ]),
    );
  }

  IconData get _typeIcon => switch (rdv.type) {
    'consultation'     => Icons.person_outline,
    'suivi'            => Icons.refresh,
    'signature'        => Icons.edit_outlined,
    'telephone'        => Icons.phone_outlined,
    'expertise'        => Icons.search,
    'remise_documents' => Icons.insert_drive_file_outlined,
    _                  => Icons.calendar_today_outlined,
  };
}

class _DatesCard extends StatelessWidget {
  final RendezVousModel rdv;
  const _DatesCard({required this.rdv});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: LexSnTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: LexSnTheme.border, width: 0.5),
      ),
      child: Row(children: [
        Expanded(child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('DÉBUT', style: TextStyle(fontSize: 10, color: Color(0xFF9CA3AF), letterSpacing: .8)),
            const SizedBox(height: 4),
            Text(DateFormat('dd/MM/yyyy').format(rdv.debut),
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: LexSnTheme.primary)),
            Text(DateFormat('HH:mm').format(rdv.debut),
                style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280))),
          ]),
        )),
        Container(width: 1, height: 60, color: LexSnTheme.border),
        Expanded(child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('FIN', style: TextStyle(fontSize: 10, color: Color(0xFF9CA3AF), letterSpacing: .8)),
            const SizedBox(height: 4),
            Text(DateFormat('dd/MM/yyyy').format(rdv.fin),
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: LexSnTheme.primary)),
            Text('${DateFormat('HH:mm').format(rdv.fin)} · ${rdv.dureeFormattee}',
                style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280))),
          ]),
        )),
      ]),
    );
  }
}

class _VisioCard extends StatelessWidget {
  final String lien;
  const _VisioCard({required this.lien});
 String get fullUrl {
    if (lien.startsWith('http://') || lien.startsWith('https://')) {
      return lien;
    }
    return 'https://$lien';
  }
  @override
  Widget build(BuildContext context) {
        final url = fullUrl;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFBFDBFE)),
      ),
      child: Row(children: [
        const Icon(Icons.videocam, color: Color(0xFF1E40AF), size: 20),
        const SizedBox(width: 10),
        const Expanded(child: Text('Visioconférence', style: TextStyle(color: Color(0xFF1E40AF), fontWeight: FontWeight.w600))),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1E40AF), padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8)),
          onPressed: () async {
            final uri = Uri.tryParse(url);
            if (uri != null && await canLaunchUrl(uri)) launchUrl(uri, mode: LaunchMode.externalApplication);
          },
          child: const Text('Rejoindre', style: TextStyle(fontSize: 12, color: Colors.white)),
        ),
      ]),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _InfoRow({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: LexSnTheme.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: LexSnTheme.border, width: 0.5),
      ),
      child: Row(children: [
        Icon(icon, size: 16, color: const Color(0xFF9CA3AF)),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFF9CA3AF))),
          Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: LexSnTheme.primary)),
        ])),
      ]),
    );
  }
}

class _TextCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String text;
  final Color bg;
  final Color borderColor;

  const _TextCard({
    required this.icon,
    required this.label,
    required this.text,
    this.bg = LexSnTheme.surface,
    this.borderColor = LexSnTheme.border,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10), border: Border.all(color: borderColor, width: 0.5)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(icon, size: 14, color: const Color(0xFF9CA3AF)),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF9CA3AF))),
        ]),
        const SizedBox(height: 6),
        Text(text, style: const TextStyle(fontSize: 13, color: Color(0xFF374151), height: 1.5)),
      ]),
    );
  }
}

class _LinkedCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  const _LinkedCard({required this.icon, required this.title, required this.subtitle, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: LexSnTheme.surface, borderRadius: BorderRadius.circular(10), border: Border.all(color: LexSnTheme.border, width: 0.5)),
        child: Row(children: [
          Icon(icon, size: 18, color: LexSnTheme.primary),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: LexSnTheme.primary)),
            Text(subtitle, style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280)), maxLines: 1, overflow: TextOverflow.ellipsis),
          ])),
          const Icon(Icons.chevron_right, size: 16, color: Color(0xFF9CA3AF)),
        ]),
      ),
    );
  }
}

class _StatutSelector extends StatelessWidget {
  final RendezVousModel rdv;
  final Function(String) onStatutChanged;
  const _StatutSelector({required this.rdv, required this.onStatutChanged});

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Changer le statut', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF6B7280))),
      const SizedBox(height: 8),
      Wrap(spacing: 8, runSpacing: 8,
        children: RendezVousModel.statutsLabels.entries.map((e) {
          final isCurrent = rdv.statut == e.key;
          return GestureDetector(
            onTap: isCurrent ? null : () => onStatutChanged(e.key),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: isCurrent ? LexSnTheme.primary : LexSnTheme.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: isCurrent ? LexSnTheme.primary : LexSnTheme.border),
              ),
              child: Text(e.value, style: TextStyle(
                fontSize: 12, fontWeight: FontWeight.w500,
                color: isCurrent ? Colors.white : const Color(0xFF374151),
              )),
            ),
          );
        }).toList(),
      ),
    ]);
  }
}

class _StatutPill extends StatelessWidget {
  final String statut;
  final String label;
  const _StatutPill({required this.statut, required this.label});

  @override
  Widget build(BuildContext context) {
    final config = switch (statut) {
      'planifie'   => (const Color(0xFFDBEAFE), const Color(0xFF1E40AF)),
      'confirme'   => (const Color(0xFFD1FAE5), const Color(0xFF065F46)),
      'annule'     => (const Color(0xFFFEE2E2), const Color(0xFF991B1B)),
      'termine'    => (const Color(0xFFF3F4F6), const Color(0xFF374151)),
      'reporte'    => (const Color(0xFFFEF3C7), const Color(0xFF92400E)),
      'en_attente' => (const Color(0xFFFEF3C7), const Color(0xFF92400E)),
      _            => (const Color(0xFFF3F4F6), const Color(0xFF374151)),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: config.$1, borderRadius: BorderRadius.circular(20)),
      child: Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: config.$2)),
    );
  }
}