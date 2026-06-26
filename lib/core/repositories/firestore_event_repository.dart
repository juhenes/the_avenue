import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/event_record.dart';
import 'event_repository.dart';

class FirestoreEventRepository implements EventRepository {
  FirestoreEventRepository({FirebaseFirestore? firestore}) : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _events => _firestore.collection('events');

  @override
  Future<void> deleteEvent(String eventId) async {
    await _events.doc(eventId).delete();
  }

  @override
  Future<List<EventRecord>> fetchEvents(String userId) async {
    final snapshot = await _events.get();
    final events = snapshot.docs
        .map((document) => EventRecord.fromJson({...document.data(), 'id': document.id}))
        .where((event) => event.ownerId == userId || event.privacy == EventPrivacy.public)
        .toList();

    events.sort((left, right) => left.celebrationDate.compareTo(right.celebrationDate));
    return events;
  }

  @override
  Stream<List<EventRecord>> watchEvents(String userId) {
    return _events.snapshots().map((snapshot) {
      final events = snapshot.docs
          .map((document) => EventRecord.fromJson({...document.data(), 'id': document.id}))
          .where((event) => event.ownerId == userId || event.privacy == EventPrivacy.public)
          .toList();
      events.sort((left, right) => left.celebrationDate.compareTo(right.celebrationDate));
      return events;
    });
  }

  @override
  Future<void> saveEvent(EventRecord event) async {
    await _events.doc(event.id).set(event.toJson(), SetOptions(merge: true));
  }
}
