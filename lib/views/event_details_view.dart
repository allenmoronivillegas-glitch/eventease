import 'package:flutter/material.dart';

import '../models/event_model.dart';
import '../services/firestore_service.dart';
import '../theme/app_theme.dart';
import 'register_attendee_dialog.dart';
import 'send_announcement_dialog.dart';

class EventDetailsView extends StatefulWidget {
  final String eventId;
  final List<EventItem> events;
  final List<AttendeeItem> attendees;
  final List<ScheduleItem> schedules;
  final List<AnnouncementItem> announcements;
  final Function(AttendeeItem) onAttendeeRegistered;
  final Function(AttendeeItem) onAttendeeCheckInToggled;
  final VoidCallback onDataChanged;

  const EventDetailsView({
    super.key,
    required this.eventId,
    required this.events,
    required this.attendees,
    required this.schedules,
    required this.announcements,
    required this.onAttendeeRegistered,
    required this.onAttendeeCheckInToggled,
    required this.onDataChanged,
  });

  @override
  State<EventDetailsView> createState() => _EventDetailsViewState();
}

class _EventDetailsViewState extends State<EventDetailsView>
    with SingleTickerProviderStateMixin {
  final FirestoreService _firestoreService = FirestoreService();
  late TabController _tabController;
  String _attendeeSearchQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  EventItem get _currentEvent =>
      widget.events.firstWhere((e) => e.id == widget.eventId);

  void _openCheckInDialog() {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Icon(Icons.qr_code_scanner_rounded, color: AppTheme.primary),
              SizedBox(width: 10),
              Text('Quick Badge / QR Check-In'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 180,
                height: 180,
                decoration: BoxDecoration(
                  color: AppTheme.background,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppTheme.cardBorder, width: 2),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.qr_code_2_rounded,
                      size: 100,
                      color: AppTheme.primaryDark,
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Ready to Scan Pass',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Hold attendee QR badge in front of camera or select attendee directly in Attendee tab.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
              ),
            ],
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Close Scanner'),
            ),
          ],
        );
      },
    );
  }

  void _addNewScheduleItem() {
    final titleCtrl = TextEditingController();
    final timeCtrl = TextEditingController(text: '02:00 PM - 03:00 PM');
    final speakerCtrl = TextEditingController();
    final roomCtrl = TextEditingController(text: 'Room A');
    final tagCtrl = TextEditingController(text: 'Session');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Add Schedule Item'),
        content: SingleChildScrollView(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Session Title *',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: timeCtrl,
                  decoration: const InputDecoration(labelText: 'Time Slot *'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: speakerCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Speaker / Facilitator',
                  ),
                ),
                const SizedBox(height: 12),
                LayoutBuilder(
                  builder: (context, constraints) {
                    if (constraints.maxWidth < 300) {
                      return Column(
                        children: [
                          TextField(
                            controller: roomCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Track / Room',
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: tagCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Category Tag',
                            ),
                          ),
                        ],
                      );
                    }
                    return Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: roomCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Track / Room',
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: tagCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Category Tag',
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final title = titleCtrl.text.trim();
              if (title.isEmpty) return;
              final schedule = ScheduleItem(
                id: 'SCH-${DateTime.now().millisecondsSinceEpoch}',
                eventId: widget.eventId,
                time: timeCtrl.text.trim(),
                title: title,
                speakerName: speakerCtrl.text.trim().isEmpty
                    ? 'TBA'
                    : speakerCtrl.text.trim(),
                roomOrTrack: roomCtrl.text.trim().isEmpty
                    ? 'Main Hall'
                    : roomCtrl.text.trim(),
                tag: tagCtrl.text.trim().isEmpty
                    ? 'General'
                    : tagCtrl.text.trim(),
              );
              try {
                await _firestoreService.createSchedule(schedule);
                if (!ctx.mounted || !mounted) return;
                Navigator.of(ctx).pop();
                widget.onDataChanged();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Schedule item saved successfully.'),
                  ),
                );
              } catch (error) {
                if (!ctx.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Could not save schedule item: $error'),
                  ),
                );
              }
            },
            child: const Text('Add Item'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final event = _currentEvent;

    final eventAttendees = widget.attendees
        .where((a) => a.eventId == event.id)
        .toList();
    final eventSchedules = widget.schedules
        .where((s) => s.eventId == event.id)
        .toList();
    final eventAnnouncements = widget.announcements
        .where((a) => a.eventId == event.id)
        .toList();

    final filteredAttendees = eventAttendees.where((a) {
      final query = _attendeeSearchQuery.toLowerCase();
      return a.name.toLowerCase().contains(query) ||
          a.email.toLowerCase().contains(query) ||
          a.ticketType.toLowerCase().contains(query);
    }).toList();

    final checkInRate = event.registeredCount > 0
        ? (event.checkedInCount / event.registeredCount * 100).toInt()
        : 0;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text(
          event.title,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        actions: [
          IconButton(
            tooltip: 'Live Check-In Scanner',
            icon: Icon(Icons.qr_code_scanner_rounded, color: AppTheme.primary),
            onPressed: _openCheckInDialog,
          ),
          IconButton(
            tooltip: 'Broadcast Announcement',
            icon: Icon(Icons.campaign_rounded, color: AppTheme.accent),
            onPressed: () {
              showDialog(
                context: context,
                builder: (ctx) => SendAnnouncementDialog(
                  events: [event],
                  initialEventId: event.id,
                  onAnnouncementSent: (announcement) {
                    widget.announcements.insert(0, announcement);
                    widget.onDataChanged();
                    setState(() {});
                  },
                ),
              );
            },
          ),
          IconButton(
            tooltip: 'Register Attendee',
            icon: Icon(Icons.person_add_alt_1_rounded, color: AppTheme.success),
            onPressed: () {
              showDialog(
                context: context,
                builder: (ctx) => RegisterAttendeeDialog(
                  events: [event],
                  initialEventId: event.id,
                  onAttendeeRegistered: (attendee) {
                    widget.onAttendeeRegistered(attendee);
                    setState(() {});
                  },
                ),
              );
            },
          ),
          const SizedBox(width: 8),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppTheme.primary,
          unselectedLabelColor: AppTheme.textSecondary,
          indicatorColor: AppTheme.primary,
          indicatorWeight: 3,
          isScrollable: true,
          tabs: [
            Tab(
              icon: const Icon(Icons.dashboard_outlined, size: 20),
              text: 'Overview',
            ),
            Tab(
              icon: const Icon(Icons.people_outline, size: 20),
              text: 'Attendees (${eventAttendees.length})',
            ),
            Tab(
              icon: const Icon(Icons.schedule_outlined, size: 20),
              text: 'Schedule (${eventSchedules.length})',
            ),
            Tab(
              icon: const Icon(Icons.notifications_outlined, size: 20),
              text: 'Broadcasts (${eventAnnouncements.length})',
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // 1. OVERVIEW TAB
          _buildOverviewTab(event, checkInRate, eventAttendees, eventSchedules),

          // 2. ATTENDEES TAB (with check-in capability)
          _buildAttendeesTab(event, filteredAttendees),

          // 3. SCHEDULE TAB
          _buildScheduleTab(eventSchedules),

          // 4. ANNOUNCEMENTS TAB
          _buildAnnouncementsTab(eventAnnouncements),
        ],
      ),
    );
  }

  Widget _buildOverviewTab(
    EventItem event,
    int checkInRate,
    List<AttendeeItem> attendees,
    List<ScheduleItem> schedules,
  ) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Hero Banner
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [AppTheme.primaryDark, AppTheme.primary],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.primary.withValues(alpha: 0.25),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 10,
                  runSpacing: 8,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        event.category.toUpperCase(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: event.status == 'Live'
                            ? AppTheme.success
                            : Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (event.status == 'Live')
                            Container(
                              width: 8,
                              height: 8,
                              margin: const EdgeInsets.only(right: 6),
                              decoration: const BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                              ),
                            ),
                          Text(
                            event.status,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  event.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  event.description,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontSize: 14,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 20),
                Wrap(
                  spacing: 24,
                  runSpacing: 12,
                  children: [
                    _infoBadge(Icons.calendar_today, event.date),
                    _infoBadge(Icons.access_time, event.time),
                    _infoBadge(Icons.location_on_outlined, event.location),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Real-time Event Metrics
          const Text(
            'Live Event Metrics',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth > 700;
              final isNarrow = constraints.maxWidth < 450;
              final crossCount = isWide ? 4 : (isNarrow ? 1 : 2);

              return GridView.count(
                crossAxisCount: crossCount,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                childAspectRatio: isNarrow ? 3.8 : 1.3,
                children: [
                  _metricCard(
                    'Total Capacity',
                    '${event.totalCapacity}',
                    Icons.airline_seat_recline_normal,
                    AppTheme.textSecondary,
                  ),
                  _metricCard(
                    'Registered',
                    '${event.registeredCount}',
                    Icons.how_to_reg,
                    AppTheme.primary,
                  ),
                  _metricCard(
                    'Checked-In',
                    '${event.checkedInCount}',
                    Icons.check_circle_outline,
                    AppTheme.success,
                  ),
                  _metricCard(
                    'Check-in Rate',
                    '$checkInRate%',
                    Icons.insights,
                    AppTheme.accent,
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 28),

          // Capacity & Progress Indicator Card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.cardBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  spacing: 12,
                  runSpacing: 8,
                  children: [
                    const Text(
                      'Attendance & Venue Capacity Fulfillment',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    Text(
                      '${event.registeredCount} / ${event.totalCapacity} (${(event.registeredCount / event.totalCapacity * 100).toInt()}%)',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: AppTheme.primary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: event.registeredCount / event.totalCapacity,
                    minHeight: 12,
                    backgroundColor: AppTheme.cardBorder,
                    valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primary),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        '${event.totalCapacity - event.registeredCount} spots remaining',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppTheme.textSecondary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      '${event.checkedInCount} checked-in',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.success,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoBadge(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: Colors.white70),
        const SizedBox(width: 8),
        Text(text, style: const TextStyle(color: Colors.white, fontSize: 13)),
      ],
    );
  }

  Widget _metricCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAttendeesTab(EventItem event, List<AttendeeItem> attendees) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  decoration: const InputDecoration(
                    hintText: 'Search attendee...',
                    prefixIcon: Icon(Icons.search, size: 20),
                  ),
                  onChanged: (val) =>
                      setState(() => _attendeeSearchQuery = val),
                ),
              ),
              const SizedBox(width: 14),
              ElevatedButton(
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (ctx) => RegisterAttendeeDialog(
                      events: [event],
                      initialEventId: event.id,
                      onAttendeeRegistered: (attendee) {
                        widget.onAttendeeRegistered(attendee);
                        setState(() {});
                      },
                    ),
                  );
                },
                child: const Icon(Icons.add, size: 18),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: attendees.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.person_search_outlined,
                          size: 64,
                          color: AppTheme.textMuted,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'No attendees found',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.separated(
                    itemCount: attendees.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final att = attendees[index];
                      return Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppTheme.surface,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppTheme.cardBorder),
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              backgroundColor: AppTheme.primaryLight,
                              foregroundColor: AppTheme.primary,
                              child: Text(
                                att.name.isNotEmpty ? att.name[0] : '?',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          att.name,
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 15,
                                            color: AppTheme.textPrimary,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: att.ticketType == 'VIP'
                                              ? const Color(0xFFFEF3C7)
                                              : att.ticketType == 'Speaker'
                                              ? const Color(0xFFEDE9FE)
                                              : AppTheme.background,
                                          borderRadius: BorderRadius.circular(
                                            6,
                                          ),
                                        ),
                                        child: Text(
                                          att.ticketType,
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                            color: att.ticketType == 'VIP'
                                                ? const Color(0xFFD97706)
                                                : att.ticketType == 'Speaker'
                                                ? AppTheme.primary
                                                : AppTheme.textSecondary,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${att.email} • ${att.phone}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: AppTheme.textSecondary,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            // Check-in status toggle button
                            IconButton(
                              onPressed: () {
                                widget.onAttendeeCheckInToggled(att);
                                setState(() {});
                              },
                              icon: Icon(
                                att.isCheckedIn
                                    ? Icons.check_circle
                                    : Icons.radio_button_unchecked,
                                color: att.isCheckedIn
                                    ? AppTheme.success
                                    : AppTheme.primary,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildScheduleTab(List<ScheduleItem> schedules) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(
                child: Text(
                  'Day Agenda',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              ElevatedButton(
                onPressed: _addNewScheduleItem,
                child: const Icon(Icons.add, size: 18),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: schedules.isEmpty
                ? const Center(child: Text('No sessions yet.'))
                : ListView.separated(
                    itemCount: schedules.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final item = schedules[index];
                      return Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: AppTheme.surface,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppTheme.cardBorder),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: AppTheme.primaryLight,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                item.time,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11,
                                  color: AppTheme.primary,
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          item.title,
                                          style: TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.bold,
                                            color: AppTheme.textPrimary,
                                          ),
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 3,
                                        ),
                                        decoration: BoxDecoration(
                                          color: AppTheme.background,
                                          borderRadius: BorderRadius.circular(
                                            6,
                                          ),
                                          border: Border.all(
                                            color: AppTheme.cardBorder,
                                          ),
                                        ),
                                        child: Text(
                                          item.tag,
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: AppTheme.textSecondary,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Wrap(
                                    spacing: 12,
                                    runSpacing: 6,
                                    children: [
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.person_pin_circle_outlined,
                                            size: 14,
                                            color: AppTheme.textMuted,
                                          ),
                                          const SizedBox(width: 4),
                                          Flexible(
                                            child: Text(
                                              item.speakerName,
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: AppTheme.textSecondary,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.room_outlined,
                                            size: 14,
                                            color: AppTheme.textMuted,
                                          ),
                                          const SizedBox(width: 4),
                                          Flexible(
                                            child: Text(
                                              item.roomOrTrack,
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: AppTheme.textSecondary,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnnouncementsTab(List<AnnouncementItem> announcements) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(
                child: Text(
                  'Broadcasts',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              ElevatedButton(
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (ctx) => SendAnnouncementDialog(
                      events: [_currentEvent],
                      initialEventId: _currentEvent.id,
                      onAnnouncementSent: (announcement) {
                        widget.announcements.insert(0, announcement);
                        widget.onDataChanged();
                        setState(() {});
                      },
                    ),
                  );
                },
                child: const Icon(Icons.campaign, size: 18),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: announcements.isEmpty
                ? const Center(child: Text('No announcements yet.'))
                : ListView.separated(
                    itemCount: announcements.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final a = announcements[index];
                      final isUrgent = a.priority == 'Urgent';
                      return Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: AppTheme.surface,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: isUrgent
                                ? AppTheme.danger.withValues(alpha: 0.4)
                                : AppTheme.cardBorder,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Wrap(
                              alignment: WrapAlignment.spaceBetween,
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isUrgent
                                        ? AppTheme.dangerLight
                                        : AppTheme.accentLight,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    a.priority.toUpperCase(),
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: isUrgent
                                          ? AppTheme.danger
                                          : AppTheme.accent,
                                    ),
                                  ),
                                ),
                                Text(
                                  'Target: ${a.sentTo}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppTheme.textSecondary,
                                  ),
                                ),
                                Text(
                                  a.timestamp,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppTheme.textMuted,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Text(
                              a.title,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              a.message,
                              style: TextStyle(
                                fontSize: 13,
                                color: AppTheme.textSecondary,
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
