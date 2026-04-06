import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:event_management_app/widgets/club_card.dart';
import 'package:flutter/material.dart';

class ClubScreen extends StatefulWidget {
  const ClubScreen({super.key});

  @override
  State<ClubScreen> createState() => _ClubScreenState();
}

class _ClubScreenState extends State<ClubScreen> {
  final _clubNameController = TextEditingController();
  final _searchController = TextEditingController();
  bool _isSaving = false;
  String _searchQuery = '';

  static const _pageBackgroundTop = Color(0xFFF8F3EE);
  static const _pageBackgroundBottom = Color(0xFFF6F1EB);
  static const _navy = Color(0xFF0D1B2E);
  static const _accent = Color(0xFFCB6D22);
  static const _muted = Color(0xFF7B6E63);
  static const _softBorder = Color(0xFFE8D5C4);
  static const _card = Colors.white;

  @override
  void dispose() {
    _clubNameController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _showClubDialog(
      {DocumentSnapshot<Map<String, dynamic>>? club}) async {
    final isEditing = club != null;
    _clubNameController.text = club?.data()?['name']?.toString() ?? '';
    String? validationMessage;

    await showDialog<void>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              title: Text(isEditing ? 'Update Club' : 'Add Club'),
              content: SizedBox(
                width: 380,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: _clubNameController,
                      textCapitalization: TextCapitalization.words,
                      decoration: InputDecoration(
                        labelText: 'Club name',
                        hintText: 'Enter club name',
                        errorText: validationMessage,
                        filled: true,
                        fillColor: const Color(0xFFFBF8F4),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(color: _softBorder),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(color: _softBorder),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide:
                              const BorderSide(color: _accent, width: 1.6),
                        ),
                      ),
                      onChanged: (_) {
                        if (validationMessage != null) {
                          setDialogState(() => validationMessage = null);
                        }
                      },
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Use a short, recognizable club name.',
                      style: TextStyle(fontSize: 12, color: _muted),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed:
                      _isSaving ? null : () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _accent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 18, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  onPressed: _isSaving
                      ? null
                      : () async {
                          final clubName = _clubNameController.text.trim();
                          if (clubName.isEmpty) {
                            setDialogState(
                              () =>
                                  validationMessage = 'Club name is required.',
                            );
                            return;
                          }

                          final wasSaved =
                              await _saveClub(clubName, club: club);
                          if (wasSaved && mounted) {
                            Navigator.of(this.context).pop();
                          }
                        },
                  child: _isSaving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(isEditing ? 'Update' : 'Create'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<bool> _saveClub(String clubName,
      {DocumentSnapshot<Map<String, dynamic>>? club}) async {
    setState(() {
      _isSaving = true;
    });

    try {
      final clubs = FirebaseFirestore.instance.collection('clubs');
      final normalizedName = clubName.toLowerCase();

      final duplicateSnapshot = await clubs
          .where('nameLower', isEqualTo: normalizedName)
          .limit(1)
          .get();

      if (duplicateSnapshot.docs.isNotEmpty &&
          (club == null || duplicateSnapshot.docs.first.id != club.id)) {
        if (!mounted) return false;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('A club with this name already exists.')),
        );
        return false;
      }

      if (club == null) {
        await clubs.add({
          'name': clubName,
          'nameLower': normalizedName,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
        if (!mounted) return false;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Club added successfully.')),
        );
      } else {
        await clubs.doc(club.id).update({
          'name': clubName,
          'nameLower': normalizedName,
          'updatedAt': FieldValue.serverTimestamp(),
        });
        if (!mounted) return false;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Club updated successfully.')),
        );
      }
      return true;
    } catch (_) {
      if (!mounted) return false;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to save club. Try again later.')),
      );
      return false;
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  Future<void> _deleteClub(DocumentSnapshot<Map<String, dynamic>> club) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          elevation: 8,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
          contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
          actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFECE6),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.warning_amber_rounded,
                    color: Color(0xFF9C2214), size: 24),
              ),
              const SizedBox(width: 16),
              const Text(
                'Delete Club',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0D1B2E),
                ),
              ),
            ],
          ),
          content: Text(
            'Are you sure you want to permanently delete "${club.data()?['name'] ?? 'this club'}"? This action cannot be undone and will affect future events.',
            style: const TextStyle(
              fontSize: 14,
              color: Color(0xFF7B6E63),
              height: 1.5,
              fontWeight: FontWeight.w500,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF7B6E63),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('Cancel',
                  style: TextStyle(fontWeight: FontWeight.w600)),
            ),
            const SizedBox(width: 4),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF9C2214),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('Delete',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            ),
          ],
        );
      },
    );

    if (confirm != true) return;

    try {
      await FirebaseFirestore.instance
          .collection('clubs')
          .doc(club.id)
          .delete();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Club deleted.')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to delete club.')),
      );
    }
  }

  Widget _buildSearchBar() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(
            color: Color(0x120D1B2E),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: TextField(
        controller: _searchController,
        onChanged: (value) => setState(() => _searchQuery = value.trim()),
        decoration: InputDecoration(
          prefixIcon: const Icon(Icons.search_rounded, color: _muted),
          hintText: 'Search clubs...',
          hintStyle: const TextStyle(color: _muted),
          suffixIcon: _searchQuery.isEmpty
              ? null
              : IconButton(
                  onPressed: () {
                    _searchController.clear();
                    setState(() => _searchQuery = '');
                  },
                  icon: const Icon(Icons.close_rounded, color: _muted),
                ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: const BorderSide(color: _softBorder),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: const BorderSide(color: _softBorder),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: const BorderSide(color: _accent, width: 1.5),
          ),
          filled: true,
          fillColor: _card,
          contentPadding: const EdgeInsets.symmetric(vertical: 14),
        ),
      ),
    );
  }

  Widget _buildHeaderAction({required int totalCount}) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _card,
        border: Border.all(color: _softBorder),
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(
            color: Color(0x120D1B2E),
            blurRadius: 20,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF2E7),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              '$totalCount clubs',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: _accent,
              ),
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Manage clubs for future events',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: _navy,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Create and maintain the official clubs list for event planning.',
            style: TextStyle(
              fontSize: 13,
              height: 1.5,
              color: _muted,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isSaving ? null : () => _showClubDialog(),
              icon: _isSaving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.add_rounded),
              label: Text(_isSaving ? 'Saving...' : 'Add Club'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _accent,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Clubs'),
        backgroundColor: _card,
        foregroundColor: _navy,
        centerTitle: true,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [_pageBackgroundTop, _pageBackgroundBottom],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('clubs')
              .orderBy('name')
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(color: Color(0xFFCB6D22)),
              );
            }

            if (snapshot.hasError) {
              return const Center(
                child: Text(
                  'Unable to load clubs right now.',
                  style: TextStyle(fontSize: 16, color: Colors.black54),
                ),
              );
            }

            final clubs = snapshot.data?.docs ?? [];
            final filteredClubs = _searchQuery.isEmpty
                ? clubs
                : clubs.where((club) {
                    final clubName =
                        club.data()['name']?.toString().toLowerCase() ?? '';
                    return clubName.contains(_searchQuery.toLowerCase());
                  }).toList();

            return ListView(
              padding: const EdgeInsets.only(bottom: 24),
              children: [
                _buildHeaderAction(totalCount: clubs.length),
                _buildSearchBar(),
                if (clubs.isEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 56, 24, 24),
                    child: Column(
                      children: [
                        Container(
                          width: 88,
                          height: 88,
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFF2E7),
                            borderRadius: BorderRadius.circular(28),
                          ),
                          child: const Icon(
                            Icons.groups_rounded,
                            size: 42,
                            color: _accent,
                          ),
                        ),
                        const SizedBox(height: 18),
                        const Text(
                          'No clubs found yet.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: _navy,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Create the first club from the Add Club button above.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14,
                            height: 1.5,
                            color: _muted,
                          ),
                        ),
                      ],
                    ),
                  )
                else if (filteredClubs.isEmpty)
                  const Padding(
                    padding: EdgeInsets.fromLTRB(24, 56, 24, 24),
                    child: Column(
                      children: [
                        Icon(Icons.search_off_rounded, size: 52, color: _muted),
                        SizedBox(height: 12),
                        Text(
                          'No clubs match your search.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: _navy,
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  ...filteredClubs.map(
                    (club) => ClubCard(
                      clubName:
                          club.data()['name']?.toString() ?? 'Untitled club',
                      onEdit: () => _showClubDialog(club: club),
                      onDelete: () => _deleteClub(club),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}
