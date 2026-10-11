import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'models/event_model.dart';
import 'services/user_profile_service.dart';
import 'theme/app_theme.dart';
import 'views/announcements_view.dart';
import 'views/attendee_events_view.dart';
import 'views/attendees_view.dart';
import 'views/create_event_dialog.dart';
import 'views/dashboard_view.dart';
import 'views/events_view.dart';
import 'views/schedule_view.dart';
import 'views/settings_page.dart';
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
  final UserProfileService _userProfileService = UserProfileService();
  User? _signedInUser;
  Map<String, dynamic>? _profile;
  String? _role;
  String? _profileError;
  bool _profileLoading = true;
  bool _organizerSubscriptionsStarted = false;
  StreamSubscription<Map<String, dynamic>?>? _profileSubscription;
  final List<StreamSubscription<dynamic>> _dataSubscriptions = [];
  final Set<String> _loadedDataSources = {};
  final Map<String, String> _dataErrors = {};
  final List<AttendeeItem> _attendees = [];
  final List<ScheduleItem> _schedules = [];
  final List<AnnouncementItem> _announcements = [];

  @override
  void initState() {
    super.initState();
    _signedInUser = FirebaseAuth.instance.currentUser;
    _listenToProfile();
  }

  void _listenToProfile() {
    final uid = _signedInUser?.uid;
    if (uid == null) {
      setState(() {
        _profileLoading = false;
        _profileError = 'Your signed-in account could not be found.';
      });
      return;
    }

    _profileSubscription = _userProfileService
        .watchProfile(uid)
        .listen(
          (profile) {
            if (!mounted) return;
            final role = profile?['role'];
            final validRole = role == 'organizer' || role == 'attendee';
            if (role != 'organizer' && _organizerSubscriptionsStarted) {
              _cancelOrganizerSubscriptions();
            }
            setState(() {
              _profile = profile;
              _role = validRole ? role as String : null;
              _profileLoading = false;
              _profileError = validRole
                  ? null
                  : 'Your account role is missing or invalid. Sign out and sign '
                        'back in, or contact support.';
            });
            if (role == 'organizer' && !_organizerSubscriptionsStarted) {
              _subscribeToOrganizerData();
            }
          },
          onError: (Object error, StackTrace stackTrace) {
            if (!mounted) return;
            debugPrint(
              '[HomePage] Profile stream failed (${error.runtimeType})',
            );
            if (_organizerSubscriptionsStarted) {
              _cancelOrganizerSubscriptions();
            }
            setState(() {
              _profileLoading = false;
              _profileError = 'Could not load your account role. Check your connection and retry.';
            });
          },
        );
  }

  void _subscribeToOrganizerData() {
    _organizerSubscriptionsStarted = true;
    setState(() {
      _loadedDataSources.clear();
      _dataErrors.clear();
    });

    _listenToData(
      'events',
      _firestoreService.getEvents(),
      (events) => _events
        ..clear()
        ..addAll(events),
    );
    _listenToData(
      'attendees',
      _firestoreService.getAttendees(),
      (attendees) => _attendees
        ..clear()
        ..addAll(attendees),
    );
    _listenToData(
      'schedules',
      _firestoreService.getSchedules(),
      (schedules) => _schedules
        ..clear()
        ..addAll(schedules),
    );
    _listenToData(
      'announcements',
      _firestoreService.getAnnouncements(),
      (announcements) => _announcements
        ..clear()
        ..addAll(announcements),
    );
  }

  void _listenToData<T>(
    String source,
    Stream<T> stream,
    void Function(T data) updateData,
  ) {
    _dataSubscriptions.add(
      stream.listen(
        (data) {
          if (!mounted) return;
          setState(() {
            updateData(data);
            _loadedDataSources.add(source);
            _dataErrors.remove(source);
          });
        },
        onError: (Object error, StackTrace stackTrace) {
          if (!mounted) return;
          debugPrint('[HomePage] $source stream failed (${error.runtimeType})');
          setState(() {
            _loadedDataSources.add(source);
            _dataErrors[source] = 'Could not load ${source.toLowerCase()}.';
          });
        },
      ),
    );
  }

  void _cancelOrganizerSubscriptions() {
    for (final subscription in _dataSubscriptions) {
      unawaited(subscription.cancel());
    }
    _dataSubscriptions.clear();
    _organizerSubscriptionsStarted = false;
    _loadedDataSources.clear();
    _dataErrors.clear();
    _events.clear();
    _attendees.clear();
    _schedules.clear();
    _announcements.clear();
  }

  void _retryProfile() {
    unawaited(_profileSubscription?.cancel());
    setState(() {
      _profileLoading = true;
      _profileError = null;
    });
    _listenToProfile();
  }

  void _retryOrganizerData() {
    _cancelOrganizerSubscriptions();
    _subscribeToOrganizerData();
  }

  @override
  void dispose() {
    unawaited(_profileSubscription?.cancel());
    for (final subscription in _dataSubscriptions) {
      unawaited(subscription.cancel());
    }
    super.dispose();
  }

  Future<void> _onEventCreated(EventItem event) async {
    try {
      await _firestoreService.createEvent(event);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Event saved to Firebase successfully!')),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Failed to save event: $e')));
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

      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Failed to save attendee: $e')));
    }
  }

  Future<void> _onAnnouncementSent(AnnouncementItem announcement) async {
    try {
      await _firestoreService.createAnnouncement(announcement);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Announcement saved to Firebase successfully!'),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save announcement: $e')),
      );
    }
  }

  Future<void> _onAttendeeCheckInToggled(AttendeeItem attendee) async {
    try {
      final newStatus = !attendee.isCheckedIn;

      await _firestoreService.updateAttendeeCheckIn(attendee, newStatus);

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

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to update check-in: $e')));
    }
  }

  void _openSettings() {
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => const SettingsPage()));
  }

  @override
  Widget build(BuildContext context) {
    Theme.of(context);
    if (_profileLoading) return _buildLoadingScreen();
    if (_profileError != null) {
      return _buildErrorScreen(_profileError!, onRetry: _retryProfile);
    }
    if (_role == 'attendee') return _buildAttendeeHome();
    if (_role != 'organizer') {
      return _buildErrorScreen(
        'Your account role could not be verified. Organizer tools are '
        'unavailable until your profile is corrected.',
        onRetry: _retryProfile,
      );
    }
    if (_loadedDataSources.length < 4 && _dataErrors.isEmpty) {
      return _buildLoadingScreen();
    }

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
                VerticalDivider(
                  thickness: 1,
                  width: 1,
                  color: AppTheme.cardBorder,
                ),
                Expanded(
                  child: SafeArea(
                    child: Column(
                      children: [
                        _buildTopNavbar(),
                        Divider(
                          thickness: 1,
                          height: 1,
                          color: AppTheme.cardBorder,
                        ),
                        Expanded(child: _withDataStatus(pages[_selectedIndex])),
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
                  SizedBox(
                    width: 36,
                    height: 36,
                    child: Image.asset(
                      'assets/branding/logo.png',
                      fit: BoxFit.contain,
                      semanticLabel: 'EventEase logo',
                    ),
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
                  icon: Icon(
                    Icons.add_circle_outline_rounded,
                    color: AppTheme.primary,
                  ),
                  tooltip: 'Create Event',
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (ctx) =>
                          CreateEventDialog(onEventCreated: _onEventCreated),
                    );
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.notifications_none_rounded),
                  onPressed: () => setState(() => _selectedIndex = 4),
                ),
                IconButton(
                  icon: const Icon(Icons.settings_outlined),
                  tooltip: 'Settings',
                  onPressed: _openSettings,
                ),
              ],
            ),
            body: SafeArea(child: _withDataStatus(pages[_selectedIndex])),
            bottomNavigationBar: NavigationBar(
              selectedIndex: _selectedIndex,
              onDestinationSelected: (index) =>
                  setState(() => _selectedIndex = index),
              indicatorColor: AppTheme.primaryLight,
              destinations: [
                NavigationDestination(
                  icon: Icon(Icons.dashboard_outlined),
                  selectedIcon: Icon(
                    Icons.dashboard_rounded,
                    color: AppTheme.primary,
                  ),
                  label: 'Home',
                ),
                NavigationDestination(
                  icon: Icon(Icons.event_outlined),
                  selectedIcon: Icon(
                    Icons.event_rounded,
                    color: AppTheme.primary,
                  ),
                  label: 'Events',
                ),
                NavigationDestination(
                  icon: Icon(Icons.people_alt_outlined),
                  selectedIcon: Icon(
                    Icons.people_alt_rounded,
                    color: AppTheme.primary,
                  ),
                  label: 'Attendees',
                ),
                NavigationDestination(
                  icon: Icon(Icons.schedule_outlined),
                  selectedIcon: Icon(
                    Icons.schedule_rounded,
                    color: AppTheme.primary,
                  ),
                  label: 'Schedule',
                ),
                NavigationDestination(
                  icon: Icon(Icons.campaign_outlined),
                  selectedIcon: Icon(
                    Icons.campaign_rounded,
                    color: AppTheme.primary,
                  ),
                  label: 'Broadcasts',
                ),
              ],
            ),
          );
        }
      },
    );
  }

  Widget _withDataStatus(Widget child) {
    return Column(
      children: [
        if (_dataErrors.isNotEmpty)
          MaterialBanner(
            content: Text(
              'Some event data could not be loaded '
              '(${_dataErrors.keys.join(', ')}).',
            ),
            leading: const Icon(Icons.warning_amber_rounded),
            actions: [
              TextButton(
                onPressed: _retryOrganizerData,
                child: const Text('Retry'),
              ),
            ],
          ),
        Expanded(child: child),
      ],
    );
  }

  Widget _buildLoadingScreen() {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Center(child: CircularProgressIndicator(color: AppTheme.primary)),
    );
  }

  Widget _buildErrorScreen(String message, {required VoidCallback onRetry}) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.error_outline_rounded,
                size: 40,
                color: AppTheme.danger,
              ),
              const SizedBox(height: 12),
              Text(message, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAttendeeHome() {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text(
          'Browse Events',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Settings',
            onPressed: _openSettings,
          ),
        ],
      ),
      body: AttendeeEventsView(firestoreService: _firestoreService),
    );
  }

  Widget _buildWebSidebar() {
    return Container(
      width: 250,
      color: AppTheme.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Logo & Branding
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            child: Row(
              children: [
                SizedBox(
                  width: 40,
                  height: 40,
                  child: Image.asset(
                    'assets/branding/logo.png',
                    fit: BoxFit.contain,
                    semanticLabel: 'EventEase logo',
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
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
          Divider(height: 1, color: AppTheme.cardBorder),
          const SizedBox(height: 12),

          // Nav Items
          _sidebarItem(
            0,
            'Dashboard',
            Icons.dashboard_outlined,
            Icons.dashboard_rounded,
          ),
          _sidebarItem(1, 'Events', Icons.event_outlined, Icons.event_rounded),
          _sidebarItem(
            2,
            'Attendees',
            Icons.people_alt_outlined,
            Icons.people_alt_rounded,
          ),
          _sidebarItem(
            3,
            'Schedules',
            Icons.calendar_month_outlined,
            Icons.calendar_month_rounded,
          ),
          _sidebarItem(
            4,
            'Announcements',
            Icons.campaign_outlined,
            Icons.campaign_rounded,
          ),

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
                    builder: (ctx) =>
                        CreateEventDialog(onEventCreated: _onEventCreated),
                  );
                },
                icon: const Icon(Icons.add, size: 18),
                label: const Text('New Event'),
              ),
            ),
          ),

          _buildUserProfilePill(),
        ],
      ),
    );
  }

  Widget _buildUserProfilePill() {
    final user = _signedInUser;
    if (user == null) {
      return _userProfilePill(name: 'EventEase User', role: 'Member');
    }

    final profile = _profile;
    final name =
        _nonEmptyString(profile?['displayName']) ??
        _nonEmptyString(user.displayName) ??
        _nonEmptyString(user.email) ??
        'EventEase User';
    return _userProfilePill(
      name: name,
      role: _friendlyRole(_role),
      photoUrl:
          _nonEmptyString(profile?['photoURL']) ??
          _nonEmptyString(user.photoURL),
    );
  }

  Widget _userProfilePill({
    required String name,
    required String role,
    String? photoUrl,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.cardBorder),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: AppTheme.primaryDark,
            backgroundImage: photoUrl == null ? null : NetworkImage(photoUrl),
            child: photoUrl == null
                ? Text(
                    _initials(name),
                    style: TextStyle(
                      color: AppTheme.surface,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  )
                : null,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  role,
                  style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String? _nonEmptyString(Object? value) {
    if (value is String && value.trim().isNotEmpty) return value.trim();
    return null;
  }

  String _friendlyRole(Object? value) {
    switch (value) {
      case 'organizer':
        return 'Event Organizer';
      case 'attendee':
        return 'Attendee';
      default:
        return 'Member';
    }
  }

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return 'E';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }

  Widget _sidebarItem(
    int index,
    String title,
    IconData icon,
    IconData activeIcon,
  ) {
    final isSelected = _selectedIndex == index;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
      child: Material(
        color: Colors.transparent,
        child: ListTile(
          dense: true,
          selected: isSelected,
          selectedTileColor: AppTheme.primaryLight,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
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
      ),
    );
  }

  Widget _buildTopNavbar() {
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      color: AppTheme.surface,
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
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 10),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.successLight,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.fiber_manual_record,
                        color: AppTheme.success,
                        size: 10,
                      ),
                      SizedBox(width: 4),
                      Text(
                        'Live',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppTheme.success,
                          fontWeight: FontWeight.bold,
                        ),
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
                icon: Icon(
                  Icons.help_outline_rounded,
                  color: AppTheme.textSecondary,
                ),
                tooltip: 'Documentation & Help',
                onPressed: () {},
              ),
              IconButton(
                icon: Icon(
                  Icons.settings_outlined,
                  color: AppTheme.textSecondary,
                ),
                tooltip: 'Settings',
                onPressed: _openSettings,
              ),
              const SizedBox(width: 8),
              Stack(
                children: [
                  IconButton(
                    icon: Icon(
                      Icons.notifications_none_rounded,
                      color: AppTheme.textSecondary,
                    ),
                    onPressed: () => setState(() => _selectedIndex = 4),
                  ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
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
