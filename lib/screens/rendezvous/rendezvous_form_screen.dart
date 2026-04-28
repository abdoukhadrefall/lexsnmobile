import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../services/api_client.dart';
import '../../models/rendezvous_model.dart';
import '../../utils/theme.dart';

class RendezVousFormScreen extends ConsumerStatefulWidget {
  final int? rdvId;
  final int? clientId;   // pré-remplissage optionnel
  final int? dossierId;

  const RendezVousFormScreen({super.key, this.rdvId, this.clientId, this.dossierId});

  @override
  ConsumerState<RendezVousFormScreen> createState() => _RendezVousFormScreenState();
}

class _RendezVousFormScreenState extends ConsumerState<RendezVousFormScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _loading  = false;
  bool _dataLoaded = false;

  final _titreCtrl       = TextEditingController();
  final _lieuCtrl        = TextEditingController();
  final _lienVisioCtrl   = TextEditingController();
  final _descCtrl        = TextEditingController();
  final _notesCtrl       = TextEditingController();

  String _type    = 'consultation';
  String _statut  = 'planifie';
  bool _enLigne   = false;
  int _rappel     = 60;

  DateTime _debut = DateTime.now().add(const Duration(hours: 1));
  DateTime _fin   = DateTime.now().add(const Duration(hours: 2));

  int? _clientId;
  int? _dossierId;
  int? _userId;

  List<Map<String, dynamic>> _clients = [];
  List<Map<String, dynamic>> _dossiers = [];
  List<Map<String, dynamic>> _avocats  = [];

  Map<String, String> _fieldErrors = {};

  @override
  void initState() {
    super.initState();
    _clientId  = widget.clientId;
    _dossierId = widget.dossierId;
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final api = ref.read(apiClientProvider);
      final results = await Future.wait([
        api.getClients(),
        api.getDossiers(),
        api.getDashboard(),
      ]);
      if (mounted) {
        setState(() {
          _clients  = List<Map<String, dynamic>>.from(results[0]['data'] as List? ?? []);
          _dossiers = List<Map<String, dynamic>>.from(results[1]['data'] as List? ?? []);
          _avocats  = List<Map<String, dynamic>>.from(results[2]['avocats'] as List? ?? []);
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
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 730)),
      locale: const Locale('fr'),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_debut),
    );
    if (time == null) return;
    final newDebut = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    setState(() {
      _debut = newDebut;
      // Ajuster la fin si besoin (durée min 30 min)
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
      lastDate: DateTime.now().add(const Duration(days: 730)),
      locale: const Locale('fr'),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_fin),
    );
    if (time == null) return;
    final newFin = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    if (newFin.isBefore(_debut)) {
      _showError('La fin doit être après le début.');
      return;
    }
    setState(() => _fin = newFin);
  }

  Future<void> _submit() async {
    setState(() => _fieldErrors = {});
    if (!_formKey.currentState!.validate()) return;

    setState(() => _loading = true);

    try {
      final data = {
        'titre':           _titreCtrl.text.trim(),
        'type':            _type,
        'debut':           _debut.toIso8601String(),
        'fin':             _fin.toIso8601String(),
        'statut':          _statut,
        'en_ligne':        _enLigne,
        'rappel_minutes':  _rappel,
        if (_lieuCtrl.text.trim().isNotEmpty && !_enLigne)
          'lieu': _lieuCtrl.text.trim(),
        if (_lienVisioCtrl.text.trim().isNotEmpty && _enLigne)
          'lien_visio': _lienVisioCtrl.text.trim(),
        if (_descCtrl.text.trim().isNotEmpty)
          'description': _descCtrl.text.trim(),
        if (_notesCtrl.text.trim().isNotEmpty)
          'notes': _notesCtrl.text.trim(),
        if (_clientId != null)  'client_id':  _clientId,
        if (_dossierId != null) 'dossier_id': _dossierId,
        if (_userId != null)    'user_id':    _userId,
      };

      if (widget.rdvId != null) {
        await ref.read(apiClientProvider).updateRendezVous(widget.rdvId!, data);
      } else {
        await ref.read(apiClientProvider).createRendezVous(data);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(widget.rdvId != null
              ? 'Rendez-vous mis à jour ✓'
              : 'Rendez-vous créé ✓'),
          backgroundColor: LexSnTheme.success,
        ));
        context.pop();
      }
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _fieldErrors = e.validationErrors.map((k, v) => MapEntry(k, v.first));
        });
        _showError(e.userMessage);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        _showError('Erreur inattendue: $e');
      }
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(msg),
        backgroundColor: LexSnTheme.danger,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 5),
      ));
  }

  @override
  void dispose() {
    _titreCtrl.dispose(); _lieuCtrl.dispose(); _lienVisioCtrl.dispose();
    _descCtrl.dispose();  _notesCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.rdvId == null ? 'Nouveau rendez-vous' : 'Modifier le RDV'),
      ),
      body: !_dataLoaded
          ? const Center(child: CircularProgressIndicator(color: LexSnTheme.primary))
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [

                  // ── Titre ─────────────────────────────────────────────
                  TextFormField(
                    controller: _titreCtrl,
                    decoration: InputDecoration(
                      labelText: 'Titre *',
                      hintText: 'Ex: Consultation Diallo — succession',
                      errorText: _fieldErrors['titre'],
                    ),
                    validator: (v) => (v?.trim().isNotEmpty ?? false) ? null : 'Champ requis',
                    textCapitalization: TextCapitalization.sentences,
                  ),

                  const SizedBox(height: 20),

                  // ── Type ──────────────────────────────────────────────
                  const _Label('Type *'),
                  Wrap(
                    spacing: 8, runSpacing: 8,
                    children: RendezVousModel.typesLabels.entries.map((e) {
                      final sel = _type == e.key;
                      return GestureDetector(
                        onTap: () => setState(() => _type = e.key),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                          decoration: BoxDecoration(
                            color: sel ? LexSnTheme.primary : LexSnTheme.surface,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: sel ? LexSnTheme.primary : LexSnTheme.border),
                          ),
                          child: Text(e.value, style: TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w500,
                            color: sel ? Colors.white : const Color(0xFF374151),
                          )),
                        ),
                      );
                    }).toList(),
                  ),
                  if (_fieldErrors['type'] != null)
                    _FieldError(_fieldErrors['type']!),

                  const SizedBox(height: 20),

                  // ── Début ─────────────────────────────────────────────
                  _DateTimePicker(
                    label: 'Début *',
                    value: _debut,
                    onTap: _pickDebut,
                    hasError: _fieldErrors['debut'] != null,
                  ),
                  if (_fieldErrors['debut'] != null)
                    _FieldError(_fieldErrors['debut']!),

                  const SizedBox(height: 12),

                  // ── Fin ───────────────────────────────────────────────
                  _DateTimePicker(
                    label: 'Fin *',
                    value: _fin,
                    onTap: _pickFin,
                    hasError: _fieldErrors['fin'] != null,
                  ),
                  if (_fieldErrors['fin'] != null)
                    _FieldError(_fieldErrors['fin']!),

                  // Durée calculée
                  Padding(
                    padding: const EdgeInsets.only(top: 6, left: 4),
                    child: Text(
                      'Durée : ${_dureeLabel()}',
                      style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // ── Lieu / En ligne ───────────────────────────────────
                  SwitchListTile(
                    value: _enLigne,
                    onChanged: (v) => setState(() => _enLigne = v),
                    title: const Text('Réunion en ligne', style: TextStyle(fontSize: 14)),
                    subtitle: const Text('Visioconférence, appel vidéo...', style: TextStyle(fontSize: 12)),
                    activeColor: LexSnTheme.primary,
                    contentPadding: EdgeInsets.zero,
                  ),

                  if (!_enLigne)
                    TextFormField(
                      controller: _lieuCtrl,
                      decoration: InputDecoration(
                        labelText: 'Lieu',
                        hintText: 'Adresse, salle...',
                        prefixIcon: const Icon(Icons.location_on_outlined, size: 18),
                        errorText: _fieldErrors['lieu'],
                      ),
                    ),

                  if (_enLigne)
                    TextFormField(
                      controller: _lienVisioCtrl,
                      decoration: InputDecoration(
                        labelText: 'Lien de la réunion',
                        hintText: 'https://meet.google.com/...',
                        prefixIcon: const Icon(Icons.videocam_outlined, size: 18),
                        errorText: _fieldErrors['lien_visio'],
                      ),
                      keyboardType: TextInputType.url,
                    ),

                  const SizedBox(height: 16),

                  // ── Client ────────────────────────────────────────────
                  DropdownButtonFormField<int>(
                    value: _clientId,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: 'Client (optionnel)',
                      errorText: _fieldErrors['client_id'],
                    ),
                    items: [
                      const DropdownMenuItem<int>(
                          value: null, child: Text('— Aucun —')),
                      ..._clients.map((c) {
                        final nom    = c['nom'] as String? ?? '';
                        final prenom = c['prenom'] as String? ?? '';
                        return DropdownMenuItem<int>(
                          value: c['id'] as int,
                          child: Text('$nom $prenom'.trim(), overflow: TextOverflow.ellipsis),
                        );
                      }),
                    ],
                    onChanged: (v) => setState(() {
                      _clientId = v;
                      _fieldErrors.remove('client_id');
                    }),
                  ),

                  const SizedBox(height: 12),

                  // ── Dossier ───────────────────────────────────────────
                  DropdownButtonFormField<int>(
                    value: _dossierId,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: 'Dossier (optionnel)',
                      errorText: _fieldErrors['dossier_id'],
                    ),
                    items: [
                      const DropdownMenuItem<int>(
                          value: null, child: Text('— Aucun —')),
                      ..._dossiers.map((d) {
                        final ref = d['reference'] as String? ?? '';
                        final intitule = d['intitule'] as String? ?? '';
                        return DropdownMenuItem<int>(
                          value: d['id'] as int,
                          child: Text('$ref — $intitule', overflow: TextOverflow.ellipsis),
                        );
                      }),
                    ],
                    onChanged: (v) => setState(() {
                      _dossierId = v;
                      _fieldErrors.remove('dossier_id');
                    }),
                  ),

                  const SizedBox(height: 12),

                  // ── Assigné à ─────────────────────────────────────────
                  if (_avocats.isNotEmpty)
                    DropdownButtonFormField<int>(
                      value: _userId,
                      isExpanded: true,
                      decoration: InputDecoration(
                        labelText: 'Assigné à',
                        errorText: _fieldErrors['user_id'],
                      ),
                      items: [
                        const DropdownMenuItem<int>(
                            value: null, child: Text('— Moi-même —')),
                        ..._avocats.map((a) {
                          final nom = a['nom'] as String? ?? '';
                          return DropdownMenuItem<int>(
                            value: a['id'] as int,
                            child: Text(nom, overflow: TextOverflow.ellipsis),
                          );
                        }),
                      ],
                      onChanged: (v) => setState(() => _userId = v),
                    ),

                  const SizedBox(height: 16),

                  // ── Rappel ────────────────────────────────────────────
                  DropdownButtonFormField<int>(
                    value: _rappel,
                    decoration: const InputDecoration(
                      labelText: 'Rappel',
                      prefixIcon: Icon(Icons.notifications_outlined, size: 18),
                    ),
                    items: RendezVousModel.rappelOptions.map((opt) =>
                        DropdownMenuItem<int>(
                          value: opt['value'] as int,
                          child: Text(opt['label'] as String),
                        )).toList(),
                    onChanged: (v) => setState(() => _rappel = v ?? 60),
                  ),

                  const SizedBox(height: 16),

                  // ── Statut (modification uniquement) ──────────────────
                  if (widget.rdvId != null) ...[
                    DropdownButtonFormField<String>(
                      value: _statut,
                      decoration: const InputDecoration(labelText: 'Statut'),
                      items: RendezVousModel.statutsLabels.entries
                          .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
                          .toList(),
                      onChanged: (v) => setState(() => _statut = v ?? 'planifie'),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // ── Description ───────────────────────────────────────
                  TextFormField(
                    controller: _descCtrl,
                    decoration: InputDecoration(
                      labelText: 'Description',
                      hintText: 'Objet du rendez-vous, points à aborder...',
                      alignLabelWithHint: true,
                      errorText: _fieldErrors['description'],
                    ),
                    maxLines: 3,
                    textCapitalization: TextCapitalization.sentences,
                  ),

                  const SizedBox(height: 12),

                  // ── Notes internes ────────────────────────────────────
                  TextFormField(
                    controller: _notesCtrl,
                    decoration: InputDecoration(
                      labelText: 'Notes internes',
                      hintText: 'Notes privées...',
                      alignLabelWithHint: true,
                      errorText: _fieldErrors['notes'],
                    ),
                    maxLines: 2,
                    textCapitalization: TextCapitalization.sentences,
                  ),

                  const SizedBox(height: 32),

                  ElevatedButton(
                    onPressed: _loading ? null : _submit,
                    child: _loading
                        ? const SizedBox(
                            width: 20, height: 20,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : Text(widget.rdvId == null
                            ? 'Créer le rendez-vous'
                            : 'Enregistrer'),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
    );
  }

  String _dureeLabel() {
    final diff = _fin.difference(_debut);
    if (diff.isNegative || diff.inMinutes == 0) return 'invalide';
    final h = diff.inHours;
    final m = diff.inMinutes % 60;
    if (h == 0) return '${m}min';
    if (m == 0) return '${h}h';
    return '${h}h${m.toString().padLeft(2, '0')}';
  }
}

// ─── Widgets helpers ─────────────────────────────────────────────────────────

class _Label extends StatelessWidget {
  final String text;
  const _Label(this.text);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(text, style: const TextStyle(
          fontSize: 13, fontWeight: FontWeight.w500, color: Color(0xFF6B7280))),
      );
}

class _FieldError extends StatelessWidget {
  final String message;
  const _FieldError(this.message);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 6, left: 12),
        child: Text(message, style: const TextStyle(fontSize: 12, color: LexSnTheme.danger)),
      );
}

class _DateTimePicker extends StatelessWidget {
  final String label;
  final DateTime value;
  final VoidCallback onTap;
  final bool hasError;
  const _DateTimePicker({
    required this.label, required this.value,
    required this.onTap, this.hasError = false,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: LexSnTheme.surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: hasError ? LexSnTheme.danger : LexSnTheme.border,
            ),
          ),
          child: Row(children: [
            const Icon(Icons.calendar_month_outlined,
                size: 18, color: LexSnTheme.primary),
            const SizedBox(width: 10),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF9CA3AF))),
              Text(
                DateFormat('EEEE d MMM yyyy à HH:mm', 'fr_FR').format(value),
                style: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w600, color: LexSnTheme.primary),
              ),
            ]),
            const Spacer(),
            const Icon(Icons.edit_outlined, size: 16, color: Color(0xFF9CA3AF)),
          ]),
        ),
      );
}