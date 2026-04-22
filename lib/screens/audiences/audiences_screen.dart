import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';

import '../../services/api_client.dart';
import '../../models/audience_model.dart';
import '../../widgets/common_widgets.dart';
import '../../utils/theme.dart';

final audiencesProvider = FutureProvider.family<List<AudienceModel>, String>((ref, mois) async {
  final data = await ref.read(apiClientProvider).getAudiences(mois: mois);
  final items = data['audiences'] as List<dynamic>? ?? [];
  return items.map((e) => AudienceModel.fromJson(e as Map<String, dynamic>)).toList();
});

class AudiencesScreen extends ConsumerStatefulWidget {
  const AudiencesScreen({super.key});

  @override
  ConsumerState<AudiencesScreen> createState() => _AudiencesScreenState();
}

class _AudiencesScreenState extends ConsumerState<AudiencesScreen> {
  DateTime _focusedDay  = DateTime.now();
  DateTime? _selectedDay;

  String get _moisParam => DateFormat('yyyy-MM').format(_focusedDay);

  List<AudienceModel> _audiencesDuJour(List<AudienceModel> all, DateTime day) {
    return all.where((a) =>
      a.dateHeure.year == day.year &&
      a.dateHeure.month == day.month &&
      a.dateHeure.day == day.day
    ).toList();
  }

  @override
  Widget build(BuildContext context) {
    final audiencesAsync = ref.watch(audiencesProvider(_moisParam));

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
        ],
      ),
      body: audiencesAsync.when(
        loading: () => const LexSnLoader(),
        error: (e, _) => LexSnError(message: 'Impossible de charger les audiences',
          onRetry: () => ref.invalidate(audiencesProvider(_moisParam))),
        data: (audiences) {
          final selected = _selectedDay ?? DateTime.now();
          final audiencesJour = _audiencesDuJour(audiences, selected);

          return Column(children: [

            // Calendrier
            TableCalendar<AudienceModel>(
              locale: 'fr_FR',
              firstDay: DateTime(2020),
              lastDay: DateTime(2030),
              focusedDay: _focusedDay,
              selectedDayPredicate: (d) => isSameDay(d, _selectedDay),
              eventLoader: (day) => _audiencesDuJour(audiences, day),
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
                todayTextStyle: const TextStyle(color: LexSnTheme.primary, fontWeight: FontWeight.w700),
                markerDecoration: const BoxDecoration(
                  color: LexSnTheme.accent, shape: BoxShape.circle,
                ),
                markersMaxCount: 3,
              ),
              daysOfWeekStyle: const DaysOfWeekStyle(
                weekdayStyle: TextStyle(fontSize: 11, color: Color(0xFF9CA3AF), fontWeight: FontWeight.w600),
                weekendStyle: TextStyle(fontSize: 11, color: Color(0xFFD1D5DB), fontWeight: FontWeight.w600),
              ),
              onDaySelected: (selected, focused) => setState(() {
                _selectedDay = selected;
                _focusedDay  = focused;
              }),
              onPageChanged: (focused) => setState(() => _focusedDay = focused),
            ),

            const Divider(height: 0),

            // Liste du jour sélectionné
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
              child: Row(children: [
                Text(
                  DateFormat('EEEE d MMMM', 'fr_FR').format(selected),
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: LexSnTheme.primary),
                ),
                const SizedBox(width: 8),
                if (audiencesJour.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: LexSnTheme.infoBg, borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text('${audiencesJour.length}', style: const TextStyle(
                      fontSize: 11, fontWeight: FontWeight.w700, color: LexSnTheme.info,
                    )),
                  ),
              ]),
            ),

            Expanded(
              child: audiencesJour.isEmpty
                  ? const Center(child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.event_available_outlined, size: 36, color: Color(0xFFD1D5DB)),
                        SizedBox(height: 8),
                        Text('Aucune audience ce jour', style: TextStyle(fontSize: 13, color: Color(0xFF9CA3AF))),
                      ],
                    ))
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 80),
                      itemCount: audiencesJour.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (_, i) => _AudienceCard(audience: audiencesJour[i]),
                    ),
            ),
          ]);
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: LexSnTheme.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add, size: 18),
        label: const Text('Audience', style: TextStyle(fontSize: 13)),
        onPressed: () => context.go('/dossiers'),
      ),
    );
  }
}

class _AudienceCard extends StatelessWidget {
  final AudienceModel audience;
  const _AudienceCard({required this.audience});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.go('/audiences/${audience.id}/modifier'),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: LexSnTheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: audience.estDansLes48h && !audience.estPassee
                ? const Color(0xFFFCA5A5) : LexSnTheme.border,
            width: audience.estDansLes48h && !audience.estPassee ? 1 : 0.5,
          ),
        ),
        child: Row(children: [
          Container(
            width: 52, height: 52,
            decoration: BoxDecoration(
              color: audience.estPassee ? const Color(0xFFF3F4F6) : LexSnTheme.primary,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(DateFormat('HH').format(audience.dateHeure), style: TextStyle(
                  fontSize: 16, fontWeight: FontWeight.w700,
                  color: audience.estPassee ? const Color(0xFF9CA3AF) : Colors.white,
                )),
                Text(DateFormat('mm').format(audience.dateHeure), style: TextStyle(
                  fontSize: 11, color: audience.estPassee ? const Color(0xFFD1D5DB) : Colors.white70,
                )),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(audience.clientNom, style: const TextStyle(
                fontWeight: FontWeight.w700, fontSize: 14, color: LexSnTheme.primary,
              )),
              Text(audience.objet, style: const TextStyle(fontSize: 13)),
              if (audience.salle != null)
                Text(audience.salle!, style: const TextStyle(fontSize: 11, color: Color(0xFF9CA3AF))),
              Text(audience.dossierReference, style: const TextStyle(
                fontSize: 11, color: Color(0xFFB5C4D4), fontFamily: 'monospace',
              )),
            ],
          )),
          const SizedBox(width: 8),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              StatutBadge(statut: audience.statut, styles: audienceStatutStyles),
              if (audience.estDansLes48h && !audience.estPassee) ...[
                const SizedBox(height: 4),
                const Icon(Icons.notifications_active, size: 14, color: LexSnTheme.danger),
              ],
            ],
          ),
        ]),
      ),
    );
  }
}