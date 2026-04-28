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
  final List<String> permissions;
  final List<String> roles;

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
    this.permissions = const [],
    this.roles = const [],
  });

  String get nomComplet => '$prenom $nom'.trim();
  String get initiales =>
      (prenom.isNotEmpty ? prenom[0] : '') + (nom.isNotEmpty ? nom[0] : '');

  bool get isAdmin     => role == 'admin'    || roles.contains('admin');
  bool get isAvocat    => role == 'avocat'   || roles.contains('avocat');
  bool get isStagiaire => role == 'stagiaire'|| roles.contains('stagiaire');

  bool hasPermission(String perm) => permissions.contains(perm);

  factory UserModel.fromJson(Map<String, dynamic> json) {
    final cabinet = json['cabinet'] as Map<String, dynamic>?;
    final perms = (json['permissions'] as List<dynamic>?)
            ?.map((e) => e.toString()).toList() ?? [];
    final rolesList = (json['roles'] as List<dynamic>?)
            ?.map((e) => e.toString()).toList() ?? [];

    return UserModel(
      id:               json['id'] as int,
      nom:              json['nom'] as String,
      prenom:           json['prenom'] as String,
      email:            json['email'] as String,
      role:             json['role'] as String,
      telephone:        json['telephone'] as String?,
      specialite:       json['specialite'] as String?,
      matriculeBarreau: json['matricule_barreau'] as String?,
      cabinetId:        json['cabinet_id'] as int,
      cabinetNom:       cabinet?['nom'] as String? ?? '',
      permissions:      perms,
      roles:            rolesList,
    );
  }
}