import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../services/api_client.dart';
import '../../models/rendezvous_model.dart';
import '../../utils/theme.dart';

class RendezVousFormScreen extends ConsumerStatefulWidget {
  final int? rendezVousId;
  final int? dossierIdPreselect;
  final int? clientIdPreselect;

  const RendezVousFormScreen({
    super.key,
    this.rendezVousId,
    this.dossierIdPreselect,
    this.clientIdPreselect,
  });

  @override
  ConsumerState<RendezVousFormScreen> createState() => _RendezVousFormScreenState();
}

class _RendezVousFormScreenState extends ConsumerState<RendezVousFormScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _loading  = false;
  bool _dataLoaded = false;

  final _titreCtrl       = TextEditingController();
  final _lieuCtrl        = TextEditingController(text: 'Cabinet');
  final _lienVisioCtrl   = TextEditingController();
  final _descriptionCtrl = TextEditingController();
  final _notesCtrl       = TextEditingController();

  String   _type           = 'consultation';
  String   _statut         = 'planifie';
  DateTime _debut          = DateTime.now().add(const Duration(days: 1)).copyWith(hour: 9, minute: 0, second: 0);
  DateTime _fin            = DateTime.now().add(const Duration(days: 1)).copyWith(hour: 10, minute: 0, second: 0);
  bool     _enLigne        = false;
  int      _rappelMinutes  = 60;
  int?     _clientId;
  int?     _dossierId;
  int?     _avocatId;

  List<Map<String, dynamic>> _clients  = [];
  List<Map<String, dynamic>> _dossiers = [];
  List<Map<String, dynamic>> _avocats  = [];
  Map<String, String> _fieldErrors     = {};

  static const _types = RendezVousModel.typesLabels;
  static const _statuts = RendezVousModel.statutsLabels;

  @override
  void initState() {
    super.initState();
    _clientId  = widget.clientIdPreselect;
    _dossierId = widget.dossierIdPreselect;
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final api     = ref.read(apiClientProvider);
      final results = await Future.wait([
        api.getClients(),
        api.getDashboard(),
      ]);
      if (mounted) {
        setState(() {
          _clients  = List<Map<String, dynamic>>.from(results[0]['data'] as List? ?? []);
          _avocats  = List<Map<String, dynamic>>.from(results[1]['avocats'] as List? ?? []);
          _dossiers = List<Map<String, dynamic>>.from(results[1]['dossiers'] as List? ?? []);
          if (_avocatId == null && _avocats.isNotEmpty) {
            _avocatId = _avocats.first['id'] as int?;
          }
          _dataLoaded = true;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _dataLoaded = true);
    }
  }

  Future<void> _pickDebut() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _debut,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365 * 3)),
      locale: const Locale('fr'),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(_debut));
    if (time == null || !mounted) return;
    setState(() {
      _debut = DateTime(date.year, date.month, date.day, time.hour, time.minute);
      if (_fin.isBefore(_debut.add(const Duration(minutes: 30)))) {
        _fin = _debut.add(const Duration(hours: 1));
      }
    });
  }

  Future<void> _pickFin() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _fin,
      firstDate: _debut,
      lastDate: DateTime.now().add(const Duration(days: 365 * 3)),
      locale: const Locale('fr'),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(_fin));
    if (time == null || !mounted) return;
    setState(() => _fin = DateTime(date.year, date.month, date.day, time.hour, time.minute));
  }

  void _setDuree(int minutes) {
    setState(() => _fin = _debut.add(Duration(minutes: minutes)));
  }

  Future<void> _submit() async {
    setState(() => _fieldErrors = {});
    if (!_formKey.currentState!.validate()) return;
    if (_fin.isBefore(_debut)) {
      setState(() => _fieldErrors['fin'] = 'La fin doit être après le début.');
      return;
    }

    setState(() => _loading = true);

    try {
      final data = {
        'titre':           _titreCtrl.text.trim(),
        'type':            _type,
        'statut':          _statut,
        'debut':           _debut.toIso8601String(),
        'fin':             _fin.toIso8601String(),
        'en_ligne':        _enLigne,
        'rappel_minutes':  _rappelMinutes,
        if (_clientId != null)  'client_id':  _clientId,
        if (_dossierId != null) 'dossier_id': _dossierId,
        if (_avocatId != null)  'user_id':    _avocatId,
        if (!_enLigne && _lieuCtrl.text.isNotEmpty)     'lieu':       _lieuCtrl.text.trim(),
        if (_enLigne && _lienVisioCtrl.text.isNotEmpty) 'lien_visio': _lienVisioCtrl.text.trim(),
        if (_descriptionCtrl.text.isNotEmpty)            'description':_descriptionCtrl.text.trim(),
        if (_notesCtrl.text.isNotEmpty)                  'notes':      _notesCtrl.text.trim(),
      };

      final result = widget.rendezVousId == null
          ? await ref.read(apiClientProvider).createRendezVous(data)
          : await ref.read(apiClientProvider).updateRendezVous(widget.rendezVousId!, data);

      final id = ((result['data'] as Map<String, dynamic>?)?['id'] as int?) ?? widget.rendezVousId;

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(widget.rendezVousId == null
              ? 'Rendez-vous créé ✓'
              : 'Rendez-vous mis à jour ✓'),
          backgroundColor: LexSnTheme.success,
        ));
        if (id != null) context.go('/rendezvous/$id');
        else context.go('/rendezvous');
      }
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _fieldErrors = Map<String, String>.fromEntries(
            e.validationErrors.entries.map((en) => MapEntry(en.key, en.value.first)),
          );
        });
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(e.userMessage),
          backgroundColor: LexSnTheme.danger,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Erreur: $e'),
          backgroundColor: LexSnTheme.danger,
        ));
      }
    }
  }

  @override
  void dispose() {
    _titreCtrl.dispose(); _lieuCtrl.dispose(); _lienVisioCtrl.dispose();
    _descriptionCtrl.dispose(); _notesCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.rendezVousId == null ? 'Nouveau rendez-vous' : 'Modifier le RDV'),
      ),
      body: !_dataLoaded
          ? const Center(child: CircularProgressIndicator(color: LexSnTheme.primary))
          : Form(
              key: _formKey,
              child: ListView(padding: const EdgeInsets.all(16), children: [

                // Titre
                TextFormField(
                  controller: _titreCtrl,
                  decoration: InputDecoration(
                    labelText: 'Titre *',
                    hintText: 'Ex: Consultation initiale M. Diallo',
                    errorText: _fieldErrors['titre'],
                  ),
                  validator: (v) => v?.trim().isEmpty ?? true ? 'Champ requis' : null,
                  textCapitalization: TextCapitalization.sentences,
                ),

                const SizedBox(height: 20),

                // Type
                const _Label('Type de rendez-vous *'),
                Wrap(spacing: 8, runSpacing: 8,
                  children: _types.entries.map((e) {
                    final sel = _type == e.key;
                    return GestureDetector(
                      onTap: () => setState(() => _type = e.key),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                        decoration: BoxDecoration(
                          color:  sel ? LexSnTheme.primary : LexSnTheme.surface,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: sel ? LexSnTheme.primary : LexSnTheme.border),
                        ),
                        child: Text(e.value, style: TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w500,
                          color: sel ? Colors.white : const Color(0xFF374151),
                        )),
                      ),
                    );
                  }).toList(),
                ),

                const SizedBox(height: 20),

                // Dates
                const _Label('Date et heure *'),
                Row(children: [
                  Expanded(child: _DateTile(
                    label: 'Début',
                    value: _debut,
                    onTap: _pickDebut,
                  )),
                  const SizedBox(width: 12),
                  Expanded(child: _DateTile(
                    label: 'Fin',
                    value: _fin,
                    onTap: _pickFin,
                    hasError: _fieldErrors.containsKey('fin'),
                  )),
                ]),
                if (_fieldErrors['fin'] != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4, left: 12),
                    child: Text(_fieldErrors['fin']!, style: const TextStyle(fontSize: 12, color: LexSnTheme.danger)),
                  ),

                const SizedBox(height: 10),

                // Durée rapide
                const _Label('Durée rapide'),
                Wrap(spacing: 8,
                  children: {'30 min': 30, '1h': 60, '1h30': 90, '2h': 120}.entries.map((e) =>
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      onPressed: () => _setDuree(e.value),
                      child: Text(e.key, style: const TextStyle(fontSize: 12)),
                    ),
                  ).toList(),
                ),

                const SizedBox(height: 20),

                // Mode
                SwitchListTile(
                  value: _enLigne,
                  onChanged: (v) => setState(() => _enLigne = v),
                  title: const Text('En ligne (visioconférence)', style: TextStyle(fontSize: 14)),
                  subtitle: const Text('Teams, Meet, WhatsApp...', style: TextStyle(fontSize: 12)),
                  activeColor: LexSnTheme.primary,
                  contentPadding: EdgeInsets.zero,
                ),

                if (!_enLigne)
                  TextFormField(
                    controller: _lieuCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Lieu',
                      hintText: 'Ex: Cabinet, chez le client...',
                      prefixIcon: Icon(Icons.location_on_outlined, size: 18),
                    ),
                  ),

                if (_enLigne)
                  TextFormField(
                    controller: _lienVisioCtrl,
                    decoration: InputDecoration(
                      labelText: 'Lien visio',
                      hintText: 'https://meet.google.com/...',
                      prefixIcon: const Icon(Icons.videocam_outlined, size: 18),
                      errorText: _fieldErrors['lien_visio'],
                    ),
                    keyboardType: TextInputType.url,
                  ),

                const SizedBox(height: 20),

                // Rappel
                DropdownButtonFormField<int>(
                  value: _rappelMinutes,
                  decoration: const InputDecoration(labelText: 'Rappel avant le RDV'),
                  items: const [
                    DropdownMenuItem(value: 15,   child: Text('15 minutes')),
                    DropdownMenuItem(value: 30,   child: Text('30 minutes')),
                    DropdownMenuItem(value: 60,   child: Text('1 heure')),
                    DropdownMenuItem(value: 120,  child: Text('2 heures')),
                    DropdownMenuItem(value: 1440, child: Text('1 jour')),
                  ],
                  onChanged: (v) => setState(() => _rappelMinutes = v ?? 60),
                ),

                const SizedBox(height: 20),

                // Client
                DropdownButtonFormField<int>(
                  value: _clientId,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Client (optionnel)'),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('— Aucun —')),
                    ..._clients.map((c) => DropdownMenuItem<int>(
                      value: c['id'] as int,
                      child: Text('${c['nom']} ${c['prenom'] ?? ''}'.trim(), overflow: TextOverflow.ellipsis),
                    )),
                  ],
                  onChanged: (v) => setState(() => _clientId = v),
                ),

                const SizedBox(height: 16),

                // Dossier
                DropdownButtonFormField<int>(
                  value: _dossierId,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Dossier lié (optionnel)'),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('— Aucun —')),
                    ..._dossiers.map((d) => DropdownMenuItem<int>(
                      value: d['id'] as int,
                      child: Text('${d['reference']} — ${d['client'] ?? ''}', overflow: TextOverflow.ellipsis),
                    )),
                  ],
                  onChanged: (v) => setState(() => _dossierId = v),
                ),

                const SizedBox(height: 16),

                // Avocat
                if (_avocats.isNotEmpty)
                  DropdownButtonFormField<int>(
                    value: _avocatId,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Responsable *'),
                    items: _avocats.map((a) => DropdownMenuItem<int>(
                      value: a['id'] as int,
                      child: Text('${a['prenom'] ?? ''} ${a['nom'] ?? ''}'.trim(), overflow: TextOverflow.ellipsis),
                    )).toList(),
                    onChanged: (v) => setState(() => _avocatId = v),
                  ),

                const SizedBox(height: 20),

                // Description
                TextFormField(
                  controller: _descriptionCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Description / Ordre du jour',
                    hintText: 'Documents à apporter, points à aborder...',
                    alignLabelWithHint: true,
                  ),
                  maxLines: 3,
                  textCapitalization: TextCapitalization.sentences,
                ),

                const SizedBox(height: 16),

                // Notes privées
                TextFormField(
                  controller: _notesCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Notes privées',
                    hintText: 'Rappels internes, stratégie...',
                    alignLabelWithHint: true,
                    prefixIcon: Icon(Icons.lock_outline, size: 16),
                  ),
                  maxLines: 3,
                  textCapitalization: TextCapitalization.sentences,
                ),

                const SizedBox(height: 32),

                ElevatedButton(
                  onPressed: _loading ? null : _submit,
                  child: _loading
                      ? const SizedBox(width: 20, height: 20,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : Text(widget.rendezVousId == null ? 'Créer le rendez-vous' : 'Enregistrer'),
                ),
                const SizedBox(height: 24),
              ]),
            ),
    );
  }
}

class _Label extends StatelessWidget {
  final String text;
  const _Label(this.text);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(text, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Color(0xFF6B7280))),
  );
}

class _DateTile extends StatelessWidget {
  final String   label;
  final DateTime value;
  final VoidCallback onTap;
  final bool hasError;

  const _DateTile({required this.label, required this.value, required this.onTap, this.hasError = false});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: LexSnTheme.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: hasError ? LexSnTheme.danger : LexSnTheme.border),
        ),
        child: Row(children: [
          Icon(Icons.calendar_today_outlined, size: 16, color: hasError ? LexSnTheme.danger : const Color(0xFF9CA3AF)),
          const SizedBox(width: 8),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: const TextStyle(fontSize: 10, color: Color(0xFF9CA3AF))),
            Text(
              DateFormat('dd/MM · HH:mm').format(value),
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500,
                  color: hasError ? LexSnTheme.danger : LexSnTheme.primary),
            ),
          ])),
        ]),
      ),
    );
  }
}