import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../services/api_client.dart';
import '../../utils/theme.dart';

class DossierFormScreen extends ConsumerStatefulWidget {
  final int? dossierId;
  const DossierFormScreen({super.key, this.dossierId});

  @override
  ConsumerState<DossierFormScreen> createState() => _DossierFormScreenState();
}

class _DossierFormScreenState extends ConsumerState<DossierFormScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _loading = false;

  final _intituleCtrl   = TextEditingController();
  final _descCtrl       = TextEditingController();
  final _partiesCtrl    = TextEditingController();
  final _parquetCtrl    = TextEditingController();
  final _honorairesCtrl = TextEditingController();

  String _typeAffaire = 'civil';
  String _juridiction = '';
  int? _clientId;
  int? _avocatId;
  DateTime _dateOuverture = DateTime.now();

  List<Map<String, dynamic>> _clients = [];
  List<Map<String, dynamic>> _avocats = [];
  bool _dataLoaded = false;
  String? _dataError;

  // Erreurs de validation par champ (retournées par Laravel)
  Map<String, String> _fieldErrors = {};

  static const _types = {
    'civil': 'Civil',
    'penal': 'Pénal',
    'commercial': 'Commercial',
    'administratif': 'Administratif',
    'social': 'Social / Travail',
    'foncier': 'Foncier',
    'famille': 'Famille',
    'autre': 'Autre',
  };

  static const _juridictions = {
    '': 'Non renseigné',
    'tribunal_hors_classe_dakar': 'THC Dakar',
    'tribunal_regional': 'Tribunal Régional',
    'tribunal_departement': 'Tribunal Dép.',
    'cour_appel': "Cour d'Appel",
    'cour_supreme': 'Cour Suprême',
    'cour_arbitrage_ohada': 'CCJA (OHADA)',
    'autre': 'Autre',
  };

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final api = ref.read(apiClientProvider);
      final results = await Future.wait([
        api.getClients(),
        api.getDashboard(),
      ]);
      if (mounted) {
        setState(() {
          _clients = List<Map<String, dynamic>>.from(
              (results[0]['data'] as List<dynamic>? ?? []));
          _avocats = List<Map<String, dynamic>>.from(
              (results[1]['avocats'] as List<dynamic>? ?? []));
          _dataLoaded = true;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _dataLoaded = true;
          _dataError = 'Impossible de charger les données: $e';
        });
      }
    }
  }

  Future<void> _pickDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _dateOuverture,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      locale: const Locale('fr'),
    );
    if (d != null) setState(() => _dateOuverture = d);
  }

  Future<void> _submit() async {
    // Effacer les erreurs précédentes
    setState(() => _fieldErrors = {});

    if (!_formKey.currentState!.validate()) return;

    if (_clientId == null) {
      setState(() => _fieldErrors['client_id'] = 'Veuillez sélectionner un client.');
      _showErrorBanner('Veuillez sélectionner un client.');
      return;
    }
    if (_avocatId == null) {
      setState(() => _fieldErrors['avocat_id'] = 'Veuillez sélectionner un avocat.');
      _showErrorBanner('Veuillez sélectionner un avocat.');
      return;
    }

    setState(() => _loading = true);

    try {
      final data = {
        'intitule': _intituleCtrl.text.trim(),
        'type_affaire': _typeAffaire,
        'client_id': _clientId,
        'avocat_id': _avocatId,
        if (_juridiction.isNotEmpty) 'juridiction': _juridiction,
        if (_parquetCtrl.text.isNotEmpty) 'numero_parquet': _parquetCtrl.text.trim(),
        if (_descCtrl.text.isNotEmpty) 'description': _descCtrl.text.trim(),
        if (_partiesCtrl.text.isNotEmpty) 'parties_adverses': _partiesCtrl.text.trim(),
        'date_ouverture': DateFormat('yyyy-MM-dd').format(_dateOuverture),
        if (_honorairesCtrl.text.isNotEmpty)
          'honoraires_prevus':
              double.tryParse(_honorairesCtrl.text.replaceAll(' ', '').replaceAll(',', '.')) ?? 0,
      };

      final result = await ref.read(apiClientProvider).createDossier(data);
      final id = (result['data'] as Map?)?.entries
              .firstWhere((e) => e.key == 'id', orElse: () => MapEntry('id', null))
              .value as int? ??
          result['id'] as int?;

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Dossier ouvert avec succès ✓'),
            backgroundColor: LexSnTheme.success,
          ),
        );
        if (id != null) {
          context.go('/dossiers/$id');
        } else {
          context.go('/dossiers');
        }
      }
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          // Remplir les erreurs par champ
          _fieldErrors = e.validationErrors.map(
            (k, v) => MapEntry(k, v.first),
          );
        });
        _showErrorBanner(e.userMessage);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        _showErrorBanner('Erreur inattendue: $e');
      }
    }
  }

  void _showErrorBanner(String msg) {
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
    _intituleCtrl.dispose();
    _descCtrl.dispose();
    _partiesCtrl.dispose();
    _parquetCtrl.dispose();
    _honorairesCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.dossierId == null ? 'Nouveau dossier' : 'Modifier le dossier'),
      ),
      body: !_dataLoaded
          ? const Center(child: CircularProgressIndicator(color: LexSnTheme.primary))
          : _dataError != null && _clients.isEmpty && _avocats.isEmpty
              ? _ErrorRetry(message: _dataError!, onRetry: _loadData)
              : Form(
                  key: _formKey,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [

                      // ── Intitulé ──────────────────────────────────────────
                      TextFormField(
                        controller: _intituleCtrl,
                        decoration: InputDecoration(
                          labelText: 'Intitulé du dossier *',
                          hintText: 'Ex: Diallo c/ Immo SN — Litige foncier',
                          errorText: _fieldErrors['intitule'],
                        ),
                        maxLines: 2,
                        validator: (v) =>
                            (v?.trim().isNotEmpty ?? false) ? null : 'Champ requis',
                        textCapitalization: TextCapitalization.sentences,
                      ),

                      const SizedBox(height: 20),

                      // ── Type d'affaire ────────────────────────────────────
                      const _Label('Type d\'affaire *'),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _types.entries.map((e) {
                          final sel = _typeAffaire == e.key;
                          return GestureDetector(
                            onTap: () => setState(() => _typeAffaire = e.key),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 8),
                              decoration: BoxDecoration(
                                color: sel ? LexSnTheme.primary : LexSnTheme.surface,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                    color: sel ? LexSnTheme.primary : LexSnTheme.border),
                              ),
                              child: Text(e.value,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                    color: sel ? Colors.white : const Color(0xFF374151),
                                  )),
                            ),
                          );
                        }).toList(),
                      ),
                      if (_fieldErrors['type_affaire'] != null)
                        _FieldErrorText(_fieldErrors['type_affaire']!),

                      const SizedBox(height: 20),

                      // ── Client ────────────────────────────────────────────
                      const _Label('Client *'),
                      if (_clients.isEmpty)
                        _NoDataWarning(
                          message: 'Aucun client disponible.',
                          actionLabel: 'Créer',
                          onAction: () => context.go('/clients/nouveau'),
                        )
                      else
                        DropdownButtonFormField<int>(
                          value: _clientId,
                          isExpanded: true,
                          decoration: InputDecoration(
                            labelText: 'Sélectionner un client',
                            errorText: _fieldErrors['client_id'],
                          ),
                          items: _clients.map((c) {
                            final nom = c['nom'] as String? ?? '';
                            final prenom = c['prenom'] as String? ?? '';
                            return DropdownMenuItem<int>(
                              value: c['id'] as int,
                              child: Text('$nom $prenom'.trim(),
                                  overflow: TextOverflow.ellipsis),
                            );
                          }).toList(),
                          onChanged: (v) => setState(() {
                            _clientId = v;
                            _fieldErrors.remove('client_id');
                          }),
                          validator: (v) =>
                              v != null ? null : 'Sélectionnez un client',
                        ),

                      const SizedBox(height: 20),

                      // ── Avocat ────────────────────────────────────────────
                      const _Label('Avocat *'),
                      if (_avocats.isEmpty)
                        _NoDataWarning(
                          message: 'Aucun avocat disponible.',
                          actionLabel: 'Actualiser',
                          onAction: _loadData,
                        )
                      else
                        DropdownButtonFormField<int>(
                          value: _avocatId,
                          isExpanded: true,
                          decoration: InputDecoration(
                            labelText: 'Sélectionner un avocat',
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
                          validator: (v) =>
                              v != null ? null : 'Sélectionnez un avocat',
                        ),

                      const SizedBox(height: 20),

                      // ── Juridiction ───────────────────────────────────────
                      DropdownButtonFormField<String>(
                        value: _juridiction,
                        isExpanded: true,
                        decoration: InputDecoration(
                          labelText: 'Juridiction',
                          errorText: _fieldErrors['juridiction'],
                        ),
                        items: _juridictions.entries
                            .map((e) => DropdownMenuItem(
                                value: e.key, child: Text(e.value)))
                            .toList(),
                        onChanged: (v) => setState(() => _juridiction = v ?? ''),
                      ),

                      const SizedBox(height: 16),

                      // ── N° parquet ────────────────────────────────────────
                      TextFormField(
                        controller: _parquetCtrl,
                        decoration: InputDecoration(
                          labelText: 'N° parquet / greffe',
                          hintText: 'Ex: THC/2024/COM/1234',
                          errorText: _fieldErrors['numero_parquet'],
                        ),
                      ),

                      const SizedBox(height: 16),

                      // ── Date d'ouverture ───────────────────────────────────
                      GestureDetector(
                        onTap: _pickDate,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 14),
                          decoration: BoxDecoration(
                            color: LexSnTheme.surface,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: LexSnTheme.border),
                          ),
                          child: Row(children: [
                            const Icon(Icons.calendar_today_outlined,
                                size: 18, color: Color(0xFF9CA3AF)),
                            const SizedBox(width: 10),
                            Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Date d\'ouverture',
                                      style: TextStyle(
                                          fontSize: 12,
                                          color: Color(0xFF9CA3AF))),
                                  Text(
                                    DateFormat('dd MMMM yyyy', 'fr_FR')
                                        .format(_dateOuverture),
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                      color: LexSnTheme.primary,
                                    ),
                                  ),
                                ]),
                            const Spacer(),
                            const Icon(Icons.edit_outlined,
                                size: 16, color: Color(0xFF9CA3AF)),
                          ]),
                        ),
                      ),
                      if (_fieldErrors['date_ouverture'] != null)
                        _FieldErrorText(_fieldErrors['date_ouverture']!),

                      const SizedBox(height: 16),

                      // ── Honoraires ────────────────────────────────────────
                      TextFormField(
                        controller: _honorairesCtrl,
                        decoration: InputDecoration(
                          labelText: 'Honoraires prévus (FCFA)',
                          hintText: 'Ex: 500000',
                          suffixText: 'FCFA',
                          errorText: _fieldErrors['honoraires_prevus'],
                        ),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return null;
                          final parsed = double.tryParse(
                              v.replaceAll(' ', '').replaceAll(',', '.'));
                          if (parsed == null) return 'Montant invalide';
                          return null;
                        },
                      ),

                      const SizedBox(height: 16),

                      // ── Description ───────────────────────────────────────
                      TextFormField(
                        controller: _descCtrl,
                        decoration: InputDecoration(
                          labelText: 'Description / Résumé des faits',
                          hintText: 'Contexte, enjeux, antécédents...',
                          alignLabelWithHint: true,
                          errorText: _fieldErrors['description'],
                        ),
                        maxLines: 4,
                        textCapitalization: TextCapitalization.sentences,
                      ),

                      const SizedBox(height: 16),

                      // ── Parties adverses ──────────────────────────────────
                      TextFormField(
                        controller: _partiesCtrl,
                        decoration: InputDecoration(
                          labelText: 'Parties adverses',
                          hintText: 'Noms, avocats adverses...',
                          alignLabelWithHint: true,
                          errorText: _fieldErrors['parties_adverses'],
                        ),
                        maxLines: 3,
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
                            : const Text('Ouvrir le dossier'),
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
    );
  }
}

// ─── Widgets helpers ─────────────────────────────────────────────────────────

class _Label extends StatelessWidget {
  final String text;
  const _Label(this.text);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(text,
            style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: Color(0xFF6B7280))),
      );
}

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

class _NoDataWarning extends StatelessWidget {
  final String message;
  final String actionLabel;
  final VoidCallback onAction;
  const _NoDataWarning(
      {required this.message,
      required this.actionLabel,
      required this.onAction});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: LexSnTheme.warningBg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFFCD34D)),
        ),
        child: Row(children: [
          const Icon(Icons.warning_outlined, color: LexSnTheme.warning, size: 18),
          const SizedBox(width: 8),
          Expanded(child: Text(message, style: const TextStyle(fontSize: 13))),
          TextButton(
            onPressed: onAction,
            child: Text(actionLabel, style: const TextStyle(fontSize: 13)),
          ),
        ]),
      );
}

class _ErrorRetry extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorRetry({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.error_outline, size: 48, color: LexSnTheme.danger),
            const SizedBox(height: 12),
            Text(message,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Color(0xFF6B7280))),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('Réessayer'),
              onPressed: onRetry,
            ),
          ]),
        ),
      );
}