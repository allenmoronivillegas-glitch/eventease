class EventItem {
  final String id;
  final String title;
  final String description;
  final String category;
  final String date;
  final String time;
  final String location;
  final bool isVirtual;
  final int totalCapacity;
  final int registeredCount;
  final int checkedInCount;
  final double ticketPrice;
  final String bannerImageUrl;
  final String status; // 'Upcoming', 'Live', 'Completed', 'Draft'
  final bool isPublished;

  EventItem({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    required this.date,
    required this.time,
    required this.location,
    this.isVirtual = false,
    required this.totalCapacity,
    required this.registeredCount,
    required this.checkedInCount,
    this.ticketPrice = 0.0,
    required this.bannerImageUrl,
    this.status = 'Upcoming',
    this.isPublished = false,
  });
}

class EventRegistration {
  final String eventId;
  final String organizerUid;
  final String attendeeUid;
  final DateTime registeredAt;

  const EventRegistration({
    required this.eventId,
    required this.organizerUid,
    required this.attendeeUid,
    required this.registeredAt,
  });
}

class AttendeeItem {
  final String id;
  final String eventId;
  final String name;
  final String email;
  final String phone;
  final String ticketType; // 'VIP', 'General', 'Speaker', 'Student'
  final String registeredDate;
  bool isCheckedIn;
  final String? checkInTime;

  AttendeeItem({
    required this.id,
    required this.eventId,
    required this.name,
    required this.email,
    required this.phone,
    required this.ticketType,
    required this.registeredDate,
    this.isCheckedIn = false,
    this.checkInTime,
  });
}

class ScheduleItem {
  final String id;
  final String eventId;
  final String time;
  final String title;
  final String speakerName;
  final String roomOrTrack;
  final String tag;

  ScheduleItem({
    required this.id,
    required this.eventId,
    required this.time,
    required this.title,
    required this.speakerName,
    required this.roomOrTrack,
    required this.tag,
  });
}

class AnnouncementItem {
  final String id;
  final String eventId;
  final String title;
  final String message;
  final String timestamp;
  final String priority; // 'Normal', 'Urgent', 'Update'
  final String sentTo; // 'All Attendees', 'VIP Only', 'Speakers'

  AnnouncementItem({
    required this.id,
    required this.eventId,
    required this.title,
    required this.message,
    required this.timestamp,
    this.priority = 'Normal',
    this.sentTo = 'All Attendees',
  });
}
