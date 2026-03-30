class UserModel {
  final String uid;
  final String email;
  final String role; // 'admin' or 'student'
  final String? name;
  final String? studentId;
  final String? department;
  final String? photoUrl;

  UserModel({
    required this.uid,
    required this.email,
    required this.role,
    this.name,
    this.studentId,
    this.department,
    this.photoUrl,
  });

  // Convert Firestore document to UserModel
  factory UserModel.fromMap(Map<String, dynamic> map, String uid) {
    return UserModel(
      uid: uid,
      email: map['email'] ?? '',
      role: map['role'] ?? 'student',
      name: map['name'],
      studentId: map['studentId'],
      department: map['department'],
      photoUrl: map['photoUrl'],
    );
  }

  // Convert UserModel to Firestore document
  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'email': email,
      'role': role,
      'name': name,
      'studentId': studentId,
      'department': department,
      'photoUrl': photoUrl,
      'createdAt': DateTime.now().toIso8601String(),
    };
  }
}
