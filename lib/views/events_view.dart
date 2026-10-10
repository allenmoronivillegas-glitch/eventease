import 'package:flutter/material.dart';

import '../models/event_model.dart';
import '../services/firestore_service.dart';
import '../theme/app_theme.dart';
import 'create_event_dialog.dart';
import 'event_details_view.dart';

class EventsView extends StatefulWidget {
  final List<EventItem> events;
  final List<AttendeeItem> attendees;
  final List<ScheduleItem> schedules;
  final List<AnnouncementItem> announcements;
  final Function(EventItem) onEventCreated;
  final Function(AttendeeItem) onAttendeeRegistered;
  final Function(AttendeeItem) onAttendeeCheckInToggled;
  final VoidCallback onDataChanged;

  const EventsView({
    super.key,
    required this.events,
    required this.attendees,
    required this.schedules,
    required this.announcements,
    required this.onEventCreated,
    required this.onAttendeeRegistered,
    required this.onAttendeeCheckInToggled,
    required this.onDataChanged,
  });

  @override
  State<EventsView> createState() => _EventsViewState();
}

class _EventsViewState extends State<EventsView> {
  String _filterCategory = 'All';
  String _searchQuery = '';
  final FirestoreService _firestoreService = FirestoreService();
  final Set<String> _deletingEventIds = {};

  Future<void> _deleteEvent(EventItem event) async {
    if (_deletingEventIds.contains(event.id)) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete Event?'),
        content: Text(
          'Permanently delete "${event.title}" and all of its associated '
          'attendees, schedules, and announcements?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Delete Event'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted || _deletingEventIds.contains(event.id)) {
      return;
    }
    setState(() => _deletingEventIds.add(event.id));

    try {
      await _firestoreService.deleteEvent(event.id);
      if (!mounted) return;
      widget.onDataChanged();
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('"${event.title}" was deleted.')));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Could not confirm deletion of "${event.title}". Related records '
            'may have been partially deleted; verify Firestore before retrying. '
            'Details: $error',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _deletingEventIds.remove(event.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final categories = ['All', 'Technology', 'Design', 'Business', 'Developer'];

    final filteredEvents = widget.events.where((event) {
      final matchesCat = _filterCategory == 'All' || event.category == _filterCategory;
      final matchesSearch =
          event.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          event.location.toLowerCase().contains(_searchQuery.toLowerCase());
      return matchesCat && matchesSearch;
    }).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header + Action
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Events Directory',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Manage your upcoming events.',
                      style: TextStyle(fontSize: 14, color: AppTheme.textSecondary),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton(
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (ctx) => CreateEventDialog(onEventCreated: widget.onEventCreated),
                  );
                },
                child: const Icon(Icons.add, size: 20),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Filters & Search Bar
          LayoutBuilder(
            builder: (context, constraints) {
              final bool isNarrow = constraints.maxWidth < 500;
              final searchField = TextField(
                decoration: const InputDecoration(
                  hintText: 'Search event...',
                  prefixIcon: Icon(Icons.search, size: 20),
                ),
                onChanged: (val) => setState(() => _searchQuery = val),
              );

              final categoryDropdown = DropdownButtonFormField<String>(
                initialValue: _filterCategory,
                items: categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                onChanged: (val) {
                  if (val != null) setState(() => _filterCategory = val);
                },
                decoration: const InputDecoration(
                  labelText: 'Category',
                  contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
              );

              return Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppTheme.cardBorder),
                ),
                child: isNarrow
                    ? Column(children: [searchField, const SizedBox(height: 12), categoryDropdown])
                    : Row(
                        children: [
                          Expanded(flex: 2, child: searchField),
                          const SizedBox(width: 16),
                          Expanded(flex: 1, child: categoryDropdown),
                        ],
                      ),
              );
            },
          ),
          const SizedBox(height: 24),

          // Events Grid
          LayoutBuilder(
            builder: (context, constraints) {
              final double width = constraints.maxWidth;
              int crossAxisCount = 1;
              if (width >= 1100) {
                crossAxisCount = 3;
              } else if (width >= 700) {
                crossAxisCount = 2;
              }

              if (filteredEvents.isEmpty) {
                return Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(40),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppTheme.cardBorder),
                  ),
                  child: Column(
                    children: [
                      Icon(Icons.event_busy, size: 50, color: AppTheme.textMuted),
                      const SizedBox(height: 12),
                      const Text(
                        'No events found',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                );
              }

              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: filteredEvents.length,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: crossAxisCount,
                  crossAxisSpacing: 20,
                  mainAxisSpacing: 20,
                  mainAxisExtent: 400,
                ),
                itemBuilder: (context, index) {
                  final event = filteredEvents[index];
                  return _buildEventCard(event);
                },
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildEventCard(EventItem event) {
    final double progress = event.totalCapacity > 0
        ? (event.registeredCount / event.totalCapacity)
        : 0;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.cardBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Image / Gradient Area
          Container(
            height: 110,
            decoration: BoxDecoration(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
              gradient: LinearGradient(
                colors: [
                  AppTheme.primary.withValues(alpha: 0.85),
                  AppTheme.accent.withValues(alpha: 0.85),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Text(
                        event.category,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: event.status == 'Live'
                            ? AppTheme.success
                            : Colors.black.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Text(
                        event.status,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                Text(
                  event.date,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),

          // Content
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  event.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(Icons.location_on_outlined, size: 14, color: AppTheme.textMuted),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        event.location,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Registration stats
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Registration',
                      style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                    ),
                    Text(
                      '${event.registeredCount} / ${event.totalCapacity}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 8,
                    backgroundColor: AppTheme.cardBorder,
                    valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.primary),
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  spacing: 12,
                  runSpacing: 4,
                  children: [
                    Text(
                      'Checked-in: ${event.checkedInCount}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppTheme.success,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      event.ticketPrice > 0 ? '\$${event.ticketPrice.toStringAsFixed(0)}' : 'Free',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),

                // Manage / Details Button
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) => EventDetailsView(
                                eventId: event.id,
                                events: widget.events,
                                attendees: widget.attendees,
                                schedules: widget.schedules,
                                announcements: widget.announcements,
                                onAttendeeRegistered: widget.onAttendeeRegistered,
                                onAttendeeCheckInToggled: widget.onAttendeeCheckInToggled,
                                onDataChanged: widget.onDataChanged,
                              ),
                            ),
                          );
                        },
                        child: const Text('Manage Event'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      tooltip: 'Delete event',
                      onPressed: _deletingEventIds.contains(event.id)
                          ? null
                          : () => _deleteEvent(event),
                      icon: _deletingEventIds.contains(event.id)
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.delete_outline),
                      color: AppTheme.danger,
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
}
