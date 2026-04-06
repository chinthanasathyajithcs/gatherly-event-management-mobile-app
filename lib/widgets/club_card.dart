import 'package:flutter/material.dart';

class ClubCard extends StatelessWidget {
  const ClubCard({
    super.key,
    required this.clubName,
    required this.onEdit,
    required this.onDelete,
  });

  final String clubName;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  static const Color _navy = Color(0xFF0D1B2E);
  static const Color _accent = Color(0xFFCB6D22);
  static const Color _accentSoft = Color(0xFFF49B3B);

  @override
  Widget build(BuildContext context) {
    final leadingLetter = clubName.trim().isEmpty
        ? 'C'
        : clubName.trim().characters.first.toUpperCase();

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
            color: Color(0x140D1B2E),
            blurRadius: 16,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [_accent, _accentSoft],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Center(
              child: Text(
                leadingLetter,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 18,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              clubName,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: _navy,
              ),
            ),
          ),
          IconButton(
            tooltip: 'Edit club',
            icon: const Icon(Icons.edit_rounded, color: _accent),
            onPressed: onEdit,
          ),
          IconButton(
            tooltip: 'Delete club',
            icon: const Icon(
              Icons.delete_outline_rounded,
              color: Color(0xFFB85C1E),
            ),
            onPressed: onDelete,
          ),
        ],
      ),
    );
  }
}
