import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';

import '../../services/api_client.dart';
import '../../models/rendezvous_model.dart';
import '../../widgets/common_widgets.dart';
import '../../utils/theme.dart';

final rdvListProvider =
    FutureProvider.family<List<RendezVousModel>, String>((ref, mois) async {
  final data = await ref.read(apiClientProvider).getRendezVous(mois: mois);
  final items = data['data'] as List<dynamic>? ?? [];
  return items
      .map((e) => RendezVousModel.fromJson(e as Map<String, dynamic>))
      .toList();
});

class RendezVousScreen extends ConsumerStatefulWidget {
  const RendezVousScreen({super.key});

  @override
  ConsumerState<RendezVousScreen> createState() => _RendezVousScreenState();
}

class _RendezVousScreenState extends ConsumerState<RendezVousScreen> {
  DateTime _focusedDay  = DateTime.now();
  DateTime? _selectedDay;

  String get _moisParam => DateFormat('yyyy-MM').format(_focusedDay);

  List<RendezVousModel> _rdvDuJour(List<RendezVousModel> all, DateTime day) {
    return all
        .where((r) =>
            r.debut.year == day.year &&
            r.debut.month == day.month &&
            r.debut.day == day.day)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final rdvAsync = ref.watch(rdvListProvider(_moisParam));

    return Scaffold(
      appBar: AppBar(
        title: Text(DateFormat('MMMM yyyy', 'fr_FR').format(_focusedDay)),
        actions: [
          IconButton(
            icon: const Icon(Icons.today),
            onPressed: () => setState(() {
              _focusedDay  = DateTime.now();
              _selectedDay = DateTime.now();
            }),
          ),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => context.go('/rendezvous/nouveau'),
          ),
        ],
      ),
      body: rdvAsync.when(
        loading: () => const LexSnLoader(),
        error: (e, _) => LexSnError(
          message: e is ApiException ? e.userMessage : 'Impossible de charger les rendez-vous',
          onRetry: () => ref.invalidate(rdvListProvider(_moisParam)),
        ),
        data: (rdvs) {
          final selected = _selectedDay ?? DateTime.now();
          final rdvJour  = _rdvDuJour(rdvs, selected);

          return Column(children: [
            // Calendrier
            TableCalendar<RendezVousModel>(
              locale: 'fr_FR',
              firstDay: DateTime(2020),
              lastDay: DateTime(2030),
              focusedDay: _focusedDay,
              selectedDayPredicate: (d) => isSameDay(d, _selectedDay),
              eventLoader: (day) => _rdvDuJour(rdvs, day),
              calendarFormat: CalendarFormat.month,
              startingDayOfWeek: StartingDayOfWeek.monday,
              headerVisible: false,
              calendarStyle: CalendarStyle(
                outsideDaysVisible: false,
                selectedDecoration: const BoxDecoration(
                  color: LexSnTheme.primary, shape: BoxShape.circle,
                ),
                todayDecoration: BoxDecoration(
                  color: LexSnTheme.primary.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                todayTextStyle: const TextStyle(
                    color: LexSnTheme.primary, fontWeight: FontWeight.w700),
                markerDecoration: const BoxDecoration(
                  color: LexSnTheme.accent, shape: BoxShape.circle,
                ),
                markersMaxCount: 3,
              ),
              daysOfWeekStyle: const DaysOfWeekStyle(
                weekdayStyle: TextStyle(
                    fontSize: 11,
                    color: Color(0xFF9CA3AF),
                    fontWeight: FontWeight.w600),
                weekendStyle: TextStyle(
                    fontSize: 11,
                    color: Color(0xFFD1D5DB),
                    fontWeight: FontWeight.w600),
              ),
              onDaySelected: (sel, foc) => setState(() {
                _selectedDay = sel;
                _focusedDay  = foc;
              }),
              onPageChanged: (foc) => setState(() => _focusedDay = foc),
            ),

            const Divider(height: 0),

            // Titre du jour
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
              child: Row(children: [
                Text(
                  DateFormat('EEEE d MMMM', 'fr_FR').format(selected),
                  style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: LexSnTheme.primary),
                ),
                const SizedBox(width: 8),
                if (rdvJour.isNotEmpty)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: LexSnTheme.infoBg,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text('${rdvJour.length}',
                        style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: LexSnTheme.info)),
                  ),
              ]),
            ),

            Expanded(
              child: rdvJour.isEmpty
                  ? const Center(
                      child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.event_available_outlined,
                            size: 36, color: Color(0xFFD1D5DB)),
                        SizedBox(height: 8),
                        Text('Aucun rendez-vous ce jour',
                            style: TextStyle(
                                fontSize: 13, color: Color(0xFF9CA3AF))),
                      ],
                    ))
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 80),
                      itemCount: rdvJour.length,
                      separatorBuilder: (_, __) =>
                          const SizedBox(height: 8),
                      itemBuilder: (_, i) =>
                          _RdvCard(rdv: rdvJour[i]),
                    ),
            ),
          ]);
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: LexSnTheme.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add, size: 18),
        label: const Text('Rendez-vous', style: TextStyle(fontSize: 13)),
        onPressed: () => context.go('/rendezvous/nouveau'),
      ),
    );
  }
}

// ─── Card RDV ─────────────────────────────────────────────────────────────────

class _RdvCard extends StatelessWidget {
  final RendezVousModel rdv;
  const _RdvCard({required this.rdv});

  Color get _typeColor {
    switch (rdv.type) {
      case 'consultation':   return LexSnTheme.info;
      case 'audience':       return LexSnTheme.warning;
      case 'reunion':        return LexSnTheme.accent;
      case 'appel':          return LexSnTheme.success;
      default:               return const Color(0xFF6B7280);
    }
  }

  Color get _typeBg {
    switch (rdv.type) {
      case 'consultation':   return LexSnTheme.infoBg;
      case 'audience':       return LexSnTheme.warningBg;
      case 'reunion':        return const Color(0xFFFEF7EE);
      case 'appel':          return LexSnTheme.successBg;
      default:               return const Color(0xFFF3F4F6);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isUrgent = rdv.dans24h && !rdv.estPasse;

    return GestureDetector(
      onTap: () => context.go('/rendezvous/${rdv.id}'),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: rdv.estAnnule
              ? const Color(0xFFF9FAFB)
              : LexSnTheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isUrgent
                ? const Color(0xFFFCA5A5)
                : rdv.estAnnule
                    ? const Color(0xFFE5E7EB)
                    : LexSnTheme.border,
            width: isUrgent ? 1 : 0.5,
          ),
        ),
        child: Row(children: [
          // Heure
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: rdv.estPasse || rdv.estAnnule
                  ? const Color(0xFFF3F4F6)
                  : _typeBg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  DateFormat('HH').format(rdv.debut),
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: rdv.estPasse || rdv.estAnnule
                        ? const Color(0xFF9CA3AF)
                        : _typeColor,
                  ),
                ),
                Text(
                  DateFormat('mm').format(rdv.debut),
                  style: TextStyle(
                    fontSize: 11,
                    color: rdv.estPasse || rdv.estAnnule
                        ? const Color(0xFFD1D5DB)
                        : _typeColor.withOpacity(0.7),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(rdv.titre,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: rdv.estAnnule
                          ? const Color(0xFF9CA3AF)
                          : LexSnTheme.primary,
                      decoration:
                          rdv.estAnnule ? TextDecoration.lineThrough : null,
                    )),
                const SizedBox(height: 2),
                Row(children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: _typeBg,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(rdv.typeLabel,
                        style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: _typeColor)),
                  ),
                  const SizedBox(width: 6),
                  Text(rdv.dureeFormattee,
                      style: const TextStyle(
                          fontSize: 11, color: Color(0xFF9CA3AF))),
                ]),
                if (rdv.client != null) ...[
                  const SizedBox(height: 2),
                  Text(rdv.client!.nom,
                      style: const TextStyle(
                          fontSize: 12, color: Color(0xFF6B7280))),
                ],
                if (rdv.lieu != null && !rdv.enLigne)
                  Text('📍 ${rdv.lieu}',
                      style: const TextStyle(
                          fontSize: 11, color: Color(0xFF9CA3AF))),
                if (rdv.enLigne)
                  const Text('🎥 En ligne',
                      style: TextStyle(
                          fontSize: 11, color: LexSnTheme.info)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _StatutBadgeRdv(statut: rdv.statut),
              if (isUrgent) ...[
                const SizedBox(height: 4),
                const Icon(Icons.notifications_active,
                    size: 14, color: LexSnTheme.danger),
              ],
            ],
          ),
        ]),
      ),
    );
  }
}

class _StatutBadgeRdv extends StatelessWidget {
  final String statut;
  const _StatutBadgeRdv({required this.statut});

  @override
  Widget build(BuildContext context) {
    final (label, bg, fg) = switch (statut) {
      'planifie'  => ('Planifié',  LexSnTheme.infoBg,     LexSnTheme.info),
      'confirme'  => ('Confirmé',  LexSnTheme.successBg,  LexSnTheme.success),
      'annule'    => ('Annulé',    LexSnTheme.dangerBg,   LexSnTheme.danger),
      'termine'   => ('Terminé',   const Color(0xFFF3F4F6), const Color(0xFF6B7280)),
      'reporte'   => ('Reporté',   LexSnTheme.warningBg,  LexSnTheme.warning),
      _           => (statut,      LexSnTheme.infoBg,     LexSnTheme.info),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(label,
          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: fg)),
    );
  }
}