class AudienceModel {
  final int id;
  final int dossierId;
  final String dossierReference;
  final String dossierIntitule;
  final String clientNom;
  final String objet;
  final DateTime dateHeure;
  final String statut;
  final String? salle;
  final DateTime? dateRenvoi;
  final String? resultat;
  final bool rappelEnvoye;

  const AudienceModel({
    required this.id,
    required this.dossierId,
    required this.dossierReference,
    required this.dossierIntitule,
    required this.clientNom,
    required this.objet,
    required this.dateHeure,
    required this.statut,
    this.salle,
    this.dateRenvoi,
    this.resultat,
    this.rappelEnvoye = false,
  });

  // ─── Labels ──────────────────────────────
  static const Map<String, String> statutsLabels = {
    'planifiee': 'Planifiée',
    'tenue': 'Tenue',
    'renvoyee': 'Renvoyée',
    'annulee': 'Annulée',
  };

  String get statutLabel => statutsLabels[statut] ?? statut;

  // ─── Helpers safe parse ───────────────────
  static int _toInt(dynamic v) {
    if (v == null) return 0;
    if (v is int) return v;
    if (v is String) return int.tryParse(v) ?? 0;
    if (v is double) return v.toInt();
    return 0;
  }

  static DateTime _toDate(dynamic v) {
    if (v == null) return DateTime.now();
    return DateTime.tryParse(v.toString()) ?? DateTime.now();
  }

  // ─── Status helpers ──────────────────────
  bool get estDansLes48h {
    final diff = dateHeure.difference(DateTime.now());
    return diff.inHours >= 0 && diff.inHours <= 48;
  }

  bool get estPassee => dateHeure.isBefore(DateTime.now());

  // ─── JSON ────────────────────────────────
  factory AudienceModel.fromJson(Map<String, dynamic> json) {
    final dossier = json['dossier'] as Map<String, dynamic>? ?? {};
    final client = dossier['client'] as Map<String, dynamic>? ?? {};

    return AudienceModel(
      id: _toInt(json['id']),
      dossierId: _toInt(json['dossier_id']),

      dossierReference: dossier['reference']?.toString() ?? '',
      dossierIntitule: dossier['intitule']?.toString() ?? '',
      clientNom: client['nom']?.toString() ?? '',

      objet: json['objet']?.toString() ?? '',
      statut: json['statut']?.toString() ?? '',

      dateHeure: _toDate(json['date_heure']),
      salle: json['salle']?.toString(),
      dateRenvoi: json['date_renvoi'] != null
          ? _toDate(json['date_renvoi'])
          : null,

      resultat: json['resultat']?.toString(),
      rappelEnvoye: json['rappel_envoye'] == true,
    );
  }
}