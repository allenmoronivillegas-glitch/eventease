import 'package:flutter/material.dart';
import '../models/event_model.dart';
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
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
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
                  color: Colors.white,
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
              color: Colors.white,
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
                        const Divider(height: 1, color: AppTheme.cardBorder),
                    itemBuilder: (context, index) {
                      final att = filtered[index];
                      final event = widget.events
                          .cast<EventItem?>()
                          .firstWhere((e) => e?.id == att.eventId, orElse: () => null);

                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 8),
                        leading: CircleAvatar(
                          radius: 20,
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
                            Expanded(
                              child: Text(
                                att.name,
                                style: const TextStyle(
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
                                  horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: att.ticketType == 'VIP'
                                    ? const Color(0xFFFEF3C7)
                                    : AppTheme.background,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                att.ticketType,
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: att.ticketType == 'VIP'
                                      ? const Color(0xFFD97706)
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
                        trailing: IconButton(
                          onPressed: () => widget.onAttendeeCheckInToggled(att),
                          icon: Icon(
                            att.isCheckedIn
                                ? Icons.check_circle
                                : Icons.radio_button_unchecked,
                            color: att.isCheckedIn ? AppTheme.success : AppTheme.primary,
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
