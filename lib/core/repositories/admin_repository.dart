import '../models/admin_record.dart';

abstract class AdminRepository {
  Stream<List<AdminRecord>> watchAdmins();
  Future<List<AdminRecord>> fetchAdmins();
  Stream<AdminRecord?> watchAdminByEmail(String email);
  Future<AdminRecord?> fetchAdminByEmail(String email);
  Future<void> grantAdmin({required String email, required String createdBy});
  Future<void> revokeAdmin(String email);
}