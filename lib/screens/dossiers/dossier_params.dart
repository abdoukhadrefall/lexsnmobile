class DossierParams {
  final String? q;
  final String? statut;

  const DossierParams({this.q, this.statut});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DossierParams &&
          runtimeType == other.runtimeType &&
          q == other.q &&
          statut == other.statut;

  @override
  int get hashCode => Object.hash(q, statut);
}