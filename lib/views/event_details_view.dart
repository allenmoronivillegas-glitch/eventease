import 'package:flutter/material.dart';
import '../data/mock_data.dart';
import '../models/event_model.dart';
import '../theme/app_theme.dart';
import 'register_attendee_dialog.dart';
import 'send_announcement_dialog.dart';

class EventDetailsView extends StatefulWidget {
  final EventItem event;
  final List<AttendeeItem> attendees;
  final List<ScheduleItem> schedules;
  final List<AnnouncementItem> announcements;
  final VoidCallback onDataChanged;

  const EventDetailsView({
    super.key,
    required this.event,
    required this.attendees,
    required this.schedules,
    required this.announcements,
    required this.onDataChanged,
  });

  @override
  State<EventDetailsView> createState() => _EventDetailsViewState();
}

class _EventDetailsViewState extends State<EventDetailsView>
    with SingleTickerProviderStateMixin {
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

  void _openCheckInDialog() {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
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
                child: const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.qr_code_2_rounded, size: 100, color: AppTheme.primaryDark),
                    SizedBox(height: 8),
                    Text(
                      'Ready to Scan Pass',
                      style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const Text(
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
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleCtrl,
                decoration: const InputDecoration(labelText: 'Session Title *'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: timeCtrl,
                decoration: const InputDecoration(labelText: 'Time Slot *'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: speakerCtrl,
                decoration: const InputDecoration(labelText: 'Speaker / Facilitator'),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: roomCtrl,
                      decoration: const InputDecoration(labelText: 'Track / Room'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: tagCtrl,
                      decoration: const InputDecoration(labelText: 'Category Tag'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (titleCtrl.text.trim().isNotEmpty) {
                widget.schedules.add(
                  ScheduleItem(
                    id: 'SCH-${DateTime.now().millisecondsSinceEpoch}',
                    eventId: widget.event.id,
                    time: timeCtrl.text.trim(),
                    title: titleCtrl.text.trim(),
                    speakerName: speakerCtrl.text.trim().isEmpty ? 'TBA' : speakerCtrl.text.trim(),
                    roomOrTrack: roomCtrl.text.trim().isEmpty ? 'Main Hall' : roomCtrl.text.trim(),
                    tag: tagCtrl.text.trim().isEmpty ? 'General' : tagCtrl.text.trim(),
                  ),
                );
                widget.onDataChanged();
                setState(() {});
                Navigator.of(ctx).pop();
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
    final eventAttendees =
        widget.attendees.where((a) => a.eventId == widget.event.id).toList();
    final eventSchedules =
        widget.schedules.where((s) => s.eventId == widget.event.id).toList();
    final eventAnnouncements =
        widget.announcements.where((a) => a.eventId == widget.event.id).toList();

    final filteredAttendees = eventAttendees.where((a) {
      final query = _attendeeSearchQuery.toLowerCase();
      return a.name.toLowerCase().contains(query) ||
          a.email.toLowerCase().contains(query) ||
          a.ticketType.toLowerCase().contains(query);
    }).toList();

    final checkInRate = widget.event.registeredCount > 0
        ? (widget.event.checkedInCount / widget.event.registeredCount * 100).toInt()
        : 0;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text(
          widget.event.title,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        actions: [
          IconButton(
            tooltip: 'Live Check-In Scanner',
            icon: const Icon(Icons.qr_code_scanner_rounded, color: AppTheme.primary),
            onPressed: _openCheckInDialog,
          ),
          IconButton(
            tooltip: 'Broadcast Announcement',
            icon: const Icon(Icons.campaign_rounded, color: AppTheme.accent),
            onPressed: () {
              showDialog(
                context: context,
                builder: (ctx) => SendAnnouncementDialog(
                  events: [widget.event],
                  initialEventId: widget.event.id,
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
            icon: const Icon(Icons.person_add_alt_1_rounded, color: AppTheme.success),
            onPressed: () {
              showDialog(
                context: context,
                builder: (ctx) => RegisterAttendeeDialog(
                  events: [widget.event],
                  initialEventId: widget.event.id,
                  onAttendeeRegistered: (attendee) {
                    widget.attendees.insert(0, attendee);
                    widget.onDataChanged();
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
          _buildOverviewTab(checkInRate, eventAttendees, eventSchedules),

          // 2. ATTENDEES TAB (with check-in capability)
          _buildAttendeesTab(filteredAttendees),

          // 3. SCHEDULE TAB
          _buildScheduleTab(eventSchedules),

          // 4. ANNOUNCEMENTS TAB
          _buildAnnouncementsTab(eventAnnouncements),
        ],
      ),
    );
  }

  Widget _buildOverviewTab(
      int checkInRate, List<AttendeeItem> attendees, List<ScheduleItem> schedules) {
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
              gradient: const LinearGradient(
                colors: [Color(0xFF312E81), Color(0xFF4F46E5), Color(0xFF06B6D4)],
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
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        widget.event.category.toUpperCase(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: widget.event.status == 'Live'
                            ? AppTheme.success
                            : Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        children: [
                          if (widget.event.status == 'Live')
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
                            widget.event.status,
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
                  widget.event.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  widget.event.description,
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
                    _infoBadge(Icons.calendar_today, widget.event.date),
                    _infoBadge(Icons.access_time, widget.event.time),
                    _infoBadge(Icons.location_on_outlined, widget.event.location),
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
              return Wrap(
                spacing: 16,
                runSpacing: 16,
                children: [
                  SizedBox(
                    width: isWide ? (constraints.maxWidth - 48) / 4 : (constraints.maxWidth - 16) / 2,
                    child: _metricCard(
                      'Total Capacity',
                      '${widget.event.totalCapacity}',
                      Icons.airline_seat_recline_normal,
                      Colors.blue,
                    ),
                  ),
                  SizedBox(
                    width: isWide ? (constraints.maxWidth - 48) / 4 : (constraints.maxWidth - 16) / 2,
                    child: _metricCard(
                      'Registered',
                      '${widget.event.registeredCount}',
                      Icons.how_to_reg,
                      AppTheme.primary,
                    ),
                  ),
                  SizedBox(
                    width: isWide ? (constraints.maxWidth - 48) / 4 : (constraints.maxWidth - 16) / 2,
                    child: _metricCard(
                      'Checked-In',
                      '${widget.event.checkedInCount}',
                      Icons.check_circle_outline,
                      AppTheme.success,
                    ),
                  ),
                  SizedBox(
                    width: isWide ? (constraints.maxWidth - 48) / 4 : (constraints.maxWidth - 16) / 2,
                    child: _metricCard(
                      'Check-in Rate',
                      '$checkInRate%',
                      Icons.insights,
                      AppTheme.accent,
                    ),
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
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.cardBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Attendance & Venue Capacity Fulfillment',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                    Text(
                      '${widget.event.registeredCount} / ${widget.event.totalCapacity} (${(widget.event.registeredCount / widget.event.totalCapacity * 100).toInt()}%)',
                      style: const TextStyle(
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
                    value: widget.event.registeredCount / widget.event.totalCapacity,
                    minHeight: 12,
                    backgroundColor: AppTheme.cardBorder,
                    valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.primary),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${widget.event.totalCapacity - widget.event.registeredCount} spots remaining',
                      style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                    ),
                    Text(
                      '${widget.event.checkedInCount} checked-in at desk',
                      style: const TextStyle(fontSize: 12, color: AppTheme.success, fontWeight: FontWeight.w600),
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
        Text(
          text,
          style: const TextStyle(color: Colors.white, fontSize: 13),
        ),
      ],
    );
  }

  Widget _metricCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 12),
          Text(
            value,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildAttendeesTab(List<AttendeeItem> attendees) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  decoration: const InputDecoration(
                    hintText: 'Search attendee by name, email or ticket pass...',
                    prefixIcon: Icon(Icons.search, size: 20),
                  ),
                  onChanged: (val) => setState(() => _attendeeSearchQuery = val),
                ),
              ),
              const SizedBox(width: 14),
              ElevatedButton.icon(
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (ctx) => RegisterAttendeeDialog(
                      events: [widget.event],
                      initialEventId: widget.event.id,
                      onAttendeeRegistered: (attendee) {
                        widget.attendees.insert(0, attendee);
                        widget.onDataChanged();
                        setState(() {});
                      },
                    ),
                  );
                },
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add Attendee'),
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
                        Icon(Icons.person_search_outlined,
                            size: 64, color: AppTheme.textMuted),
                        const SizedBox(height: 12),
                        const Text(
                          'No attendees found',
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textSecondary),
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
                          color: Colors.white,
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
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        att.name,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 15,
                                          color: AppTheme.textPrimary,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: att.ticketType == 'VIP'
                                              ? const Color(0xFFFEF3C7)
                                              : att.ticketType == 'Speaker'
                                                  ? const Color(0xFFEDE9FE)
                                                  : AppTheme.background,
                                          borderRadius: BorderRadius.circular(6),
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
                                    style: const TextStyle(
                                        fontSize: 12, color: AppTheme.textSecondary),
                                  ),
                                ],
                              ),
                            ),
                            // Check-in status toggle button
                            ElevatedButton.icon(
                              onPressed: () {
                                setState(() {
                                  att.isCheckedIn = !att.isCheckedIn;
                                  final increment = att.isCheckedIn ? 1 : -1;
                                  
                                  // update
                                  final index = MockData.events.indexWhere((e) => e.id == widget.event.id);
                                  if (index != -1) {
                                    final e = MockData.events[index];
                                    MockData.events[index] = EventItem(
                                      id: e.id,
                                      title: e.title,
                                      description: e.description,
                                      category: e.category,
                                      date: e.date,
                                      time: e.time,
                                      location: e.location,
                                      isVirtual: e.isVirtual,
                                      totalCapacity: e.totalCapacity,
                                      registeredCount: e.registeredCount,
                                      checkedInCount: e.checkedInCount + increment,
                                      ticketPrice: e.ticketPrice,
                                      bannerImageUrl: e.bannerImageUrl,
                                      status: e.status,
                                    );
                                  }
                                });
                                widget.onDataChanged();
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: att.isCheckedIn
                                    ? AppTheme.successLight
                                    : AppTheme.primaryLight,
                                foregroundColor: att.isCheckedIn
                                    ? AppTheme.success
                                    : AppTheme.primary,
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 10),
                              ),
                              icon: Icon(
                                att.isCheckedIn
                                    ? Icons.check_circle
                                    : Icons.radio_button_unchecked,
                                size: 16,
                              ),
                              label: Text(
                                att.isCheckedIn ? 'Checked In' : 'Check In',
                                style: const TextStyle(fontSize: 12),
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
              const Text(
                'Day Agenda & Session Tracks',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              ElevatedButton.icon(
                onPressed: _addNewScheduleItem,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add Session'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: schedules.isEmpty
                ? const Center(child: Text('No schedule sessions registered yet.'))
                : ListView.separated(
                    itemCount: schedules.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final item = schedules[index];
                      return Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppTheme.cardBorder),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: AppTheme.primaryLight,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                item.time,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
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
                                          style: const TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.bold,
                                            color: AppTheme.textPrimary,
                                          ),
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: AppTheme.background,
                                          borderRadius: BorderRadius.circular(6),
                                          border: Border.all(
                                              color: AppTheme.cardBorder),
                                        ),
                                        child: Text(
                                          item.tag,
                                          style: const TextStyle(
                                              fontSize: 11,
                                              color: AppTheme.textSecondary),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Row(
                                    children: [
                                      const Icon(Icons.person_pin_circle_outlined,
                                          size: 15, color: AppTheme.textMuted),
                                      const SizedBox(width: 4),
                                      Text(
                                        item.speakerName,
                                        style: const TextStyle(
                                            fontSize: 13,
                                            color: AppTheme.textSecondary),
                                      ),
                                      const SizedBox(width: 16),
                                      const Icon(Icons.room_outlined,
                                          size: 15, color: AppTheme.textMuted),
                                      const SizedBox(width: 4),
                                      Text(
                                        item.roomOrTrack,
                                        style: const TextStyle(
                                            fontSize: 13,
                                            color: AppTheme.textSecondary),
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
              const Text(
                'Sent Broadcast Updates',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              ElevatedButton.icon(
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (ctx) => SendAnnouncementDialog(
                      events: [widget.event],
                      initialEventId: widget.event.id,
                      onAnnouncementSent: (announcement) {
                        widget.announcements.insert(0, announcement);
                        widget.onDataChanged();
                        setState(() {});
                      },
                    ),
                  );
                },
                icon: const Icon(Icons.campaign_outlined, size: 18),
                label: const Text('New Broadcast'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: announcements.isEmpty
                ? const Center(
                    child: Text('No announcements dispatched for this event.'))
                : ListView.separated(
                    itemCount: announcements.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final a = announcements[index];
                      final isUrgent = a.priority == 'Urgent';
                      return Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: Colors.white,
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
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 3),
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
                                    const SizedBox(width: 8),
                                    Text(
                                      'Audience: ${a.sentTo}',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: AppTheme.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                                Text(
                                  a.timestamp,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppTheme.textMuted,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Text(
                              a.title,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              a.message,
                              style: const TextStyle(
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
