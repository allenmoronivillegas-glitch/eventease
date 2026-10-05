import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/event_model.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ============================================================
  // EVENTS
  // ============================================================

  // Get all events from Firestore
  Stream<List<EventItem>> getEvents() {
    return _db.collection('events').snapshots().map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();

        return EventItem(
          id: doc.id,
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
      }).toList();
    });
  }

  // Create an event
  Future<void> createEvent(EventItem event) async {
    await _db.collection('events').doc(event.id).set({
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
    });
  }

  // ============================================================
  // ATTENDEES
  // ============================================================

  // Get all attendees from Firestore
  Stream<List<AttendeeItem>> getAttendees() {
    return _db.collection('attendees').snapshots().map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();

        return AttendeeItem(
          id: doc.id,
          eventId: data['eventId'] ?? '',
          name: data['name'] ?? '',
          email: data['email'] ?? '',
          phone: data['phone'] ?? '',
          ticketType: data['ticketType'] ?? 'General',
          registeredDate: data['registeredDate'] ?? '',
          isCheckedIn: data['isCheckedIn'] ?? false,
          checkInTime: data['checkInTime'],
        );
      }).toList();
    });
  }

  // Create an attendee
  Future<void> createAttendee(AttendeeItem attendee) async {
    await _db.collection('attendees').doc(attendee.id).set({
      'eventId': attendee.eventId,
      'name': attendee.name,
      'email': attendee.email,
      'phone': attendee.phone,
      'ticketType': attendee.ticketType,
      'registeredDate': attendee.registeredDate,
      'isCheckedIn': attendee.isCheckedIn,
      'checkInTime': attendee.checkInTime,
    });

    // Increase the registered attendee count
    // for the associated event.
    final eventRef = _db.collection('events').doc(attendee.eventId);

    await _db.runTransaction((transaction) async {
      final snapshot = await transaction.get(eventRef);

      if (!snapshot.exists) {
        return;
      }

      final data = snapshot.data();

      final currentCount =
      (data?['registeredCount'] ?? 0) as num;

      transaction.update(eventRef, {
        'registeredCount': currentCount.toInt() + 1,
      });
    });
  }

  // Update attendee check-in status
  Future<void> updateAttendeeCheckIn(
      AttendeeItem attendee,
      bool isCheckedIn,
      ) async {
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

    await _db.collection('attendees').doc(attendee.id).update({
      'isCheckedIn': isCheckedIn,
      'checkInTime': checkInTime,
    });

    // Update the checked-in count on the event.
    final eventRef = _db.collection('events').doc(attendee.eventId);

    await _db.runTransaction((transaction) async {
      final snapshot = await transaction.get(eventRef);

      if (!snapshot.exists) {
        return;
      }

      final data = snapshot.data();

      final currentCount =
      (data?['checkedInCount'] ?? 0) as num;

      final newCount = isCheckedIn
          ? currentCount.toInt() + 1
          : (currentCount.toInt() - 1).clamp(0, 999999);

      transaction.update(eventRef, {
        'checkedInCount': newCount,
      });
    });
  }

  // ============================================================
  // SCHEDULES
  // ============================================================

  // Get all schedules from Firestore
  Stream<List<ScheduleItem>> getSchedules() {
    return _db.collection('schedules').snapshots().map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();

        return ScheduleItem(
          id: doc.id,
          eventId: data['eventId'] ?? '',
          time: data['time'] ?? '',
          title: data['title'] ?? '',
          speakerName: data['speakerName'] ?? '',
          roomOrTrack: data['roomOrTrack'] ?? '',
          tag: data['tag'] ?? '',
        );
      }).toList();
    });
  }

  // Create a schedule session
  Future<void> createSchedule(ScheduleItem schedule) async {
    await _db.collection('schedules').doc(schedule.id).set({
      'eventId': schedule.eventId,
      'time': schedule.time,
      'title': schedule.title,
      'speakerName': schedule.speakerName,
      'roomOrTrack': schedule.roomOrTrack,
      'tag': schedule.tag,
    });
  }

  // ============================================================
  // ANNOUNCEMENTS
  // ============================================================

  // Get all announcements from Firestore
  Stream<List<AnnouncementItem>> getAnnouncements() {
    return _db
        .collection('announcements')
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();

        return AnnouncementItem(
          id: doc.id,
          eventId: data['eventId'] ?? '',
          title: data['title'] ?? '',
          message: data['message'] ?? '',
          timestamp: data['timestamp'] ?? '',
          priority: data['priority'] ?? 'Normal',
          sentTo: data['sentTo'] ?? 'All Attendees',
        );
      }).toList();
    });
  }

  // Create an announcement
  Future<void> createAnnouncement(
      AnnouncementItem announcement,
      ) async {
    await _db
        .collection('announcements')
        .doc(announcement.id)
        .set({
      'eventId': announcement.eventId,
      'title': announcement.title,
      'message': announcement.message,
      'timestamp': announcement.timestamp,
      'priority': announcement.priority,
      'sentTo': announcement.sentTo,
    });
  }
}