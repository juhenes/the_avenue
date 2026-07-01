import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/admin_record.dart';
import 'admin_repository.dart';

class FirestoreAdminRepository implements AdminRepository {
  FirestoreAdminRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _admins => _firestore.collection('admins');

  List<AdminRecord> _sortAdmins(List<AdminRecord> admins) {
    admins.sort((left, right) => right.createdAt.compareTo(left.createdAt));
    return admins;
  }

  @override
  Future<List<AdminRecord>> fetchAdmins() async {
    final snapshot = await _admins.get();
    final admins = snapshot.docs
        .map((document) => AdminRecord.fromJson({...document.data(), 'id': document.id}))
        .toList();
    return _sortAdmins(admins);
  }

  @override
  Future<AdminRecord?> fetchAdminByEmail(String email) async {
    final normalizedEmail = email.trim().toLowerCase();
    final document = await _admins.doc(normalizedEmail).get();

    if (!document.exists || document.data() == null) {
      return null;
    }

    return AdminRecord.fromJson({...document.data()!, 'id': document.id});
  }

  @override
  Stream<List<AdminRecord>> watchAdmins() {
    return _admins.snapshots().map((snapshot) {
      final admins = snapshot.docs
          .map((document) => AdminRecord.fromJson({...document.data(), 'id': document.id}))
          .toList();
      return _sortAdmins(admins);
    });
  }

  @override
  Stream<AdminRecord?> watchAdminByEmail(String email) {
    final normalizedEmail = email.trim().toLowerCase();

    return _admins.doc(normalizedEmail).snapshots().map((document) {
      if (!document.exists || document.data() == null) {
        return null;
      }

      return AdminRecord.fromJson({...document.data()!, 'id': document.id});
    });
  }

  @override
  Future<void> grantAdmin({required String email, required String createdBy}) async {
    final normalizedEmail = email.trim().toLowerCase();

    await _admins.doc(normalizedEmail).set({
      'email': normalizedEmail,
      'createdAt': DateTime.now().toIso8601String(),
      'createdBy': createdBy,
    });
  }

  @override
  Future<void> revokeAdmin(String email) async {
    await _admins.doc(email.trim().toLowerCase()).delete();
  }
}