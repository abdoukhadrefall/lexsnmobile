// ─── client_detail_screen.dart ───────────────────────────────────────────────
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../services/api_client.dart';
import '../../widgets/common_widgets.dart';
import '../../utils/theme.dart';

class ClientDetailScreen extends ConsumerWidget {
  final int clientId;
  const ClientDetailScreen({super.key, required this.clientId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(_clientDetailProv(clientId));

    return async.when(
      loading: () => const Scaffold(body: LexSnLoader()),
      error: (e, _) => Scaffold(appBar: AppBar(), body: LexSnError(message: 'Client introuvable')),
      data: (data) {
        final nom    = data['nom'] as String? ?? '';
        final prenom = data['prenom'] as String? ?? '';
        final dossiers = data['dossiers'] as List<dynamic>? ?? [];

        return Scaffold(
          appBar: AppBar(
            title: Text('$prenom $nom'.trim()),
            actions: [IconButton(icon: const Icon(Icons.edit_outlined), onPressed: () {})],
          ),
          body: ListView(children: [
            // Infos client
            Container(
              color: LexSnTheme.surface,
              padding: const EdgeInsets.all(20),
              child: Row(children: [
                AvatarInitiales(initiales: nom.isNotEmpty ? nom[0].toUpperCase() : '?', size: 56),
                const SizedBox(width: 16),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('$prenom $nom'.trim(), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: LexSnTheme.primary)),
                  if (data['telephone'] != null) Text(data['telephone'] as String, style: const TextStyle(color: Color(0xFF6B7280))),
                  if (data['email'] != null) Text(data['email'] as String, style: const TextStyle(fontSize: 12, color: Color(0xFF9CA3AF))),
                ])),
              ]),
            ),
            const Divider(height: 0),
            const SectionTitle(title: 'Dossiers'),
            ...dossiers.map((d) {
              final dos = d as Map<String, dynamic>;
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: LexSnTheme.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: LexSnTheme.border, width: 0.5)),
                child: GestureDetector(
                  onTap: () => context.go('/dossiers/${dos['id']}'),
                  child: Row(children: [
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(dos['reference'] as String? ?? '', style: const TextStyle(fontFamily: 'monospace', fontSize: 11, color: LexSnTheme.primary)),
                      Text(dos['intitule'] as String? ?? '', maxLines: 2, style: const TextStyle(fontWeight: FontWeight.w500)),
                    ])),
                    StatutBadge(statut: dos['statut'] as String? ?? '', styles: dossierStatutStyles),
                  ]),
                ),
              );
            }),
            const SizedBox(height: 24),
          ]),
        );
      },
    );
  }
}

final _clientDetailProv = FutureProvider.family<Map<String, dynamic>, int>((ref, id) async {
  final response = await ref.read(apiClientProvider).getClient(id);
  // FIX: L'API retourne {data: {...}}, on déballe
  if (response.containsKey('data') && response['data'] is Map<String, dynamic>) {
    return response['data'] as Map<String, dynamic>;
  }
  return response;
});