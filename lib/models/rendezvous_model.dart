class RendezVousModel {
  final int id;
  final String titre;
  final String type;
  final String statut;
  final DateTime debut;
  final DateTime fin;
  final int dureeMinutes;
  final String dureeFormattee;
  final String? lieu;
  final bool enLigne;
  final String? lienVisio;
  final String? description;
  final String? notes;
  final int rappelMinutes;
  final bool rappelEnvoye;
  final bool estPasse;
  final bool dans24h;

  // Relations optionnelles
  final RdvClientResume? client;
  final RdvDossierResume? dossier;
  final RdvUserResume? user;

  const RendezVousModel({
    required this.id,
    required this.titre,
    required this.type,
    required this.statut,
    required this.debut,
    required this.fin,
    required this.dureeMinutes,
    required this.dureeFormattee,
    this.lieu,
    required this.enLigne,
    this.lienVisio,
    this.description,
    this.notes,
    this.rappelMinutes = 60,
    this.rappelEnvoye = false,
    this.estPasse = false,
    this.dans24h = false,
    this.client,
    this.dossier,
    this.user,
  });

  // ─── Types & statuts ─────────────────────────────────────────────────────────
  static const Map<String, String> typesLabels = {
    'consultation':     'Consultation',
    'audience':         'Audience',
    'reunion':          'Réunion',
    'appel':            'Appel téléphonique',
    'visite_cabinet':   'Visite cabinet',
    'expertise':        'Expertise',
    'mediation':        'Médiation',
    'autre':            'Autre',
  };

  static const Map<String, String> statutsLabels = {
    'planifie':  'Planifié',
    'confirme':  'Confirmé',
    'annule':    'Annulé',
    'termine':   'Terminé',
    'reporte':   'Reporté',
  };

  static const List<Map<String, dynamic>> rappelOptions = [
    {'value': 15,   'label': '15 min avant'},
    {'value': 30,   'label': '30 min avant'},
    {'value': 60,   'label': '1 heure avant'},
    {'value': 120,  'label': '2 heures avant'},
    {'value': 1440, 'label': 'La veille'},
  ];

  String get typeLabel   => typesLabels[type] ?? type;
  String get statutLabel => statutsLabels[statut] ?? statut;

  bool get estAnnule  => statut == 'annule';
  bool get estConfirme => statut == 'confirme';

  static int _toInt(dynamic v) {
    if (v is int) return v;
    if (v is double) return v.toInt();
    if (v is String) return int.tryParse(v) ?? 0;
    return 0;
  }

  static DateTime _toDate(dynamic v) =>
      v != null ? DateTime.tryParse(v.toString()) ?? DateTime.now() : DateTime.now();

  factory RendezVousModel.fromJson(Map<String, dynamic> json) {
    final clientJson  = json['client']  as Map<String, dynamic>?;
    final dossierJson = json['dossier'] as Map<String, dynamic>?;
    final userJson    = json['user']    as Map<String, dynamic>?;

    return RendezVousModel(
      id:             _toInt(json['id']),
      titre:          json['titre']?.toString() ?? '',
      type:           json['type']?.toString() ?? 'autre',
      statut:         json['statut']?.toString() ?? 'planifie',
      debut:          _toDate(json['debut']),
      fin:            _toDate(json['fin']),
      dureeMinutes:   _toInt(json['duree_minutes']),
      dureeFormattee: json['duree_formattee']?.toString() ?? '',
      lieu:           json['lieu']?.toString(),
      enLigne:        json['en_ligne'] == true,
      lienVisio:      json['lien_visio']?.toString(),
      description:    json['description']?.toString(),
      notes:          json['notes']?.toString(),
      rappelMinutes:  _toInt(json['rappel_minutes'] ?? 60),
      rappelEnvoye:   json['rappel_envoye'] == true,
      estPasse:       json['est_passe'] == true,
      dans24h:        json['dans_24h'] == true,
      client:  clientJson  != null ? RdvClientResume.fromJson(clientJson)  : null,
      dossier: dossierJson != null ? RdvDossierResume.fromJson(dossierJson) : null,
      user:    userJson    != null ? RdvUserResume.fromJson(userJson)       : null,
    );
  }
}

class RdvClientResume {
  final int id;
  final String nom;
  final String? telephone;
  const RdvClientResume({required this.id, required this.nom, this.telephone});

  factory RdvClientResume.fromJson(Map<String, dynamic> j) => RdvClientResume(
        id: j['id'] as int,
        nom: j['nom']?.toString() ?? '',
        telephone: j['telephone']?.toString(),
      );
}

class RdvDossierResume {
  final int id;
  final String reference;
  final String intitule;
  const RdvDossierResume({required this.id, required this.reference, required this.intitule});

  factory RdvDossierResume.fromJson(Map<String, dynamic> j) => RdvDossierResume(
        id: j['id'] as int,
        reference: j['reference']?.toString() ?? '',
        intitule:  j['intitule']?.toString() ?? '',
      );
}

class RdvUserResume {
  final int id;
  final String nom;
  const RdvUserResume({required this.id, required this.nom});

  factory RdvUserResume.fromJson(Map<String, dynamic> j) => RdvUserResume(
        id:  j['id'] as int,
        nom: j['nom']?.toString() ?? '',
      );
}