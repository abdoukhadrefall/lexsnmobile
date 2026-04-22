class DossierModel {
  final int id;
  final String reference;
  final String intitule;
  final String typeAffaire;
  final String statut;
  final String? juridiction;
  final String? numeroParquet;
  final String? description;
  final String? partiesAdverses;
  final DateTime dateOuverture;
  final DateTime? dateCloture;
  final double? honorairesPrevus;
  final ClientResume client;
  final AvocatResume avocat;
  final AudienceResume? prochaineAudience;
  final int audiencesCount;
  final int documentsCount;

  const DossierModel({
    required this.id,
    required this.reference,
    required this.intitule,
    required this.typeAffaire,
    required this.statut,
    this.juridiction,
    this.numeroParquet,
    this.description,
    this.partiesAdverses,
    required this.dateOuverture,
    this.dateCloture,
    this.honorairesPrevus,
    required this.client,
    required this.avocat,
    this.prochaineAudience,
    this.audiencesCount = 0,
    this.documentsCount = 0,
  });

  // =========================
  // LABELS
  // =========================

  static const Map<String, String> typesLabels = {
    'civil': 'Civil',
    'penal': 'Pénal',
    'commercial': 'Commercial',
    'administratif': 'Administratif',
    'social': 'Social / Travail',
    'foncier': 'Foncier',
    'famille': 'Famille',
    'autre': 'Autre',
  };

  static const Map<String, String> statutsLabels = {
    'ouvert': 'Ouvert',
    'en_cours': 'En cours',
    'suspendu': 'Suspendu',
    'clos': 'Clos',
    'archive': 'Archivé',
  };

  String get typeLabel => typesLabels[typeAffaire] ?? typeAffaire;
  String get statutLabel => statutsLabels[statut] ?? statut;

  // =========================
  // PARSERS
  // =========================

  static double? _parseDouble(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v);
    return null;
  }

  static DateTime _parseDate(dynamic v) {
    if (v == null) return DateTime.now();
    if (v is String) return DateTime.tryParse(v) ?? DateTime.now();
    return DateTime.now();
  }

  factory DossierModel.fromJson(Map<String, dynamic> json) {
    final raw = (json['data'] is Map<String, dynamic>)
        ? json['data']
        : json;

    return DossierModel(
      id: (raw['id'] as num).toInt(),
      reference: raw['reference'] ?? '',
      intitule: raw['intitule'] ?? '',
      typeAffaire: raw['type_affaire'] ?? '',
      statut: raw['statut'] ?? '',
      juridiction: raw['juridiction'],
      numeroParquet: raw['numero_parquet'],
      description: raw['description'],
      partiesAdverses: raw['parties_adverses'],
      dateOuverture: _parseDate(raw['date_ouverture']),
      dateCloture: raw['date_cloture'] != null
          ? _parseDate(raw['date_cloture'])
          : null,
      honorairesPrevus: _parseDouble(raw['honoraires_prevus']),
      client: ClientResume.fromJson(raw['client'] ?? {}),
      avocat: AvocatResume.fromJson(raw['avocat'] ?? {}),
      prochaineAudience: raw['prochaine_audience'] != null
          ? AudienceResume.fromJson(raw['prochaine_audience'])
          : null,
      audiencesCount: (raw['audiences_count'] as num?)?.toInt() ?? 0,
      documentsCount: (raw['documents_count'] as num?)?.toInt() ?? 0,
    );
  }
}

class ClientResume {
  final int id;
  final String nom;
  final String? prenom;
  final String? telephone;
  final String type;

  const ClientResume({
    required this.id,
    required this.nom,
    this.prenom,
    this.telephone,
    required this.type,
  });

  String get nomComplet {
    final cleanNom = nom.replaceAll('\n', ' ').trim();
    final cleanPrenom = prenom?.replaceAll('\n', ' ').trim();

    return cleanPrenom != null && cleanPrenom.isNotEmpty
        ? '$cleanNom $cleanPrenom'
        : cleanNom;
  }

  String get initiales {
    final parts = nomComplet.split(' ');
    return parts
        .where((p) => p.isNotEmpty)
        .map((p) => p[0].toUpperCase())
        .take(2)
        .join();
  }

  factory ClientResume.fromJson(Map<String, dynamic> json) {
    return ClientResume(
      id: (json['id'] as num?)?.toInt() ?? 0,
      nom: json['nom'] as String? ?? '',
      prenom: json['prenom'] as String?,
      telephone: json['telephone'] as String?,
      type: json['type'] as String? ?? 'personne_physique',
    );
  }
}
class AvocatResume {
  final int id;
  final String nom;
  final String prenom;

  const AvocatResume({
    required this.id,
    required this.nom,
    required this.prenom,
  });

  String get nomComplet => '$prenom $nom'.trim();

  factory AvocatResume.fromJson(Map<String, dynamic> json) {
    return AvocatResume(
      id: (json['id'] as num?)?.toInt() ?? 0,
      nom: json['nom'] as String? ?? '',
      prenom: json['prenom'] as String? ?? '',
    );
  }
}
class AudienceResume {
  final int id;
  final String objet;
  final DateTime dateHeure;
  final String statut;

  const AudienceResume({
    required this.id,
    required this.objet,
    required this.dateHeure,
    required this.statut,
  });

  factory AudienceResume.fromJson(Map<String, dynamic> json) {
    return AudienceResume(
      id: (json['id'] as num?)?.toInt() ?? 0,
      objet: json['objet'] as String? ?? '',
      dateHeure: DateTime.tryParse(json['date_heure'] ?? '') ?? DateTime.now(),
      statut: json['statut'] as String? ?? '',
    );
  }
}