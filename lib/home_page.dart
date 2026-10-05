import 'package:flutter/material.dart';
import 'data/mock_data.dart';
import 'models/event_model.dart';
import 'theme/app_theme.dart';
import 'views/announcements_view.dart';
import 'views/attendees_view.dart';
import 'views/create_event_dialog.dart';
import 'views/dashboard_view.dart';
import 'views/events_view.dart';
import 'views/schedule_view.dart';
import 'services/firestore_service.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedIndex = 0;

  final List<EventItem> _events = [];
  final FirestoreService _firestoreService = FirestoreService();
  final List<AttendeeItem> _attendees = [];
  final List<ScheduleItem> _schedules = MockData.schedules;
  final List<AnnouncementItem> _announcements = MockData.announcements;


  @override
  void initState() {
    super.initState();

    _firestoreService.getEvents().listen((events) {
      if (!mounted) return;

      setState(() {
        _events
          ..clear()
          ..addAll(events);
      });
    });

    _firestoreService.getAttendees().listen((attendees) {
      if (!mounted) return;

      setState(() {
        _attendees
          ..clear()
          ..addAll(attendees);
      });
    });
  }

  Future<void> _onEventCreated(EventItem event) async {
    try {
      await _firestoreService.createEvent(event);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Event saved to Firebase successfully!'),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to save event: $e'),
        ),
      );
    }
  }



  Future<void> _onAttendeeRegistered(AttendeeItem attendee) async {
    try {
      await _firestoreService.createAttendee(attendee);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Attendee saved to Firebase successfully!'),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to save attendee: $e'),
        ),
      );
    }
  }

  void _onAnnouncementSent(AnnouncementItem announcement) {
    setState(() {
      _announcements.insert(0, announcement);
    });
  }

  Future<void> _onAttendeeCheckInToggled(
      AttendeeItem attendee,
      ) async {
    try {
      final newStatus = !attendee.isCheckedIn;

      await _firestoreService.updateAttendeeCheckIn(
        attendee,
        newStatus,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            newStatus
                ? '${attendee.name} checked in successfully!'
                : '${attendee.name} check-in cancelled.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update check-in: $e'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> pages = [
      DashboardView(
        events: _events,
        attendees: _attendees,
        schedules: _schedules,
        announcements: _announcements,
        onNavigateToTab: (idx) => setState(() => _selectedIndex = idx),
        onEventCreated: _onEventCreated,
        onAttendeeRegistered: _onAttendeeRegistered,
        onAttendeeCheckInToggled: _onAttendeeCheckInToggled,
        onAnnouncementSent: _onAnnouncementSent,
        onDataChanged: () => setState(() {}),
      ),
      EventsView(
        events: _events,
        attendees: _attendees,
        schedules: _schedules,
        announcements: _announcements,
        onEventCreated: _onEventCreated,
        onAttendeeRegistered: _onAttendeeRegistered,
        onAttendeeCheckInToggled: _onAttendeeCheckInToggled,
        onDataChanged: () => setState(() {}),
      ),
      AttendeesView(
        attendees: _attendees,
        events: _events,
        onAttendeeRegistered: _onAttendeeRegistered,
        onAttendeeCheckInToggled: _onAttendeeCheckInToggled,
        onDataChanged: () => setState(() {}),
      ),
      ScheduleView(
        schedules: _schedules,
        events: _events,
        onDataChanged: () => setState(() {}),
      ),
      AnnouncementsView(
        announcements: _announcements,
        events: _events,
        onAnnouncementSent: _onAnnouncementSent,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktopOrWeb = constraints.maxWidth >= 850;

        if (isDesktopOrWeb) {
          // Responsive Web / Desktop View with Collapsible NavigationRail / Sidebar
          return Scaffold(
            backgroundColor: AppTheme.background,
            body: Row(
              children: [
                _buildWebSidebar(),
                const VerticalDivider(thickness: 1, width: 1, color: AppTheme.cardBorder),
                Expanded(
                  child: SafeArea(
                    child: Column(
                      children: [
                        _buildTopNavbar(),
                        const Divider(thickness: 1, height: 1, color: AppTheme.cardBorder),
                        Expanded(child: pages[_selectedIndex]),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        } else {
          // Mobile View with modern BottomNavigationBar and Top AppBar
          return Scaffold(
            backgroundColor: AppTheme.background,
            appBar: AppBar(
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: AppTheme.primary,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.event_seat_rounded,
                        color: Colors.white, size: 18),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'EventEase',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                ],
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.add_circle_outline_rounded, color: AppTheme.primary),
                  tooltip: 'Create Event',
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (ctx) => CreateEventDialog(
                        onEventCreated: _onEventCreated,
                      ),
                    );
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.notifications_none_rounded),
                  onPressed: () => setState(() => _selectedIndex = 4),
                ),
              ],
            ),
            body: SafeArea(child: pages[_selectedIndex]),
            bottomNavigationBar: NavigationBar(
              selectedIndex: _selectedIndex,
              onDestinationSelected: (index) =>
                  setState(() => _selectedIndex = index),
              indicatorColor: AppTheme.primaryLight,
              destinations: const [
                NavigationDestination(
                  icon: Icon(Icons.dashboard_outlined),
                  selectedIcon: Icon(Icons.dashboard_rounded, color: AppTheme.primary),
                  label: 'Home',
                ),
                NavigationDestination(
                  icon: Icon(Icons.event_outlined),
                  selectedIcon: Icon(Icons.event_rounded, color: AppTheme.primary),
                  label: 'Events',
                ),
                NavigationDestination(
                  icon: Icon(Icons.people_alt_outlined),
                  selectedIcon: Icon(Icons.people_alt_rounded, color: AppTheme.primary),
                  label: 'Attendees',
                ),
                NavigationDestination(
                  icon: Icon(Icons.schedule_outlined),
                  selectedIcon: Icon(Icons.schedule_rounded, color: AppTheme.primary),
                  label: 'Schedule',
                ),
                NavigationDestination(
                  icon: Icon(Icons.campaign_outlined),
                  selectedIcon: Icon(Icons.campaign_rounded, color: AppTheme.primary),
                  label: 'Broadcasts',
                ),
              ],
            ),
          );
        }
      },
    );
  }

  Widget _buildWebSidebar() {
    return Container(
      width: 250,
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Logo & Branding
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppTheme.primary, AppTheme.accent],
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.event_seat_rounded,
                      color: Colors.white, size: 22),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      'EventEase',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary,
                        letterSpacing: -0.5,
                      ),
                    ),
                    Text(
                      'Organizer Suite',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppTheme.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppTheme.cardBorder),
          const SizedBox(height: 12),

          // Nav Items
          _sidebarItem(0, 'Dashboard', Icons.dashboard_outlined, Icons.dashboard_rounded),
          _sidebarItem(1, 'Events', Icons.event_outlined, Icons.event_rounded),
          _sidebarItem(2, 'Attendees', Icons.people_alt_outlined, Icons.people_alt_rounded),
          _sidebarItem(3, 'Schedules', Icons.calendar_month_outlined, Icons.calendar_month_rounded),
          _sidebarItem(4, 'Announcements', Icons.campaign_outlined, Icons.campaign_rounded),

          const Spacer(),

          // Quick Create Action
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (ctx) => CreateEventDialog(
                      onEventCreated: _onEventCreated,
                    ),
                  );
                },
                icon: const Icon(Icons.add, size: 18),
                label: const Text('New Event'),
              ),
            ),
          ),

          // User Profile pill
          Container(
            padding: const EdgeInsets.all(16),
            margin: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.background,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.cardBorder),
            ),
            child: Row(
              children: [
                const CircleAvatar(
                  radius: 18,
                  backgroundColor: AppTheme.primaryDark,
                  child: Text('AD', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        'Alex Danvers',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        'Lead Organizer',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sidebarItem(int index, String title, IconData icon, IconData activeIcon) {
    final isSelected = _selectedIndex == index;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
      child: ListTile(
        dense: true,
        selected: isSelected,
        selectedTileColor: AppTheme.primaryLight,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        leading: Icon(
          isSelected ? activeIcon : icon,
          color: isSelected ? AppTheme.primary : AppTheme.textSecondary,
          size: 20,
        ),
        title: Text(
          title,
          style: TextStyle(
            fontSize: 14,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected ? AppTheme.primary : AppTheme.textPrimary,
          ),
        ),
        onTap: () => setState(() => _selectedIndex = index),
      ),
    );
  }

  Widget _buildTopNavbar() {
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      color: Colors.white,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Left breadcrumb / page title indicator
          Expanded(
            child: Row(
              children: [
                Flexible(
                  child: Text(
                    _getSectionTitle(_selectedIndex),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppTheme.successLight,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.fiber_manual_record, color: AppTheme.success, size: 10),
                      SizedBox(width: 4),
                      Text(
                        'Live',
                        style: TextStyle(fontSize: 11, color: AppTheme.success, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Actions
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.help_outline_rounded, color: AppTheme.textSecondary),
                tooltip: 'Documentation & Help',
                onPressed: () {},
              ),
              const SizedBox(width: 8),
              Stack(
                children: [
                  IconButton(
                    icon: const Icon(Icons.notifications_none_rounded, color: AppTheme.textSecondary),
                    onPressed: () => setState(() => _selectedIndex = 4),
                  ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: AppTheme.danger,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _getSectionTitle(int index) {
    switch (index) {
      case 0:
        return 'Control Center';
      case 1:
        return 'Events Directory';
      case 2:
        return 'Attendee Registry';
      case 3:
        return 'Event Agenda';
      case 4:
        return 'Broadcast Network';
      default:
        return 'EventEase';
    }
  }
}
