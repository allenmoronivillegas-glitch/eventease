import 'package:flutter/material.dart';
import '../models/event_model.dart';
import '../theme/app_theme.dart';
import 'send_announcement_dialog.dart';

class AnnouncementsView extends StatefulWidget {
  final List<AnnouncementItem> announcements;
  final List<EventItem> events;
  final Function(AnnouncementItem) onAnnouncementSent;

  const AnnouncementsView({
    super.key,
    required this.announcements,
    required this.events,
    required this.onAnnouncementSent,
  });

  @override
  State<AnnouncementsView> createState() => _AnnouncementsViewState();
}

class _AnnouncementsViewState extends State<AnnouncementsView> {
  String _selectedEventFilter = 'All';

  @override
  Widget build(BuildContext context) {
    final filtered = widget.announcements.where((a) {
      if (_selectedEventFilter == 'All') return true;
      return a.eventId == _selectedEventFilter;
    }).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Broadcasts',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Instantly update your attendees.',
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
                    builder: (ctx) => SendAnnouncementDialog(
                      events: widget.events,
                      onAnnouncementSent: (ann) {
                        widget.onAnnouncementSent(ann);
                        setState(() {});
                      },
                    ),
                  );
                },
                child: const Icon(Icons.campaign_rounded, size: 20),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Event selector filter
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.cardBorder),
            ),
            child: Row(
              children: [
                const Icon(Icons.filter_list_rounded,
                    color: AppTheme.textSecondary, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButton<String>(
                    isExpanded: true,
                    underline: const SizedBox(),
                    value: _selectedEventFilter,
                    items: [
                      const DropdownMenuItem(
                          value: 'All', child: Text('All Events')),
                      ...widget.events.map((e) => DropdownMenuItem(
                            value: e.id,
                            child: Text(e.title, overflow: TextOverflow.ellipsis),
                          )),
                    ],
                    onChanged: (val) {
                      if (val != null) setState(() => _selectedEventFilter = val);
                    },
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Announcement cards
          if (filtered.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(48),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.cardBorder),
              ),
              child: Column(
                children: [
                  Icon(Icons.campaign_outlined, size: 50, color: AppTheme.textMuted),
                  const SizedBox(height: 12),
                  const Text('No broadcasts found.',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ],
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: filtered.length,
              separatorBuilder: (_, _) => const SizedBox(height: 16),
              itemBuilder: (context, index) {
                final ann = filtered[index];
                final isUrgent = ann.priority == 'Urgent';
                final event = widget.events
                    .cast<EventItem?>()
                    .firstWhere((e) => e?.id == ann.eventId, orElse: () => null);

                return Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isUrgent
                          ? AppTheme.danger.withValues(alpha: 0.4)
                          : AppTheme.cardBorder,
                      width: isUrgent ? 1.5 : 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: isUrgent
                            ? AppTheme.danger.withValues(alpha: 0.05)
                            : Colors.black.withValues(alpha: 0.02),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        alignment: WrapAlignment.spaceBetween,
                        spacing: 12,
                        runSpacing: 8,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: isUrgent
                                      ? AppTheme.dangerLight
                                      : ann.priority == 'Update'
                                          ? AppTheme.primaryLight
                                          : AppTheme.accentLight,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  ann.priority.toUpperCase(),
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: isUrgent
                                        ? AppTheme.danger
                                        : ann.priority == 'Update'
                                            ? AppTheme.primary
                                            : AppTheme.accent,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Target: ${ann.sentTo}',
                                style: const TextStyle(
                                    fontSize: 12,
                                    color: AppTheme.textSecondary),
                              ),
                            ],
                          ),
                          Text(
                            ann.timestamp,
                            style: const TextStyle(
                                fontSize: 12, color: AppTheme.textMuted),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        ann.title,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        ann.message,
                        style: const TextStyle(
                          fontSize: 14,
                          color: AppTheme.textSecondary,
                          height: 1.45,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          const Icon(Icons.event, size: 14, color: AppTheme.textMuted),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              event?.title ?? 'General Announcement',
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppTheme.textSecondary,
                                fontWeight: FontWeight.w500,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
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
