import 'package:lexsn_mobile/models/paiement_model.dart';

class FactureModel {
  final int id;
  final String numero;
  final String clientNom;
  final String dossierReference;
  final int? dossierId;
  final DateTime dateEmission;
  final DateTime? dateEcheance;
  final double montantHt;
  final double tva;
  final double montantTtc;
  final double montantPaye;
  final String statut;
  final String? notes;
  final List<PaiementModel> paiements;

  const FactureModel({
    required this.id,
    required this.numero,
    required this.clientNom,
    required this.dossierReference,
    this.dossierId,
    required this.dateEmission,
    this.dateEcheance,
    required this.montantHt,
    required this.tva,
    required this.montantTtc,
    required this.montantPaye,
    required this.statut,
    this.notes,
    this.paiements = const [],
  });

  double get resteAPayer => montantTtc - montantPaye;
  double get pctPaye => montantTtc > 0 ? (montantPaye / montantTtc) : 0;

  static const Map<String, String> statutsLabels = {
    'brouillon': 'Brouillon',
    'envoyee': 'Envoyée',
    'partiellement_payee': 'Partiel',
    'payee': 'Payée',
    'annulee': 'Annulée',
  };

  String get statutLabel => statutsLabels[statut] ?? statut;

  // ✅ PARSE SAFE
  static double _parseDouble(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v) ?? 0;
    return 0;
  }

  static DateTime _parseDate(dynamic v) {
    if (v == null) return DateTime.now();
    if (v is String) return DateTime.tryParse(v) ?? DateTime.now();
    return DateTime.now();
  }

  factory FactureModel.fromJson(Map<String, dynamic> json) {
    final client = json['client'] as Map<String, dynamic>? ?? {};
    final dossier = json['dossier'] as Map<String, dynamic>? ?? {};

    return FactureModel(
      id: (json['id'] as num?)?.toInt() ?? 0,
      numero: json['numero'] as String? ?? '',
      clientNom: (client['nom'] as String? ?? '').replaceAll('\n', ' ').trim(),
      dossierReference: dossier['reference'] as String? ?? '',
      dossierId: (json['dossier_id'] as num?)?.toInt(),
      dateEmission: _parseDate(json['date_emission']),
      dateEcheance: json['date_echeance'] != null
          ? _parseDate(json['date_echeance'])
          : null,
      montantHt: _parseDouble(json['montant_ht']),
      tva: _parseDouble(json['tva']),
      montantTtc: _parseDouble(json['montant_ttc']),
      montantPaye: _parseDouble(json['montant_paye']),
      statut: json['statut'] as String? ?? '',
      notes: json['notes'] as String?,
      paiements: (json['paiements'] as List<dynamic>? ?? [])
          .map((p) => PaiementModel.fromJson(p as Map<String, dynamic>))
          .toList(),
    );
  }
}