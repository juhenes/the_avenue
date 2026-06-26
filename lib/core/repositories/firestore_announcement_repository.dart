import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/announcement.dart';
import 'announcement_repository.dart';

class FirestoreAnnouncementRepository implements AnnouncementRepository {
  FirestoreAnnouncementRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _announcements => _firestore.collection('announcements');

  @override
  Future<List<Announcement>> fetchAnnouncements() async {
    final snapshot = await _announcements.get();
    final announcements = snapshot.docs.map((document) => Announcement.fromJson({...document.data(), 'id': document.id})).toList();
    announcements.sort((left, right) {
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
  Stream<List<Announcement>> watchAnnouncements() {
    return _announcements.snapshots().map((snapshot) {
      final announcements = snapshot.docs.map((document) => Announcement.fromJson({...document.data(), 'id': document.id})).toList();
      announcements.sort((left, right) {
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
    });
  }
}
