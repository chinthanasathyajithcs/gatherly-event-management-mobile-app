import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class ClubScreen extends StatefulWidget {
  const ClubScreen({super.key});

  @override
  State<ClubScreen> createState() => _ClubScreenState();
}

class _ClubScreenState extends State<ClubScreen> {
  final _clubNameController = TextEditingController();
  bool _isSaving = false;

  @override
  void dispose() {
    _clubNameController.dispose();
    super.dispose();
  }

  Future<void> _showClubDialog({DocumentSnapshot<Map<String, dynamic>>? club}) async {
    final isEditing = club != null;
    _clubNameController.text = club?.data()?['name']?.toString() ?? '';

    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(isEditing ? 'Update Club' : 'Add Club'),
          content: TextField(
            controller: _clubNameController,
            decoration: const InputDecoration(
              labelText: 'Club name',
              hintText: 'Enter club name',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final clubName = _clubNameController.text.trim();
                if (clubName.isEmpty) return;

                Navigator.of(context).pop();
                await _saveClub(clubName, club: club);
              },
              child: Text(isEditing ? 'Update' : 'Create'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _saveClub(String clubName, {DocumentSnapshot<Map<String, dynamic>>? club}) async {
    setState(() {
      _isSaving = true;
    });

    try {
      final clubs = FirebaseFirestore.instance.collection('clubs');
      if (club == null) {
        await clubs.add({'name': clubName});
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Club added successfully.')),
        );
      } else {
        await clubs.doc(club.id).update({'name': clubName});
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Club updated successfully.')),
        );
      }
    } catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to save club. Try again later.')),
      );
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
          title: const Text('Delete club'),
          content: Text('Delete "${club.data()?['name'] ?? 'this club'}"?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirm != true) return;

    try {
      await FirebaseFirestore.instance.collection('clubs').doc(club.id).delete();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Club deleted.')),
      );
    } catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to delete club.')),
      );
    }
  }

  Widget _buildClubCard(DocumentSnapshot<Map<String, dynamic>> club) {
    final clubName = club.data()?['name']?.toString() ?? 'Untitled club';

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      elevation: 3,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        title: Text(
          clubName,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          club.id,
          style: const TextStyle(fontSize: 13, color: Colors.black54),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.edit, color: Color(0xFFCB6D22)),
              onPressed: () => _showClubDialog(club: club),
            ),
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.redAccent),
              onPressed: () => _deleteClub(club),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Clubs'),
        centerTitle: true,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFF7F3EE), Color(0xFFF1E7D7)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance.collection('clubs').orderBy('name').snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator(color: Color(0xFFCB6D22)));
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
            if (clubs.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Icon(Icons.group, size: 68, color: Color(0xFFCB6D22)),
                      SizedBox(height: 18),
                      Text(
                        'No clubs found yet.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 18, color: Colors.black54),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Tap the plus button to add your first club.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 14, color: Colors.black45),
                      ),
                    ],
                  ),
                ),
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.only(bottom: 100, top: 12),
              itemCount: clubs.length,
              itemBuilder: (context, index) {
                return _buildClubCard(clubs[index]);
              },
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFFCB6D22),
        onPressed: () => _showClubDialog(),
        child: const Icon(Icons.add),
      ),
    );
  }
}
