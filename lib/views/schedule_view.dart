import 'package:flutter/material.dart';

import '../models/event_model.dart';
import '../theme/app_theme.dart';
import '../services/firestore_service.dart';

class ScheduleView extends StatefulWidget {
  final List<ScheduleItem> schedules;
  final List<EventItem> events;
  final VoidCallback onDataChanged;

  const ScheduleView({
    super.key,
    required this.schedules,
    required this.events,
    required this.onDataChanged,
  });

  @override
  State<ScheduleView> createState() => _ScheduleViewState();
}

class _ScheduleViewState extends State<ScheduleView> {
  String _selectedEventId = 'All';
  final FirestoreService _firestoreService = FirestoreService();
  final Set<String> _deletingScheduleIds = {};

  void _addNewSession() {
    final titleCtrl = TextEditingController();
    final timeCtrl = TextEditingController(text: '01:00 PM - 02:00 PM');
    final speakerCtrl = TextEditingController();
    final roomCtrl = TextEditingController(text: 'Auditorium 1');
    final tagCtrl = TextEditingController(text: 'Keynote');
    String selectedEvent = widget.events.isNotEmpty
        ? widget.events.first.id
        : '';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text('Add Agenda Session'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Associated Event *',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                ),
                const SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  initialValue: selectedEvent.isNotEmpty ? selectedEvent : null,
                  items: widget.events
                      .map(
                        (e) => DropdownMenuItem(
                          value: e.id,
                          child: Text(e.title, overflow: TextOverflow.ellipsis),
                        ),
                      )
                      .toList(),
                  onChanged: (val) {
                    if (val != null) setDialogState(() => selectedEvent = val);
                  },
                ),
                const SizedBox(height: 12),
                const Text(
                  'Session Title *',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: titleCtrl,
                  decoration: const InputDecoration(
                    hintText: 'e.g. Keynote Speech',
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Time Slot *',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: timeCtrl,
                  decoration: const InputDecoration(
                    hintText: 'e.g. 10:00 AM - 11:00 AM',
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Speaker / Host',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: speakerCtrl,
                  decoration: const InputDecoration(hintText: 'e.g. John Doe'),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Room / Stage',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 6),
                          TextField(
                            controller: roomCtrl,
                            decoration: const InputDecoration(
                              hintText: 'Hall B',
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Track Tag',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 6),
                          TextField(
                            controller: tagCtrl,
                            decoration: const InputDecoration(
                              hintText: 'Tech Track',
                            ),
                          ),
                        ],
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
              onPressed: () async {
                if (titleCtrl.text.trim().isNotEmpty &&
                    selectedEvent.isNotEmpty) {
                  final schedule = ScheduleItem(
                    id: 'SCH-${DateTime.now().millisecondsSinceEpoch}',
                    eventId: selectedEvent,
                    time: timeCtrl.text.trim(),
                    title: titleCtrl.text.trim(),
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

                    if (!context.mounted) return;

                    Navigator.of(ctx).pop();

                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Schedule saved to Firebase successfully!',
                        ),
                      ),
                    );
                  } catch (e) {
                    if (!context.mounted) return;

                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Failed to save schedule: $e')),
                    );
                  }
                }
              },
              child: const Text('Add Session'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteSchedule(ScheduleItem schedule) async {
    if (_deletingScheduleIds.contains(schedule.id)) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete Schedule Session?'),
        content: Text('Permanently delete "${schedule.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Delete Session'),
          ),
        ],
      ),
    );

    if (confirmed != true ||
        !mounted ||
        _deletingScheduleIds.contains(schedule.id)) {
      return;
    }
    setState(() => _deletingScheduleIds.add(schedule.id));

    try {
      await _firestoreService.deleteSchedule(schedule.id);
      if (!mounted) return;
      widget.onDataChanged();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('"${schedule.title}" was deleted.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not delete schedule session: $error')),
      );
    } finally {
      if (mounted) setState(() => _deletingScheduleIds.remove(schedule.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = widget.schedules.where((s) {
      if (_selectedEventId == 'All') return true;
      return s.eventId == _selectedEventId;
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
                    Text(
                      'Master Schedule & Timeline',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Coordinate day-of sessions and tracks.',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton(
                onPressed: _addNewSession,
                child: const Icon(Icons.add_alarm_rounded, size: 20),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Event selector filter
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.cardBorder),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.calendar_month_outlined,
                  color: AppTheme.textSecondary,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButton<String>(
                    isExpanded: true,
                    underline: const SizedBox(),
                    value: _selectedEventId,
                    items: [
                      const DropdownMenuItem(
                        value: 'All',
                        child: Text('All Events Combined'),
                      ),
                      ...widget.events.map(
                        (e) => DropdownMenuItem(
                          value: e.id,
                          child: Text(e.title, overflow: TextOverflow.ellipsis),
                        ),
                      ),
                    ],
                    onChanged: (val) {
                      if (val != null) setState(() => _selectedEventId = val);
                    },
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Timeline / Session Cards
          if (filtered.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(48),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.cardBorder),
              ),
              child: Column(
                children: [
                  Icon(Icons.event_note, size: 50, color: AppTheme.textMuted),
                  const SizedBox(height: 12),
                  const Text(
                    'No sessions planned',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: filtered.length,
              separatorBuilder: (_, _) => const SizedBox(height: 14),
              itemBuilder: (context, index) {
                final s = filtered[index];
                final event = widget.events.cast<EventItem?>().firstWhere(
                  (e) => e?.id == s.eventId,
                  orElse: () => null,
                );

                return Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: AppTheme.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppTheme.cardBorder),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryLight,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          s.time,
                          style: TextStyle(
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
                                    s.title,
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: AppTheme.textPrimary,
                                    ),
                                  ),
                                ),
                                IconButton(
                                  tooltip: 'Delete schedule session',
                                  visualDensity: VisualDensity.compact,
                                  onPressed: _deletingScheduleIds.contains(s.id)
                                      ? null
                                      : () => _deleteSchedule(s),
                                  icon: _deletingScheduleIds.contains(s.id)
                                      ? const SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : const Icon(Icons.delete_outline),
                                  color: AppTheme.danger,
                                ),
                                const SizedBox(width: 4),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppTheme.background,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: AppTheme.cardBorder,
                                    ),
                                  ),
                                  child: Text(
                                    s.tag,
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: AppTheme.textSecondary,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 12,
                              runSpacing: 8,
                              children: [
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.person_pin_outlined,
                                      size: 16,
                                      color: AppTheme.textMuted,
                                    ),
                                    const SizedBox(width: 6),
                                    Flexible(
                                      child: Text(
                                        s.speakerName,
                                        style: TextStyle(
                                          fontSize: 13,
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
                                      Icons.location_on_outlined,
                                      size: 16,
                                      color: AppTheme.textMuted,
                                    ),
                                    const SizedBox(width: 4),
                                    Flexible(
                                      child: Text(
                                        s.roomOrTrack,
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: AppTheme.textSecondary,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            if (event != null) ...[
                              const SizedBox(height: 10),
                              Text(
                                'Event: ${event.title}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppTheme.textMuted,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ],
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
