import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../services/api_client.dart';
import '../../utils/theme.dart';

class ClientFormScreen extends ConsumerStatefulWidget {
  final int? clientId;
  const ClientFormScreen({super.key, this.clientId});

  @override
  ConsumerState<ClientFormScreen> createState() => _ClientFormScreenState();
}

class _ClientFormScreenState extends ConsumerState<ClientFormScreen> {
  final _formKey   = GlobalKey<FormState>();
  bool _loading    = false;
  String _type     = 'personne_physique';

  final _nomCtrl           = TextEditingController();
  final _prenomCtrl        = TextEditingController();
  final _telephoneCtrl     = TextEditingController();
  final _emailCtrl         = TextEditingController();
  final _adresseCtrl       = TextEditingController();
  String _ville            = '';

  final _cniCtrl           = TextEditingController();
  final _nationaliteCtrl   = TextEditingController(text: 'Sénégalaise');

  final _raisonSocialeCtrl = TextEditingController();
  final _nineaCtrl         = TextEditingController();
  final _rccmCtrl          = TextEditingController();

  // Erreurs de validation par champ
  Map<String, String> _fieldErrors = {};

  static const _villes = [
    'Dakar', 'Thiès', 'Saint-Louis', 'Ziguinchor', 'Kaolack',
    'Diourbel', 'Tambacounda', 'Louga', 'Fatick', 'Kolda',
    'Matam', 'Kédougou', 'Sédhiou', 'Kaffrine',
  ];

  @override
  void dispose() {
    _nomCtrl.dispose();
    _prenomCtrl.dispose();
    _telephoneCtrl.dispose();
    _emailCtrl.dispose();
    _adresseCtrl.dispose();
    _cniCtrl.dispose();
    _nationaliteCtrl.dispose();
    _raisonSocialeCtrl.dispose();
    _nineaCtrl.dispose();
    _rccmCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _fieldErrors = {});
    if (!_formKey.currentState!.validate()) return;

    setState(() => _loading = true);

    try {
      final data = {
        'type': _type,
        'nom': _nomCtrl.text.trim().toUpperCase(),
        if (_prenomCtrl.text.trim().isNotEmpty)
          'prenom': _prenomCtrl.text.trim(),
        if (_telephoneCtrl.text.trim().isNotEmpty)
          'telephone': _telephoneCtrl.text.trim(),
        if (_emailCtrl.text.trim().isNotEmpty)
          'email': _emailCtrl.text.trim(),
        if (_adresseCtrl.text.trim().isNotEmpty)
          'adresse': _adresseCtrl.text.trim(),
        if (_ville.isNotEmpty) 'ville': _ville,
        if (_type == 'personne_physique') ...{
          if (_cniCtrl.text.trim().isNotEmpty) 'cni': _cniCtrl.text.trim(),
          if (_nationaliteCtrl.text.trim().isNotEmpty)
            'nationalite': _nationaliteCtrl.text.trim(),
        },
        if (_type == 'personne_morale') ...{
          if (_raisonSocialeCtrl.text.trim().isNotEmpty)
            'raison_sociale': _raisonSocialeCtrl.text.trim(),
          if (_nineaCtrl.text.trim().isNotEmpty)
            'ninea': _nineaCtrl.text.trim(),
          if (_rccmCtrl.text.trim().isNotEmpty)
            'rccm': _rccmCtrl.text.trim(),
        },
      };

      await ref.read(apiClientProvider).createClient(data);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Client créé avec succès ✓'),
            backgroundColor: LexSnTheme.success,
          ),
        );
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
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.clientId == null ? 'Nouveau client' : 'Modifier le client'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [

            // ── Type de client ────────────────────────────────────────
            _Section(title: 'Type de client'),
            Row(children: [
              Expanded(child: _TypeButton(
                label: 'Personne physique',
                icon: Icons.person_outline,
                selected: _type == 'personne_physique',
                onTap: () => setState(() {
                  _type = 'personne_physique';
                  _fieldErrors = {};
                }),
              )),
              const SizedBox(width: 12),
              Expanded(child: _TypeButton(
                label: 'Société / Entreprise',
                icon: Icons.business_outlined,
                selected: _type == 'personne_morale',
                onTap: () => setState(() {
                  _type = 'personne_morale';
                  _fieldErrors = {};
                }),
              )),
            ]),
            if (_fieldErrors['type'] != null)
              _FieldError(_fieldErrors['type']!),

            const SizedBox(height: 20),

            // ── Identité (personne physique) ──────────────────────────
            if (_type == 'personne_physique') ...[
              _Section(title: 'Identité'),
              _Field(
                controller: _nomCtrl,
                label: 'Nom *',
                hint: 'DIALLO',
                errorText: _fieldErrors['nom'],
                validator: (v) =>
                    (v?.trim().isNotEmpty ?? false) ? null : 'Champ requis',
                onChanged: (_) =>
                    setState(() => _fieldErrors.remove('nom')),
              ),
              const SizedBox(height: 12),
              _Field(
                controller: _prenomCtrl,
                label: 'Prénom',
                hint: 'Mamadou',
                errorText: _fieldErrors['prenom'],
                onChanged: (_) =>
                    setState(() => _fieldErrors.remove('prenom')),
              ),
              const SizedBox(height: 12),
              _Field(
                controller: _nationaliteCtrl,
                label: 'Nationalité',
                errorText: _fieldErrors['nationalite'],
                onChanged: (_) =>
                    setState(() => _fieldErrors.remove('nationalite')),
              ),
              const SizedBox(height: 12),
              _Field(
                controller: _cniCtrl,
                label: 'N° CNI',
                hint: '1 234567890 12345 6',
                errorText: _fieldErrors['cni'],
                onChanged: (_) =>
                    setState(() => _fieldErrors.remove('cni')),
              ),
            ],

            // ── Société (personne morale) ─────────────────────────────
            if (_type == 'personne_morale') ...[
              _Section(title: 'Société'),
              _Field(
                controller: _raisonSocialeCtrl,
                label: 'Raison sociale *',
                hint: 'SN TECH SARL',
                errorText: _fieldErrors['raison_sociale'],
                validator: (v) =>
                    (v?.trim().isNotEmpty ?? false) ? null : 'Champ requis',
                onChanged: (_) =>
                    setState(() => _fieldErrors.remove('raison_sociale')),
              ),
              const SizedBox(height: 12),
              _Field(
                controller: _nomCtrl,
                label: 'Représentant légal (nom) *',
                hint: 'DIOP',
                errorText: _fieldErrors['nom'],
                validator: (v) =>
                    (v?.trim().isNotEmpty ?? false) ? null : 'Champ requis',
                onChanged: (_) =>
                    setState(() => _fieldErrors.remove('nom')),
              ),
              const SizedBox(height: 12),
              _Field(
                controller: _nineaCtrl,
                label: 'NINEA',
                hint: '0012345 2A3',
                errorText: _fieldErrors['ninea'],
                onChanged: (_) =>
                    setState(() => _fieldErrors.remove('ninea')),
              ),
              const SizedBox(height: 12),
              _Field(
                controller: _rccmCtrl,
                label: 'RCCM',
                hint: 'SN-DKR-2024-B-12345',
                errorText: _fieldErrors['rccm'],
                onChanged: (_) =>
                    setState(() => _fieldErrors.remove('rccm')),
              ),
            ],

            const SizedBox(height: 20),

            // ── Contact ───────────────────────────────────────────────
            _Section(title: 'Contact'),
            _Field(
              controller: _telephoneCtrl,
              label: 'Téléphone',
              hint: '77 xxx xx xx',
              keyboardType: TextInputType.phone,
              errorText: _fieldErrors['telephone'],
              onChanged: (_) =>
                  setState(() => _fieldErrors.remove('telephone')),
            ),
            const SizedBox(height: 12),
            _Field(
              controller: _emailCtrl,
              label: 'Email',
              keyboardType: TextInputType.emailAddress,
              errorText: _fieldErrors['email'],
              validator: (v) {
                if (v == null || v.trim().isEmpty) return null;
                final ok = RegExp(r'^[\w.+\-]+@[\w\-]+\.[a-z]{2,}$',
                        caseSensitive: false)
                    .hasMatch(v.trim());
                return ok ? null : 'Email invalide';
              },
              onChanged: (_) =>
                  setState(() => _fieldErrors.remove('email')),
            ),
            const SizedBox(height: 12),
            _Field(
              controller: _adresseCtrl,
              label: 'Adresse',
              hint: 'Rue, quartier...',
              errorText: _fieldErrors['adresse'],
              onChanged: (_) =>
                  setState(() => _fieldErrors.remove('adresse')),
            ),
            const SizedBox(height: 12),

            // Ville
            DropdownButtonFormField<String>(
              value: _ville.isEmpty ? null : _ville,
              isExpanded: true,
              decoration: InputDecoration(
                labelText: 'Ville',
                errorText: _fieldErrors['ville'],
              ),
              items: _villes
                  .map((v) => DropdownMenuItem(value: v, child: Text(v)))
                  .toList(),
              onChanged: (v) => setState(() {
                _ville = v ?? '';
                _fieldErrors.remove('ville');
              }),
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
                  : const Text('Enregistrer le client'),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

// ─── Widgets helpers ─────────────────────────────────────────────────────────

class _Section extends StatelessWidget {
  final String title;
  const _Section({required this.title});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Text(title.toUpperCase(),
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.6,
              color: Color(0xFF9CA3AF),
            )),
      );
}

class _FieldError extends StatelessWidget {
  final String message;
  const _FieldError(this.message);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 6, left: 12),
        child: Text(message,
            style: const TextStyle(fontSize: 12, color: LexSnTheme.danger)),
      );
}

class _Field extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String? hint;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;
  final String? errorText;
  final ValueChanged<String>? onChanged;

  const _Field({
    required this.controller,
    required this.label,
    this.hint,
    this.keyboardType,
    this.validator,
    this.errorText,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) => TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          errorText: errorText,
        ),
        validator: validator,
        onChanged: onChanged,
        textCapitalization: TextCapitalization.words,
      );
}

class _TypeButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _TypeButton({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding:
              const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
          decoration: BoxDecoration(
            color: selected ? LexSnTheme.primary : LexSnTheme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? LexSnTheme.primary : LexSnTheme.border,
              width: selected ? 1.5 : 0.5,
            ),
          ),
          child: Column(children: [
            Icon(icon,
                color:
                    selected ? Colors.white : const Color(0xFF9CA3AF),
                size: 24),
            const SizedBox(height: 6),
            Text(label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: selected
                      ? Colors.white
                      : const Color(0xFF374151),
                )),
          ]),
        ),
      );
}