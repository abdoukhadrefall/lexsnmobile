class PaiementModel {
  final int id;
  final double montant;
  final DateTime datePaiement;
  final String mode;
  final String? reference;

  const PaiementModel({
    required this.id,
    required this.montant,
    required this.datePaiement,
    required this.mode,
    this.reference,
  });

  static const Map<String, String> modesLabels = {
    'especes': 'Espèces',
    'virement': 'Virement',
    'cheque': 'Chèque',
    'wave': 'Wave',
    'orange_money': 'Orange Money',
    'autre': 'Autre',
  };

  String get modeLabel => modesLabels[mode] ?? mode;

  factory PaiementModel.fromJson(Map<String, dynamic> json) {
    return PaiementModel(
      id: json['id'] as int,
      montant: (json['montant'] as num).toDouble(),
      datePaiement: DateTime.parse(json['date_paiement'] as String),
      mode: json['mode'] as String,
      reference: json['reference'] as String?,
    );
  }
}