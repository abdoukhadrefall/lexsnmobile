import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../services/api_client.dart';
import '../../utils/theme.dart';

class AudienceFormScreen extends ConsumerStatefulWidget {
  final int? dossierId;
  final int? audienceId;

  const AudienceFormScreen({super.key, this.dossierId, this.audienceId});

  @override
  ConsumerState<AudienceFormScreen> createState() => _AudienceFormScreenState();
}

class _AudienceFormScreenState extends ConsumerState<AudienceFormScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _loading = false;

  final _objetCtrl    = TextEditingController();
  final _salleCtrl    = TextEditingController();
  final _resultatCtrl = TextEditingController();

  DateTime _dateHeure  = DateTime.now().add(const Duration(days: 7));
  String _statut       = 'planifiee';
  DateTime? _dateRenvoi;
  int? _dossierId;
  int? _avocatId;

  List<Map<String, dynamic>> _dossiers = [];
  List<Map<String, dynamic>> _avocats  = [];
  bool _dataLoaded = false;

  // Erreurs de validation par champ
  Map<String, String> _fieldErrors = {};

  static const _statuts = {
    'planifiee': 'Planifiée',
    'tenue': 'Tenue',
    'renvoyee': 'Renvoyée',
    'annulee': 'Annulée',
  };

  static const _objetsFrequents = [
    'Mise en état',
    'Plaidoiries',
    'Délibéré',
    'Renvoi pour conclusions',
    'Comparution des parties',
    'Tentative de conciliation',
    'Audience correctionnelle',
    'Confrontation',
    'Expertise',
    'Prononcé du jugement',
  ];

  @override
  void initState() {
    super.initState();
    _dossierId = widget.dossierId;
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final api = ref.read(apiClientProvider);
      final results = await Future.wait([
        api.getDossiers(),
        api.getDashboard(),
      ]);
      if (mounted) {
        setState(() {
          _dossiers = List<Map<String, dynamic>>.from(
              (results[0]['data'] as List<dynamic>? ?? []));
          _avocats = List<Map<String, dynamic>>.from(
              (results[1]['avocats'] as List<dynamic>? ?? []));
          _dataLoaded = true;
          // Pré-sélectionner le premier avocat si un seul
          if (_avocatId == null && _avocats.length == 1) {
            _avocatId = _avocats.first['id'] as int?;
          }
        });
      }
    } catch (_) {
      if (mounted) setState(() => _dataLoaded = true);
    }
  }

  Future<void> _pickDateTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _dateHeure,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 730)),
      locale: const Locale('fr'),
    );
    if (date == null || !mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_dateHeure),
    );
    if (time == null) return;

    setState(() {
      _dateHeure = DateTime(
          date.year, date.month, date.day, time.hour, time.minute);
    });
  }

  Future<void> _pickRenvoi() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _dateRenvoi ?? _dateHeure.add(const Duration(days: 30)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 730)),
      locale: const Locale('fr'),
    );
    if (date != null) setState(() => _dateRenvoi = date);
  }

  Future<void> _submit() async {
    setState(() => _fieldErrors = {});

    if (!_formKey.currentState!.validate()) return;

    if (_dossierId == null) {
      setState(() => _fieldErrors['dossier_id'] = 'Sélectionnez un dossier.');
      _showError('Veuillez sélectionner un dossier.');
      return;
    }
    if (_avocatId == null) {
      setState(() => _fieldErrors['avocat_id'] = 'Sélectionnez un avocat.');
      _showError('Veuillez sélectionner un avocat.');
      return;
    }
    if (_statut == 'renvoyee' && _dateRenvoi == null) {
      _showError('Veuillez indiquer la date de renvoi.');
      return;
    }

    setState(() => _loading = true);

    try {
      final data = {
        'dossier_id': _dossierId,
        'avocat_id': _avocatId,
        'objet': _objetCtrl.text.trim(),
        'date_heure': _dateHeure.toIso8601String(),
        'statut': _statut,
        if (_salleCtrl.text.trim().isNotEmpty) 'salle': _salleCtrl.text.trim(),
        if (_resultatCtrl.text.trim().isNotEmpty)
          'resultat': _resultatCtrl.text.trim(),
        if (_statut == 'renvoyee' && _dateRenvoi != null)
          'date_renvoi': DateFormat('yyyy-MM-dd').format(_dateRenvoi!),
      };

      if (widget.audienceId != null) {
        await ref.read(apiClientProvider).updateAudience(widget.audienceId!, data);
      } else {
        await ref.read(apiClientProvider).createAudience(data);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(widget.audienceId != null
              ? 'Audience mise à jour ✓'
              : 'Audience planifiée ✓'),
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
    _objetCtrl.dispose();
    _salleCtrl.dispose();
    _resultatCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.audienceId == null
            ? 'Planifier une audience'
            : 'Modifier l\'audience'),
      ),
      body: !_dataLoaded
          ? const Center(
              child: CircularProgressIndicator(color: LexSnTheme.primary))
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [

                  // ── Sélection dossier ──────────────────────────────────
                  if (widget.dossierId == null) ...[
                    DropdownButtonFormField<int>(
                      value: _dossierId,
                      isExpanded: true,
                      decoration: InputDecoration(
                        labelText: 'Dossier *',
                        errorText: _fieldErrors['dossier_id'],
                      ),
                      items: _dossiers.map((d) {
                        final ref = d['reference'] as String? ?? '';
                        final clientNom = (d['client'] as Map?)?['nom'] as String? ?? '';
                        final intitule = d['intitule'] as String? ?? '';
                        return DropdownMenuItem<int>(
                          value: d['id'] as int,
                          child: Text(
                            '$ref${clientNom.isNotEmpty ? ' — $clientNom' : ''}${intitule.isNotEmpty ? ' ($intitule)' : ''}',
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      }).toList(),
                      onChanged: (v) => setState(() {
                        _dossierId = v;
                        _fieldErrors.remove('dossier_id');
                      }),
                      validator: (v) => v != null ? null : 'Sélectionnez un dossier',
                    ),
                  ] else ...[
                    // Affichage dossier fixe
                    Builder(builder: (_) {
                      final dos = _dossiers
                          .where((d) => d['id'] == _dossierId)
                          .firstOrNull;
                      return Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: LexSnTheme.infoBg,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(children: [
                          const Icon(Icons.folder_outlined,
                              color: LexSnTheme.info, size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              dos != null
                                  ? '${dos['reference']} — ${(dos['client'] as Map?)?['nom'] ?? ''}'
                                  : 'Dossier #$_dossierId',
                              style: const TextStyle(
                                  fontWeight: FontWeight.w500,
                                  color: LexSnTheme.primary),
                            ),
                          ),
                        ]),
                      );
                    }),
                  ],

                  const SizedBox(height: 16),

                  // ── Avocat ─────────────────────────────────────────────
                  DropdownButtonFormField<int>(
                    value: _avocatId,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: 'Avocat *',
                      errorText: _fieldErrors['avocat_id'],
                    ),
                    items: _avocats.map((a) {
                      final nom = a['nom'] as String? ?? '';
                      final prenom = a['prenom'] as String? ?? '';
                      return DropdownMenuItem<int>(
                        value: a['id'] as int,
                        child: Text('$nom $prenom'.trim(),
                            overflow: TextOverflow.ellipsis),
                      );
                    }).toList(),
                    onChanged: (v) => setState(() {
                      _avocatId = v;
                      _fieldErrors.remove('avocat_id');
                    }),
                    validator: (v) => v != null ? null : 'Sélectionnez un avocat',
                  ),

                  const SizedBox(height: 16),

                  // ── Objet ──────────────────────────────────────────────
                  TextFormField(
                    controller: _objetCtrl,
                    decoration: InputDecoration(
                      labelText: 'Objet de l\'audience *',
                      errorText: _fieldErrors['objet'],
                    ),
                    validator: (v) =>
                        (v?.trim().isNotEmpty ?? false) ? null : 'Champ requis',
                  ),
                  const SizedBox(height: 8),

                  // Suggestions objets fréquents
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: _objetsFrequents.map((o) => GestureDetector(
                          onTap: () => setState(() => _objetCtrl.text = o),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: LexSnTheme.surface,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: LexSnTheme.border),
                            ),
                            child: Text(o,
                                style: const TextStyle(
                                    fontSize: 11, color: Color(0xFF6B7280))),
                          ),
                        )).toList(),
                  ),

                  const SizedBox(height: 16),

                  // ── Date & heure ───────────────────────────────────────
                  GestureDetector(
                    onTap: _pickDateTime,
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: LexSnTheme.surface,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: _fieldErrors['date_heure'] != null
                              ? LexSnTheme.danger
                              : LexSnTheme.border,
                        ),
                      ),
                      child: Row(children: [
                        const Icon(Icons.calendar_month_outlined,
                            size: 20, color: LexSnTheme.primary),
                        const SizedBox(width: 12),
                        Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Date et heure *',
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: Color(0xFF9CA3AF))),
                              Text(
                                DateFormat('EEEE d MMMM yyyy à HH:mm', 'fr_FR')
                                    .format(_dateHeure),
                                style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: LexSnTheme.primary),
                              ),
                            ]),
                        const Spacer(),
                        const Icon(Icons.edit_outlined,
                            size: 16, color: Color(0xFF9CA3AF)),
                      ]),
                    ),
                  ),
                  if (_fieldErrors['date_heure'] != null)
                    _FieldErrorText(_fieldErrors['date_heure']!),

                  const SizedBox(height: 16),

                  // ── Salle ──────────────────────────────────────────────
                  TextFormField(
                    controller: _salleCtrl,
                    decoration: InputDecoration(
                      labelText: 'Salle d\'audience',
                      hintText: 'Ex: Chambre correctionnelle n°3',
                      errorText: _fieldErrors['salle'],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // ── Statut (modification uniquement) ────────────────────
                  if (widget.audienceId != null) ...[
                    DropdownButtonFormField<String>(
                      value: _statut,
                      decoration: const InputDecoration(labelText: 'Statut'),
                      items: _statuts.entries
                          .map((e) => DropdownMenuItem(
                              value: e.key, child: Text(e.value)))
                          .toList(),
                      onChanged: (v) =>
                          setState(() => _statut = v ?? 'planifiee'),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // ── Date de renvoi ─────────────────────────────────────
                  if (_statut == 'renvoyee') ...[
                    GestureDetector(
                      onTap: _pickRenvoi,
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: LexSnTheme.warningBg,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFFCD34D)),
                        ),
                        child: Row(children: [
                          const Icon(Icons.event_repeat,
                              size: 18, color: LexSnTheme.warning),
                          const SizedBox(width: 10),
                          Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Date de renvoi *',
                                    style: TextStyle(
                                        fontSize: 12,
                                        color: LexSnTheme.warning)),
                                Text(
                                  _dateRenvoi != null
                                      ? DateFormat('dd MMMM yyyy', 'fr_FR')
                                          .format(_dateRenvoi!)
                                      : 'Appuyer pour sélectionner',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      color: LexSnTheme.warning),
                                ),
                              ]),
                        ]),
                      ),
                    ),
                    if (_fieldErrors['date_renvoi'] != null)
                      _FieldErrorText(_fieldErrors['date_renvoi']!),
                    const SizedBox(height: 16),
                  ],

                  // ── Résultat ───────────────────────────────────────────
                  TextFormField(
                    controller: _resultatCtrl,
                    decoration: InputDecoration(
                      labelText: 'Résultat / Compte-rendu',
                      hintText: 'Ce qui s\'est passé lors de l\'audience...',
                      alignLabelWithHint: true,
                      errorText: _fieldErrors['resultat'],
                    ),
                    maxLines: 4,
                    textCapitalization: TextCapitalization.sentences,
                  ),

                  const SizedBox(height: 32),

                  ElevatedButton(
                    onPressed: _loading ? null : _submit,
                    child: _loading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2))
                        : Text(widget.audienceId == null
                            ? 'Planifier l\'audience'
                            : 'Enregistrer'),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
    );
  }
}

// ─── Helper ───────────────────────────────────────────────────────────────────

class _FieldErrorText extends StatelessWidget {
  final String message;
  const _FieldErrorText(this.message);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 6, left: 12),
        child: Text(message,
            style: const TextStyle(fontSize: 12, color: LexSnTheme.danger)),
      );
      
}