import 'package:flutter/material.dart';
import '../models/event_model.dart';
import '../theme/app_theme.dart';
import '../widgets/stat_card.dart';
import 'create_event_dialog.dart';
import 'event_details_view.dart';
import 'register_attendee_dialog.dart';
import 'send_announcement_dialog.dart';

class DashboardView extends StatelessWidget {
  final List<EventItem> events;
  final List<AttendeeItem> attendees;
  final List<ScheduleItem> schedules;
  final List<AnnouncementItem> announcements;
  final Function(int) onNavigateToTab;
  final Function(EventItem) onEventCreated;
  final Function(AttendeeItem) onAttendeeRegistered;
  final Function(AnnouncementItem) onAnnouncementSent;
  final VoidCallback onDataChanged;

  const DashboardView({
    super.key,
    required this.events,
    required this.attendees,
    required this.schedules,
    required this.announcements,
    required this.onNavigateToTab,
    required this.onEventCreated,
    required this.onAttendeeRegistered,
    required this.onAnnouncementSent,
    required this.onDataChanged,
  });

  @override
  Widget build(BuildContext context) {
    final int totalEvents = events.length;
    final int totalRegistrations =
        events.fold(0, (sum, item) => sum + item.registeredCount);
    final int totalCheckedIn =
        events.fold(0, (sum, item) => sum + item.checkedInCount);
    final int liveEventsCount =
        events.where((e) => e.status == 'Live').length;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Welcome Header with Quick Action
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Organizer Dashboard',
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Welcome back! Here is what is happening across your events today.',
                    style: TextStyle(fontSize: 14, color: AppTheme.textSecondary),
                  ),
                ],
              ),
              Wrap(
                spacing: 12,
                children: [
                  OutlinedButton.icon(
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (ctx) => RegisterAttendeeDialog(
                          events: events,
                          onAttendeeRegistered: onAttendeeRegistered,
                        ),
                      );
                    },
                    icon: const Icon(Icons.person_add_outlined, size: 18),
                    label: const Text('Register Attendee'),
                  ),
                  ElevatedButton.icon(
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (ctx) => CreateEventDialog(
                          onEventCreated: onEventCreated,
                        ),
                      );
                    },
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: const Text('New Event'),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Stat Cards Section
          LayoutBuilder(
            builder: (context, constraints) {
              final double width = constraints.maxWidth;
              final int count = width > 1100 ? 4 : (width > 600 ? 2 : 1);
              return GridView.count(
                crossAxisCount: count,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                childAspectRatio: 2.2,
                children: [
                  StatCard(
                    title: 'TOTAL EVENTS',
                    value: '$totalEvents',
                    subtitle: '$liveEventsCount currently active & live',
                    icon: Icons.calendar_today_rounded,
                    iconColor: AppTheme.primary,
                    iconBgColor: AppTheme.primaryLight,
                  ),
                  StatCard(
                    title: 'TOTAL ATTENDEES',
                    value: '$totalRegistrations',
                    subtitle: '+12% registered this week',
                    icon: Icons.groups_rounded,
                    iconColor: AppTheme.accent,
                    iconBgColor: AppTheme.accentLight,
                  ),
                  StatCard(
                    title: 'CHECKED-IN NOW',
                    value: '$totalCheckedIn',
                    subtitle: totalRegistrations > 0
                        ? '${(totalCheckedIn / totalRegistrations * 100).toInt()}% overall turnout rate'
                        : '0% turnout',
                    icon: Icons.check_circle_rounded,
                    iconColor: AppTheme.success,
                    iconBgColor: AppTheme.successLight,
                  ),
                  StatCard(
                    title: 'ANNOUNCEMENTS',
                    value: '${announcements.length}',
                    subtitle: 'Broadcast alerts sent out',
                    icon: Icons.campaign_rounded,
                    iconColor: AppTheme.warning,
                    iconBgColor: AppTheme.warningLight,
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 32),

          // Quick Action Banner
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF4338CA), Color(0xFF6366F1)],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.bolt_rounded,
                      color: Colors.white, size: 28),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        'Live Event Mode is Active',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Fast badge scanning and urgent announcement dispatching are ready to use.',
                        style: TextStyle(color: Colors.white70, fontSize: 13),
                      ),
                    ],
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (ctx) => SendAnnouncementDialog(
                        events: events,
                        onAnnouncementSent: onAnnouncementSent,
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: AppTheme.primaryDark,
                  ),
                  icon: const Icon(Icons.campaign, size: 18),
                  label: const Text('Broadcast Alert'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),

          // Active Events List and Recent Activity in 2 Columns (Responsive)
          LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth > 900) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 3, child: _buildActiveEventsSection(context)),
                    const SizedBox(width: 24),
                    Expanded(flex: 2, child: _buildRecentAnnouncementsSection(context)),
                  ],
                );
              } else {
                return Column(
                  children: [
                    _buildActiveEventsSection(context),
                    const SizedBox(height: 24),
                    _buildRecentAnnouncementsSection(context),
                  ],
                );
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildActiveEventsSection(BuildContext context) {
    return Container(
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
                'Featured & Active Events',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
              ),
              TextButton(
                onPressed: () => onNavigateToTab(1),
                child: const Text('View All'),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: events.take(3).length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final event = events[index];
              return Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.background,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.cardBorder),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: AppTheme.primaryLight,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.event_note, color: AppTheme.primary),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  event.title,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                    color: AppTheme.textPrimary,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: event.status == 'Live'
                                      ? AppTheme.successLight
                                      : AppTheme.cardBorder,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  event.status,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: event.status == 'Live'
                                        ? AppTheme.success
                                        : AppTheme.textSecondary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${event.date} • ${event.location}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppTheme.textSecondary,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Text(
                                '${event.registeredCount}/${event.totalCapacity} Attendees',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.primary,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Text(
                                '${event.checkedInCount} Checked In',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppTheme.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => EventDetailsView(
                              event: event,
                              attendees: attendees,
                              schedules: schedules,
                              announcements: announcements,
                              onDataChanged: onDataChanged,
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildRecentAnnouncementsSection(BuildContext context) {
    return Container(
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
                'Recent Broadcasts',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
              ),
              TextButton(
                onPressed: () => onNavigateToTab(3),
                child: const Text('View All'),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: announcements.take(3).length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final ann = announcements[index];
              return Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: ann.priority == 'Urgent'
                      ? AppTheme.dangerLight.withValues(alpha: 0.5)
                      : AppTheme.background,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: ann.priority == 'Urgent'
                        ? AppTheme.danger.withValues(alpha: 0.3)
                        : AppTheme.cardBorder,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          ann.priority.toUpperCase(),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: ann.priority == 'Urgent'
                                ? AppTheme.danger
                                : AppTheme.accent,
                          ),
                        ),
                        Text(
                          ann.timestamp,
                          style: const TextStyle(
                              fontSize: 11, color: AppTheme.textMuted),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      ann.title,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      ann.message,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
