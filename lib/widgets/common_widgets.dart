import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../utils/theme.dart';

// ── Formatage ────────────────────────────────────────────────────────────────

String formatMontant(double montant) {
  return NumberFormat('#,###', 'fr_FR').format(montant.round()) + ' FCFA';
}

String formatDate(DateTime date) {
  return DateFormat('dd/MM/yyyy', 'fr_FR').format(date);
}

String formatDateHeure(DateTime date) {
  return DateFormat('dd/MM/yyyy à HH:mm', 'fr_FR').format(date);
}

String formatDateCourt(DateTime date) {
  return DateFormat('d MMM', 'fr_FR').format(date);
}

// ── StatutBadge ──────────────────────────────────────────────────────────────

class StatutBadge extends StatelessWidget {
  final String statut;
  final Map<String, _BadgeStyle> styles;

  const StatutBadge({super.key, required this.statut, required this.styles});

  @override
  Widget build(BuildContext context) {
    final style = styles[statut] ?? _BadgeStyle(
      bg: const Color(0xFFF3F4F6),
      fg: const Color(0xFF6B7280),
      label: statut,
    );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: style.bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        style.label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: style.fg,
        ),
      ),
    );
  }
}

class _BadgeStyle {
  final Color bg;
  final Color fg;
  final String label;
  const _BadgeStyle({required this.bg, required this.fg, required this.label});
}

// Styles statuts dossiers
final dossierStatutStyles = {
  'ouvert':   _BadgeStyle(bg: LexSnTheme.successBg, fg: LexSnTheme.success, label: 'Ouvert'),
  'en_cours': _BadgeStyle(bg: LexSnTheme.infoBg,    fg: LexSnTheme.info,    label: 'En cours'),
  'suspendu': _BadgeStyle(bg: LexSnTheme.warningBg, fg: LexSnTheme.warning, label: 'Suspendu'),
  'clos':     _BadgeStyle(bg: const Color(0xFFF3F4F6), fg: const Color(0xFF374151), label: 'Clos'),
  'archive':  _BadgeStyle(bg: const Color(0xFFE5E7EB), fg: const Color(0xFF6B7280), label: 'Archivé'),
};

// Styles statuts audiences
final audienceStatutStyles = {
  'planifiee': _BadgeStyle(bg: LexSnTheme.infoBg,    fg: LexSnTheme.info,    label: 'Planifiée'),
  'tenue':     _BadgeStyle(bg: LexSnTheme.successBg, fg: LexSnTheme.success, label: 'Tenue'),
  'renvoyee':  _BadgeStyle(bg: LexSnTheme.warningBg, fg: LexSnTheme.warning, label: 'Renvoyée'),
  'annulee':   _BadgeStyle(bg: LexSnTheme.dangerBg,  fg: LexSnTheme.danger,  label: 'Annulée'),
};

// Styles statuts factures
final factureStatutStyles = {
  'brouillon':           _BadgeStyle(bg: const Color(0xFFF3F4F6), fg: const Color(0xFF6B7280), label: 'Brouillon'),
  'envoyee':             _BadgeStyle(bg: LexSnTheme.infoBg,    fg: LexSnTheme.info,    label: 'Envoyée'),
  'partiellement_payee': _BadgeStyle(bg: LexSnTheme.warningBg, fg: LexSnTheme.warning, label: 'Partiel'),
  'payee':               _BadgeStyle(bg: LexSnTheme.successBg, fg: LexSnTheme.success, label: 'Payée'),
  'annulee':             _BadgeStyle(bg: LexSnTheme.dangerBg,  fg: LexSnTheme.danger,  label: 'Annulée'),
};

// ── AvatarInitiales ──────────────────────────────────────────────────────────

class AvatarInitiales extends StatelessWidget {
  final String initiales;
  final double size;
  final Color? bg;
  final Color? fg;

  const AvatarInitiales({
    super.key,
    required this.initiales,
    this.size = 40,
    this.bg,
    this.fg,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: bg ?? LexSnTheme.infoBg,
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Text(
        initiales.toUpperCase(),
        style: TextStyle(
          fontSize: size * 0.35,
          fontWeight: FontWeight.w600,
          color: fg ?? LexSnTheme.info,
        ),
      ),
    );
  }
}

// ── StatCard ─────────────────────────────────────────────────────────────────

class StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color iconBg;
  final Color iconColor;

  const StatCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    required this.iconBg,
    required this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: LexSnTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: LexSnTheme.border, width: 0.5),
      ),
      child: Row(children: [
        Container(
          width: 40, height: 40,
          decoration: BoxDecoration(color: iconBg, borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, color: iconColor, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFF9CA3AF))),
            const SizedBox(height: 2),
            Text(value, style: const TextStyle(
              fontSize: 18, fontWeight: FontWeight.w700, color: LexSnTheme.primary,
            )),
          ],
        )),
      ]),
    );
  }
}

// ── LoadingShimmer ───────────────────────────────────────────────────────────

class LexSnLoader extends StatelessWidget {
  const LexSnLoader({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: CircularProgressIndicator(
        color: LexSnTheme.primary,
        strokeWidth: 2.5,
      ),
    );
  }
}

// ── ErrorWidget ──────────────────────────────────────────────────────────────

class LexSnError extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;

  const LexSnError({super.key, required this.message, this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.wifi_off_outlined, size: 48, color: Color(0xFF9CA3AF)),
            const SizedBox(height: 16),
            Text(message, textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFF6B7280))),
            if (onRetry != null) ...[
              const SizedBox(height: 16),
              OutlinedButton(onPressed: onRetry, child: const Text('Réessayer')),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Section Title ────────────────────────────────────────────────────────────

class SectionTitle extends StatelessWidget {
  final String title;
  final Widget? trailing;

  const SectionTitle({super.key, required this.title, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title.toUpperCase(), style: const TextStyle(
            fontSize: 11, fontWeight: FontWeight.w700,
            letterSpacing: 0.6, color: Color(0xFF9CA3AF),
          )),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

// ── InfoRow ──────────────────────────────────────────────────────────────────

class InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isLast;

  const InfoRow({
    super.key,
    required this.label,
    required this.value,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        border: isLast ? null : const Border(
          bottom: BorderSide(color: LexSnTheme.border, width: 0.5),
        ),
      ),
      child: Row(children: [
        SizedBox(
          width: 120,
          child: Text(label, style: const TextStyle(
            fontSize: 13, color: Color(0xFF9CA3AF),
          )),
        ),
        Expanded(child: Text(value, style: const TextStyle(
          fontSize: 13, fontWeight: FontWeight.w500, color: LexSnTheme.primary,
        ))),
      ]),
    );
  }

  
}

