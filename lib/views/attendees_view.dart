import 'package:flutter/material.dart';

import '../models/event_model.dart';
import '../services/firestore_service.dart';
import '../theme/app_theme.dart';
import 'register_attendee_dialog.dart';

class AttendeesView extends StatefulWidget {
  final List<AttendeeItem> attendees;
  final List<EventItem> events;
  final Function(AttendeeItem) onAttendeeRegistered;
  final Function(AttendeeItem) onAttendeeCheckInToggled;
  final VoidCallback onDataChanged;

  const AttendeesView({
    super.key,
    required this.attendees,
    required this.events,
    required this.onAttendeeRegistered,
    required this.onAttendeeCheckInToggled,
    required this.onDataChanged,
  });

  @override
  State<AttendeesView> createState() => _AttendeesViewState();
}

class _AttendeesViewState extends State<AttendeesView> {
  String _searchQuery = '';
  String _filterTicket = 'All';
  String _filterStatus = 'All';
  final FirestoreService _firestoreService = FirestoreService();
  final Set<String> _deletingAttendeeIds = {};

  Future<void> _deleteAttendee(AttendeeItem attendee) async {
    if (_deletingAttendeeIds.contains(attendee.id)) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete Attendee?'),
        content: Text(
          'Delete ${attendee.name} (${attendee.email}) from this event?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Delete Attendee'),
          ),
        ],
      ),
    );

    if (confirmed != true ||
        !mounted ||
        _deletingAttendeeIds.contains(attendee.id)) {
      return;
    }
    setState(() => _deletingAttendeeIds.add(attendee.id));

    try {
      await _firestoreService.deleteAttendee(attendee.id);
      if (!mounted) return;
      widget.onDataChanged();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('${attendee.name} was deleted.')));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not delete attendee: $error')),
      );
    } finally {
      if (mounted) setState(() => _deletingAttendeeIds.remove(attendee.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = widget.attendees.where((att) {
      final matchesSearch =
          att.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          att.email.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          att.id.toLowerCase().contains(_searchQuery.toLowerCase());
      final matchesTicket =
          _filterTicket == 'All' || att.ticketType == _filterTicket;
      final matchesStatus =
          _filterStatus == 'All' ||
          (_filterStatus == 'Checked In' && att.isCheckedIn) ||
          (_filterStatus == 'Pending' && !att.isCheckedIn);
      return matchesSearch && matchesTicket && matchesStatus;
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
                      'Attendees',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Manage your registrations.',
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
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (ctx) => RegisterAttendeeDialog(
                      events: widget.events,
                      onAttendeeRegistered: widget.onAttendeeRegistered,
                    ),
                  );
                },
                child: const Icon(Icons.person_add_alt_1_rounded, size: 20),
              ),
            ],
          ),
          const SizedBox(height: 24),

          LayoutBuilder(
            builder: (context, constraints) {
              final bool isNarrow = constraints.maxWidth < 650;
              final bool isExtraNarrow = constraints.maxWidth < 400;

              final searchField = TextField(
                decoration: const InputDecoration(
                  hintText: 'Search attendee...',
                  prefixIcon: Icon(Icons.search, size: 20),
                ),
                onChanged: (val) => setState(() => _searchQuery = val),
              );

              final tierDropdown = DropdownButtonFormField<String>(
                initialValue: _filterTicket,
                items: ['All', 'VIP', 'General', 'Speaker', 'Student']
                    .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                    .toList(),
                onChanged: (val) {
                  if (val != null) setState(() => _filterTicket = val);
                },
                decoration: const InputDecoration(labelText: 'Tier'),
              );

              final statusDropdown = DropdownButtonFormField<String>(
                initialValue: _filterStatus,
                items: ['All', 'Checked In', 'Pending']
                    .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                    .toList(),
                onChanged: (val) {
                  if (val != null) setState(() => _filterStatus = val);
                },
                decoration: const InputDecoration(labelText: 'Status'),
              );

              return Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppTheme.cardBorder),
                ),
                child: isNarrow
                    ? Column(
                        children: [
                          searchField,
                          const SizedBox(height: 12),
                          isExtraNarrow
                              ? Column(
                                  children: [
                                    tierDropdown,
                                    const SizedBox(height: 12),
                                    statusDropdown,
                                  ],
                                )
                              : Row(
                                  children: [
                                    Expanded(child: tierDropdown),
                                    const SizedBox(width: 12),
                                    Expanded(child: statusDropdown),
                                  ],
                                ),
                        ],
                      )
                    : Row(
                        children: [
                          Expanded(flex: 3, child: searchField),
                          const SizedBox(width: 14),
                          Expanded(flex: 1, child: tierDropdown),
                          const SizedBox(width: 14),
                          Expanded(flex: 1, child: statusDropdown),
                        ],
                      ),
              );
            },
          ),
          const SizedBox(height: 24),

          // Attendees List
          Container(
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.cardBorder),
            ),
            child: filtered.isEmpty
                ? const Padding(
                    padding: EdgeInsets.all(48.0),
                    child: Center(child: Text('No results.')),
                  )
                : ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: filtered.length,
                    separatorBuilder: (_, _) =>
                        Divider(height: 1, color: AppTheme.cardBorder),
                    itemBuilder: (context, index) {
                      final att = filtered[index];
                      final event = widget.events.cast<EventItem?>().firstWhere(
                        (e) => e?.id == att.eventId,
                        orElse: () => null,
                      );

                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 8,
                        ),
                        leading: CircleAvatar(
                          radius: 20,
                          backgroundColor: AppTheme.primaryLight,
                          child: Text(
                            att.name.isNotEmpty ? att.name[0] : '?',
                            style: TextStyle(
                              color: AppTheme.primary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        title: Row(
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
                                    ? AppTheme.warningLight
                                    : AppTheme.background,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                att.ticketType,
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: att.ticketType == 'VIP'
                                      ? AppTheme.warning
                                      : AppTheme.textSecondary,
                                ),
                              ),
                            ),
                          ],
                        ),
                        subtitle: Text(
                          '${att.email} • ${event?.title ?? ""}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 12),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              tooltip: att.isCheckedIn
                                  ? 'Check out'
                                  : 'Check in',
                              onPressed: () =>
                                  widget.onAttendeeCheckInToggled(att),
                              icon: Icon(
                                att.isCheckedIn
                                    ? Icons.check_circle
                                    : Icons.radio_button_unchecked,
                                color: att.isCheckedIn
                                    ? AppTheme.success
                                    : AppTheme.primary,
                              ),
                            ),
                            IconButton(
                              tooltip: 'Delete attendee',
                              onPressed: _deletingAttendeeIds.contains(att.id)
                                  ? null
                                  : () => _deleteAttendee(att),
                              icon: _deletingAttendeeIds.contains(att.id)
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(Icons.delete_outline),
                              color: AppTheme.danger,
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
