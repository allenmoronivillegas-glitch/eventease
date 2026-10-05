import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/event_model.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Get all events
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
}