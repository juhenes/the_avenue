import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';

import '../models/event_record.dart';
import 'event_repository.dart';

class FirestoreEventRepository implements EventRepository {
  FirestoreEventRepository({FirebaseFirestore? firestore}) : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _events => _firestore.collection('events');

  Query<Map<String, dynamic>> get _publicEvents => _events.where('privacy', isEqualTo: EventPrivacy.public.name);

  Query<Map<String, dynamic>> _ownedEvents(String userId) => _events.where('ownerId', isEqualTo: userId);

  List<EventRecord> _mergeEvents(List<EventRecord> ownedEvents, List<EventRecord> publicEvents) {
    final eventsById = <String, EventRecord>{};

    for (final event in publicEvents) {
      eventsById[event.id] = event;
    }

    for (final event in ownedEvents) {
      eventsById[event.id] = event;
    }

    final events = eventsById.values.toList();
    events.sort((left, right) => left.celebrationDate.compareTo(right.celebrationDate));
    return events;
  }

  @override
  Future<void> deleteEvent(String eventId) async {
    await _events.doc(eventId).delete();
  }

  @override
  Future<List<EventRecord>> fetchEvents(String userId) async {
    final ownedSnapshot = await _ownedEvents(userId).get();
    final publicSnapshot = await _publicEvents.get();

    final ownedEvents = ownedSnapshot.docs
        .map((document) => EventRecord.fromJson({...document.data(), 'id': document.id}))
        .toList();
    final publicEvents = publicSnapshot.docs
        .map((document) => EventRecord.fromJson({...document.data(), 'id': document.id}))
        .toList();

    return _mergeEvents(ownedEvents, publicEvents);
  }

  @override
  Stream<List<EventRecord>> watchEvents(String userId) {
    late final StreamSubscription<QuerySnapshot<Map<String, dynamic>>> ownedSubscription;
    late final StreamSubscription<QuerySnapshot<Map<String, dynamic>>> publicSubscription;
    final controller = StreamController<List<EventRecord>>.broadcast();

    var ownedEvents = const <EventRecord>[];
    var publicEvents = const <EventRecord>[];

    void emit() {
      if (!controller.isClosed) {
        controller.add(_mergeEvents(ownedEvents, publicEvents));
      }
    }

    ownedSubscription = _ownedEvents(userId).snapshots().listen((snapshot) {
      ownedEvents = snapshot.docs
          .map((document) => EventRecord.fromJson({...document.data(), 'id': document.id}))
          .toList();
      emit();
    }, onError: controller.addError);

    publicSubscription = _publicEvents.snapshots().listen((snapshot) {
      publicEvents = snapshot.docs
          .map((document) => EventRecord.fromJson({...document.data(), 'id': document.id}))
          .toList();
      emit();
    }, onError: controller.addError);

    controller.onCancel = () async {
      await ownedSubscription.cancel();
      await publicSubscription.cancel();
      await controller.close();
    };

    return controller.stream;
  }

  @override
  Future<void> saveEvent(EventRecord event) async {
    await _events.doc(event.id).set(event.toJson(), SetOptions(merge: true));
  }
}
