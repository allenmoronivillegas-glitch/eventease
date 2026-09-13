import 'package:flutter/material.dart';
import '../data/mock_data.dart';
import '../models/event_model.dart';
import '../theme/app_theme.dart';
import 'register_attendee_dialog.dart';

class AttendeesView extends StatefulWidget {
  final List<AttendeeItem> attendees;
  final List<EventItem> events;
  final Function(AttendeeItem) onAttendeeRegistered;
  final VoidCallback onDataChanged;

  const AttendeesView({
    super.key,
    required this.attendees,
    required this.events,
    required this.onAttendeeRegistered,
    required this.onDataChanged,
  });

  @override
  State<AttendeesView> createState() => _AttendeesViewState();
}

class _AttendeesViewState extends State<AttendeesView> {
  String _searchQuery = '';
  String _filterTicket = 'All';
  String _filterStatus = 'All'; // 'All', 'Checked In', 'Pending'

  @override
  Widget build(BuildContext context) {
    final filtered = widget.attendees.where((att) {
      final matchesSearch =
          att.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
              att.email.toLowerCase().contains(_searchQuery.toLowerCase()) ||
              att.id.toLowerCase().contains(_searchQuery.toLowerCase());
      final matchesTicket =
          _filterTicket == 'All' || att.ticketType == _filterTicket;
      final matchesStatus = _filterStatus == 'All' ||
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
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Attendee Registry & Badging',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Search attendees, verify registration credentials, and perform on-site check-in.',
                    style: TextStyle(fontSize: 14, color: AppTheme.textSecondary),
                  ),
                ],
              ),
              ElevatedButton.icon(
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (ctx) => RegisterAttendeeDialog(
                      events: widget.events,
                      onAttendeeRegistered: widget.onAttendeeRegistered,
                    ),
                  );
                },
                icon: const Icon(Icons.person_add_alt_1_rounded, size: 18),
                label: const Text('Register Attendee'),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Filters Bar
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.cardBorder),
            ),
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: TextField(
                    decoration: const InputDecoration(
                      hintText: 'Search by attendee name, email, or badge ID...',
                      prefixIcon: Icon(Icons.search, size: 20),
                    ),
                    onChanged: (val) => setState(() => _searchQuery = val),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  flex: 1,
                  child: DropdownButtonFormField<String>(
                    initialValue: _filterTicket,
                    items: ['All', 'VIP', 'General', 'Speaker', 'Student']
                        .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                        .toList(),
                    onChanged: (val) {
                      if (val != null) setState(() => _filterTicket = val);
                    },
                    decoration: const InputDecoration(
                      labelText: 'Pass Tier',
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  flex: 1,
                  child: DropdownButtonFormField<String>(
                    initialValue: _filterStatus,
                    items: ['All', 'Checked In', 'Pending']
                        .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                        .toList(),
                    onChanged: (val) {
                      if (val != null) setState(() => _filterStatus = val);
                    },
                    decoration: const InputDecoration(
                      labelText: 'Status',
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Attendees List Table / Card
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.cardBorder),
            ),
            child: filtered.isEmpty
                ? const Padding(
                    padding: EdgeInsets.all(48.0),
                    child: Center(
                      child: Text(
                        'No attendees match the criteria.',
                        style: TextStyle(color: AppTheme.textSecondary),
                      ),
                    ),
                  )
                : ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: filtered.length,
                    separatorBuilder: (_, _) =>
                        const Divider(height: 1, color: AppTheme.cardBorder),
                    itemBuilder: (context, index) {
                      final att = filtered[index];
                      final event = widget.events
                          .cast<EventItem?>()
                          .firstWhere((e) => e?.id == att.eventId, orElse: () => null);

                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 12),
                        leading: CircleAvatar(
                          radius: 22,
                          backgroundColor: AppTheme.primaryLight,
                          child: Text(
                            att.name.isNotEmpty ? att.name[0] : '?',
                            style: const TextStyle(
                              color: AppTheme.primary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        title: Row(
                          children: [
                            Text(
                              att.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                                color: AppTheme.textPrimary,
                              ),
                            ),
                            const SizedBox(width: 10),
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
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 4.0),
                          child: Row(
                            children: [
                              Text(
                                att.email,
                                style: const TextStyle(
                                    fontSize: 12, color: AppTheme.textSecondary),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                '•   Event: ${event?.title ?? "General"}',
                                style: const TextStyle(
                                    fontSize: 12, color: AppTheme.textMuted),
                              ),
                            ],
                          ),
                        ),
                        trailing: ElevatedButton.icon(
                          onPressed: () {
                            setState(() {
                              att.isCheckedIn = !att.isCheckedIn;
                              final increment = att.isCheckedIn ? 1 : -1;
                              
                              // update event check-in count in mock data
                              final index = MockData.events.indexWhere((e) => e.id == att.eventId);
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
                                horizontal: 16, vertical: 10),
                          ),
                          icon: Icon(
                            att.isCheckedIn
                                ? Icons.check_circle
                                : Icons.radio_button_unchecked,
                            size: 16,
                          ),
                          label: Text(
                            att.isCheckedIn ? 'Checked In' : 'Mark Check-In',
                            style: const TextStyle(fontSize: 12),
                          ),
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
