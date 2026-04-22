class UserModel {
  final int id;
  final String nom;
  final String prenom;
  final String email;
  final String role;
  final String? telephone;
  final String? specialite;
  final String? matriculeBarreau;
  final int cabinetId;
  final String cabinetNom;

  const UserModel({
    required this.id,
    required this.nom,
    required this.prenom,
    required this.email,
    required this.role,
    this.telephone,
    this.specialite,
    this.matriculeBarreau,
    required this.cabinetId,
    required this.cabinetNom,
  });

  String get nomComplet => '$prenom $nom';
  String get initiales =>
      (prenom.isNotEmpty ? prenom[0] : '') +
      (nom.isNotEmpty ? nom[0] : '');

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] as int,
      nom: json['nom'] as String,
      prenom: json['prenom'] as String,
      email: json['email'] as String,
      role: json['role'] as String,
      telephone: json['telephone'] as String?,
      specialite: json['specialite'] as String?,
      matriculeBarreau: json['matricule_barreau'] as String?,
      cabinetId: json['cabinet_id'] as int,
      cabinetNom: (json['cabinet'] as Map<String, dynamic>?)?['nom'] as String? ?? '',
    );
  }
}