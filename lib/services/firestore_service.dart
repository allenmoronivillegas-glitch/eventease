import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/event_model.dart';

class FirestoreService {
  FirestoreService({FirebaseFirestore? firestore, FirebaseAuth? auth})
    : _db = firestore ?? FirebaseFirestore.instance,
      _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _db;
  final FirebaseAuth _auth;

  String get _uid {
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      throw FirebaseAuthException(
        code: 'unauthenticated',
        message: 'Sign in to manage your event data.',
      );
    }
    return uid;
  }

  // EVENTS

  Stream<List<EventItem>> getEvents() {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return Stream.value(const []);
    return _db
        .collection('events')
        .where('ownerUid', isEqualTo: uid)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => _eventFromData(doc.id, doc.data()))
              .toList(),
        );
  }

  Future<void> createEvent(EventItem event) async {
    final uid = _uid;
    final eventRef = _db.collection('events').doc(event.id);
    await _db.runTransaction((transaction) async {
      if ((await transaction.get(eventRef)).exists) {
        throw StateError('An event with this ID already exists.');
      }
      transaction.set(eventRef, {..._eventData(event), 'ownerUid': uid});
    });
  }

  Future<void> deleteEvent(String eventId) async {
    final uid = _uid;
    final eventRef = _db.collection('events').doc(eventId);
    final eventSnapshot = await eventRef.get();
    if (!eventSnapshot.exists || eventSnapshot.data()?['ownerUid'] != uid) {
      throw StateError('The event does not exist or is not owned by you.');
    }

    const relatedCollections = ['attendees', 'schedules', 'announcements'];
    for (final collectionName in relatedCollections) {
      final collection = _db.collection(collectionName);
      while (true) {
        final snapshot = await collection
            .where('eventId', isEqualTo: eventId)
            .where('ownerUid', isEqualTo: uid)
            .limit(450)
            .get();
        if (snapshot.docs.isEmpty) break;

        final batch = _db.batch();
        for (final document in snapshot.docs) {
          batch.delete(document.reference);
        }
        await batch.commit();
      }
    }

    for (final collectionName in relatedCollections) {
      final remaining = await _db
          .collection(collectionName)
          .where('eventId', isEqualTo: eventId)
          .where('ownerUid', isEqualTo: uid)
          .limit(1)
          .get();
      if (remaining.docs.isNotEmpty) {
        throw StateError(
          'Some related $collectionName records remain. The event was kept; '
          'retry the deletion after resolving the issue.',
        );
      }
    }

    await _db.runTransaction((transaction) async {
      final currentEvent = await transaction.get(eventRef);
      if (!currentEvent.exists || currentEvent.data()?['ownerUid'] != uid) {
        throw StateError('The event no longer belongs to this account.');
      }
      transaction.delete(eventRef);
    });
  }

  // ATTENDEES

  Stream<List<AttendeeItem>> getAttendees() {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return Stream.value(const []);
    return _db
        .collection('attendees')
        .where('ownerUid', isEqualTo: uid)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => _attendeeFromData(doc.id, doc.data()))
              .toList(),
        );
  }

  Future<void> createAttendee(AttendeeItem attendee) async {
    final uid = _uid;
    final attendeeRef = _db.collection('attendees').doc(attendee.id);
    final eventRef = _db.collection('events').doc(attendee.eventId);

    await _db.runTransaction((transaction) async {
      final eventSnapshot = await transaction.get(eventRef);
      _requireOwnedEvent(eventSnapshot, uid);
      if ((await transaction.get(attendeeRef)).exists) {
        throw StateError('An attendee with this ID already exists.');
      }
      transaction.set(attendeeRef, {
        'ownerUid': uid,
        'eventId': attendee.eventId,
        'name': attendee.name,
        'email': attendee.email,
        'phone': attendee.phone,
        'ticketType': attendee.ticketType,
        'registeredDate': attendee.registeredDate,
        'isCheckedIn': attendee.isCheckedIn,
        'checkInTime': attendee.checkInTime,
      });
      final currentCount =
          (eventSnapshot.data()?['registeredCount'] as num?)?.toInt() ?? 0;
      transaction.update(eventRef, {'registeredCount': currentCount + 1});
    });
  }

  Future<void> deleteAttendee(String attendeeId) async {
    final uid = _uid;
    final attendeeRef = _db.collection('attendees').doc(attendeeId);

    await _db.runTransaction((transaction) async {
      final attendeeSnapshot = await transaction.get(attendeeRef);
      if (!attendeeSnapshot.exists ||
          attendeeSnapshot.data()?['ownerUid'] != uid) {
        throw StateError(
          'This attendee does not exist or is not owned by you.',
        );
      }

      final attendeeData = attendeeSnapshot.data()!;
      final eventId = attendeeData['eventId'] as String? ?? '';
      if (eventId.isEmpty) {
        throw StateError('This attendee has no valid parent event.');
      }
      final eventRef = _db.collection('events').doc(eventId);
      final eventSnapshot = await transaction.get(eventRef);
      _requireOwnedEvent(eventSnapshot, uid);

      final eventData = eventSnapshot.data()!;
      final registeredCount =
          (eventData['registeredCount'] as num?)?.toInt() ?? 0;
      final updates = <String, Object>{
        'registeredCount': registeredCount > 0 ? registeredCount - 1 : 0,
      };
      if (attendeeData['isCheckedIn'] == true) {
        final checkedInCount =
            (eventData['checkedInCount'] as num?)?.toInt() ?? 0;
        updates['checkedInCount'] = checkedInCount > 0 ? checkedInCount - 1 : 0;
      }
      transaction.update(eventRef, updates);
      transaction.delete(attendeeRef);
    });
  }

  Future<void> updateAttendeeCheckIn(
    AttendeeItem attendee,
    bool isCheckedIn,
  ) async {
    final uid = _uid;
    String? checkInTime;
    if (isCheckedIn) {
      final now = DateTime.now();
      final hour = now.hour > 12
          ? now.hour - 12
          : (now.hour == 0 ? 12 : now.hour);
      final minute = now.minute.toString().padLeft(2, '0');
      final period = now.hour >= 12 ? 'PM' : 'AM';
      checkInTime = '$hour:$minute $period';
    }

    final attendeeRef = _db.collection('attendees').doc(attendee.id);
    await _db.runTransaction((transaction) async {
      final attendeeSnapshot = await transaction.get(attendeeRef);
      if (!attendeeSnapshot.exists ||
          attendeeSnapshot.data()?['ownerUid'] != uid) {
        throw StateError(
          'This attendee does not exist or is not owned by you.',
        );
      }

      final attendeeData = attendeeSnapshot.data()!;
      final eventId = attendeeData['eventId'] as String? ?? '';
      if (eventId.isEmpty) {
        throw StateError('This attendee has no valid parent event.');
      }
      final eventRef = _db.collection('events').doc(eventId);
      final eventSnapshot = await transaction.get(eventRef);
      _requireOwnedEvent(eventSnapshot, uid);

      final wasCheckedIn = attendeeData['isCheckedIn'] == true;
      if (wasCheckedIn != isCheckedIn) {
        final currentCount =
            (eventSnapshot.data()?['checkedInCount'] as num?)?.toInt() ?? 0;
        transaction.update(eventRef, {
          'checkedInCount': isCheckedIn
              ? currentCount + 1
              : (currentCount > 0 ? currentCount - 1 : 0),
        });
      }
      transaction.update(attendeeRef, {
        'isCheckedIn': isCheckedIn,
        'checkInTime': checkInTime,
      });
    });
  }

  // SCHEDULES

  Stream<List<ScheduleItem>> getSchedules() {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return Stream.value(const []);
    return _db
        .collection('schedules')
        .where('ownerUid', isEqualTo: uid)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => _scheduleFromData(doc.id, doc.data()))
              .toList(),
        );
  }

  Future<void> createSchedule(ScheduleItem schedule) async {
    final uid = _uid;
    final scheduleRef = _db.collection('schedules').doc(schedule.id);
    final eventRef = _db.collection('events').doc(schedule.eventId);
    await _db.runTransaction((transaction) async {
      _requireOwnedEvent(await transaction.get(eventRef), uid);
      if ((await transaction.get(scheduleRef)).exists) {
        throw StateError('A schedule item with this ID already exists.');
      }
      transaction.set(scheduleRef, {
        'ownerUid': uid,
        'eventId': schedule.eventId,
        'time': schedule.time,
        'title': schedule.title,
        'speakerName': schedule.speakerName,
        'roomOrTrack': schedule.roomOrTrack,
        'tag': schedule.tag,
      });
    });
  }

  Future<void> deleteSchedule(String scheduleId) async {
    await _deleteOwnedChild(
      collectionName: 'schedules',
      documentId: scheduleId,
    );
  }

  // ANNOUNCEMENTS

  Stream<List<AnnouncementItem>> getAnnouncements() {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return Stream.value(const []);
    return _db
        .collection('announcements')
        .where('ownerUid', isEqualTo: uid)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => _announcementFromData(doc.id, doc.data()))
              .toList(),
        );
  }

  Future<void> createAnnouncement(AnnouncementItem announcement) async {
    final uid = _uid;
    final announcementRef = _db
        .collection('announcements')
        .doc(announcement.id);
    final eventRef = _db.collection('events').doc(announcement.eventId);
    await _db.runTransaction((transaction) async {
      _requireOwnedEvent(await transaction.get(eventRef), uid);
      if ((await transaction.get(announcementRef)).exists) {
        throw StateError('An announcement with this ID already exists.');
      }
      transaction.set(announcementRef, {
        'ownerUid': uid,
        'eventId': announcement.eventId,
        'title': announcement.title,
        'message': announcement.message,
        'timestamp': announcement.timestamp,
        'priority': announcement.priority,
        'sentTo': announcement.sentTo,
      });
    });
  }

  Future<void> deleteAnnouncement(String announcementId) async {
    await _deleteOwnedChild(
      collectionName: 'announcements',
      documentId: announcementId,
    );
  }

  Future<void> _deleteOwnedChild({
    required String collectionName,
    required String documentId,
  }) async {
    final uid = _uid;
    final childRef = _db.collection(collectionName).doc(documentId);
    await _db.runTransaction((transaction) async {
      final childSnapshot = await transaction.get(childRef);
      if (!childSnapshot.exists || childSnapshot.data()?['ownerUid'] != uid) {
        throw StateError('This record does not exist or is not owned by you.');
      }
      final eventId = childSnapshot.data()?['eventId'] as String? ?? '';
      if (eventId.isEmpty) {
        throw StateError('This record has no valid parent event.');
      }
      _requireOwnedEvent(
        await transaction.get(_db.collection('events').doc(eventId)),
        uid,
      );
      transaction.delete(childRef);
    });
  }

  void _requireOwnedEvent(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
    String uid,
  ) {
    if (!snapshot.exists || snapshot.data()?['ownerUid'] != uid) {
      throw StateError(
        'The parent event does not exist or is not owned by you.',
      );
    }
  }

  EventItem _eventFromData(String id, Map<String, dynamic> data) {
    return EventItem(
      id: id,
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      category: data['category'] ?? '',
      date: data['date'] ?? '',
      time: data['time'] ?? '',
      location: data['location'] ?? '',
      isVirtual: data['isVirtual'] ?? false,
      totalCapacity: data['totalCapacity'] ?? 0,
      registeredCount: data['registeredCount'] ?? 0,
      checkedInCount: data['checkedInCount'] ?? 0,
      ticketPrice: (data['ticketPrice'] ?? 0).toDouble(),
      bannerImageUrl: data['bannerImageUrl'] ?? '',
      status: data['status'] ?? 'Upcoming',
    );
  }

  Map<String, Object> _eventData(EventItem event) => {
    'title': event.title,
    'description': event.description,
    'category': event.category,
    'date': event.date,
    'time': event.time,
    'location': event.location,
    'isVirtual': event.isVirtual,
    'totalCapacity': event.totalCapacity,
    'registeredCount': event.registeredCount,
    'checkedInCount': event.checkedInCount,
    'ticketPrice': event.ticketPrice,
    'bannerImageUrl': event.bannerImageUrl,
    'status': event.status,
  };

  AttendeeItem _attendeeFromData(String id, Map<String, dynamic> data) {
    return AttendeeItem(
      id: id,
      eventId: data['eventId'] ?? '',
      name: data['name'] ?? '',
      email: data['email'] ?? '',
      phone: data['phone'] ?? '',
      ticketType: data['ticketType'] ?? 'General',
      registeredDate: data['registeredDate'] ?? '',
      isCheckedIn: data['isCheckedIn'] ?? false,
      checkInTime: data['checkInTime'],
    );
  }

  ScheduleItem _scheduleFromData(String id, Map<String, dynamic> data) {
    return ScheduleItem(
      id: id,
      eventId: data['eventId'] ?? '',
      time: data['time'] ?? '',
      title: data['title'] ?? '',
      speakerName: data['speakerName'] ?? '',
      roomOrTrack: data['roomOrTrack'] ?? '',
      tag: data['tag'] ?? '',
    );
  }

  AnnouncementItem _announcementFromData(String id, Map<String, dynamic> data) {
    return AnnouncementItem(
      id: id,
      eventId: data['eventId'] ?? '',
      title: data['title'] ?? '',
      message: data['message'] ?? '',
      timestamp: data['timestamp'] ?? '',
      priority: data['priority'] ?? 'Normal',
      sentTo: data['sentTo'] ?? 'All Attendees',
    );
  }
}
