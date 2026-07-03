import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/announcement.dart';
import 'announcement_repository.dart';

class FirestoreAnnouncementRepository implements AnnouncementRepository {
  FirestoreAnnouncementRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _announcements => _firestore.collection('announcements');

  Query<Map<String, dynamic>> _scopedQuery({required bool includeArchived}) {
    // Non-admins MUST filter server-side via where(), not just in Dart,
    // otherwise the query is rejected outright by security rules.
    if (includeArchived) {
      return _announcements;
    }
    return _announcements.where('archived', isEqualTo: false);
  }

  List<Announcement> _sorted(List<Announcement> announcements) {
    announcements.sort((left, right) {
      if (left.archived != right.archived) {
        return left.archived ? 1 : -1;
      }
      final priorityComparison = right.priority.compareTo(left.priority);
      if (priorityComparison != 0) {
        return priorityComparison;
      }
      if (left.pinned != right.pinned) {
        return left.pinned ? -1 : 1;
      }
      return right.createdAt.compareTo(left.createdAt);
    });
    return announcements;
  }

  @override
  Future<List<Announcement>> fetchAnnouncements({required bool includeArchived}) async {
    final snapshot = await _scopedQuery(includeArchived: includeArchived).get();
    final announcements =
        snapshot.docs.map((document) => Announcement.fromJson({...document.data(), 'id': document.id})).toList();
    return _sorted(announcements);
  }

  @override
  Stream<List<Announcement>> watchAnnouncements({required bool includeArchived}) {
    return _scopedQuery(includeArchived: includeArchived).snapshots().map((snapshot) {
      final announcements =
          snapshot.docs.map((document) => Announcement.fromJson({...document.data(), 'id': document.id})).toList();
      return _sorted(announcements);
    });
  }

  @override
  Future<void> saveAnnouncement(Announcement announcement) async {
    await _announcements.doc(announcement.id).set(announcement.toJson());
  }

  @override
  Future<void> deleteAnnouncement(String id) async {
    await _announcements.doc(id).delete();
  }
}