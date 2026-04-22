// ─────────────────────────────────────────────────────────────────────────────
// screens/clients/clients_screen.dart
// ─────────────────────────────────────────────────────────────────────────────
// ignore_for_file: file_names

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../services/api_client.dart';
import '../../widgets/common_widgets.dart';
import '../../utils/theme.dart';

class ClientsScreen extends ConsumerStatefulWidget {
  const ClientsScreen({super.key});

  @override
  ConsumerState<ClientsScreen> createState() => _ClientsScreenState();
}

class _ClientsScreenState extends ConsumerState<ClientsScreen> {
  final _searchCtrl = TextEditingController();
  String _query     = '';

  @override
  Widget build(BuildContext context) {
    final clientsAsync = ref.watch(_clientsProvider(_query));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Clients'),
        actions: [
          IconButton(icon: const Icon(Icons.person_add_outlined),
            onPressed: () => context.go('/clients/nouveau')),
        ],
      ),
      body: Column(children: [
        Container(
          color: LexSnTheme.surface,
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: TextField(
            controller: _searchCtrl,
            decoration: InputDecoration(
              hintText: 'Rechercher un client...',
              prefixIcon: const Icon(Icons.search, size: 18),
              suffixIcon: _query.isNotEmpty
                  ? IconButton(icon: const Icon(Icons.clear, size: 16),
                      onPressed: () => setState(() { _searchCtrl.clear(); _query = ''; }))
                  : null,
            ),
            onChanged: (v) => setState(() => _query = v),
          ),
        ),
        const Divider(height: 0),
        Expanded(
          child: clientsAsync.when(
            loading: () => const LexSnLoader(),
            error: (e, _) => LexSnError(message: 'Impossible de charger les clients',
              onRetry: () => ref.invalidate(_clientsProvider(_query))),
            data: (clients) => clients.isEmpty
                ? const Center(child: Text('Aucun client', style: TextStyle(color: Color(0xFF9CA3AF))))
                : ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: clients.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (_, i) {
                      final c = clients[i] as Map<String, dynamic>;
                      final nom   = c['nom'] as String? ?? '';
                      final prenom = c['prenom'] as String? ?? '';
                      final init  = nom.isNotEmpty ? nom[0].toUpperCase() : '?';
                      return GestureDetector(
                        onTap: () => context.go('/clients/${c['id']}'),
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: LexSnTheme.surface,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: LexSnTheme.border, width: 0.5),
                          ),
                          child: Row(children: [
                            AvatarInitiales(initiales: init),
                            const SizedBox(width: 12),
                            Expanded(child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('$nom ${prenom}'.trim(), style: const TextStyle(fontWeight: FontWeight.w600)),
                                if (c['telephone'] != null)
                                  Text(c['telephone'] as String, style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
                              ],
                            )),
                            Text('${c['dossiers_count'] ?? 0} dossier(s)',
                              style: const TextStyle(fontSize: 11, color: Color(0xFF9CA3AF))),
                          ]),
                        ),
                      );
                    },
                  ),
          ),
        ),
      ]),
    );
  }
}

final _clientsProvider = FutureProvider.family<List<dynamic>, String>((ref, q) async {
  final data = await ref.read(apiClientProvider).getClients(q: q.isNotEmpty ? q : null);
  return data['data'] as List<dynamic>? ?? [];
});