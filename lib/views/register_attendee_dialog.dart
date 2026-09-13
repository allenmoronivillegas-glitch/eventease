import 'package:flutter/material.dart';
import '../models/event_model.dart';
import '../theme/app_theme.dart';

class RegisterAttendeeDialog extends StatefulWidget {
  final List<EventItem> events;
  final String? initialEventId;
  final Function(AttendeeItem) onAttendeeRegistered;

  const RegisterAttendeeDialog({
    super.key,
    required this.events,
    this.initialEventId,
    required this.onAttendeeRegistered,
  });

  @override
  State<RegisterAttendeeDialog> createState() => _RegisterAttendeeDialogState();
}

class _RegisterAttendeeDialogState extends State<RegisterAttendeeDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();

  late String _selectedEventId;
  String _selectedTicket = 'General';

  final List<String> _ticketTypes = ['General', 'VIP', 'Speaker', 'Student'];

  @override
  void initState() {
    super.initState();
    _selectedEventId = widget.initialEventId ??
        (widget.events.isNotEmpty ? widget.events.first.id : '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  void _submit() {
    if (_formKey.currentState!.validate()) {
      final newAttendee = AttendeeItem(
        id: 'ATT-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}',
        eventId: _selectedEventId,
        name: _nameController.text.trim(),
        email: _emailController.text.trim(),
        phone: _phoneController.text.trim(),
        ticketType: _selectedTicket,
        registeredDate: 'Today',
        isCheckedIn: false,
      );

      widget.onAttendeeRegistered(newAttendee);
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Registered "${newAttendee.name}" successfully!'),
          backgroundColor: AppTheme.success,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Padding(
          padding: const EdgeInsets.all(28.0),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryLight,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.person_add_alt_1_rounded,
                              color: AppTheme.primary),
                        ),
                        const SizedBox(width: 12),
                        const Text(
                          'Register Attendee',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: AppTheme.textSecondary),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                const Text(
                  'Issue a new badge and register attendee into EventEase system.',
                  style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
                ),
                const Divider(height: 28, color: AppTheme.cardBorder),
                const Text('Select Event *',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                const SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  initialValue: _selectedEventId.isNotEmpty ? _selectedEventId : null,
                  items: widget.events
                      .map((e) => DropdownMenuItem(
                            value: e.id,
                            child: Text(e.title, overflow: TextOverflow.ellipsis),
                          ))
                      .toList(),
                  onChanged: (val) {
                    if (val != null) setState(() => _selectedEventId = val);
                  },
                  decoration: const InputDecoration(),
                ),
                const SizedBox(height: 16),
                const Text('Full Name *',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    hintText: 'e.g. Jessica Taylor',
                    prefixIcon: Icon(Icons.badge_outlined, size: 18),
                  ),
                  validator: (v) =>
                      v == null || v.isEmpty ? 'Attendee name is required' : null,
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Email Address *',
                              style: TextStyle(
                                  fontWeight: FontWeight.w600, fontSize: 13)),
                          const SizedBox(height: 6),
                          TextFormField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            decoration: const InputDecoration(
                              hintText: 'name@company.com',
                              prefixIcon: Icon(Icons.email_outlined, size: 18),
                            ),
                            validator: (v) =>
                                v == null || !v.contains('@') ? 'Valid email required' : null,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Ticket Pass',
                              style: TextStyle(
                                  fontWeight: FontWeight.w600, fontSize: 13)),
                          const SizedBox(height: 6),
                          DropdownButtonFormField<String>(
                            initialValue: _selectedTicket,
                            items: _ticketTypes
                                .map((t) => DropdownMenuItem(
                                      value: t,
                                      child: Text(t),
                                    ))
                                .toList(),
                            onChanged: (val) =>
                                setState(() => _selectedTicket = val!),
                            decoration: const InputDecoration(),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Text('Contact Phone',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    hintText: '+1 (555) 000-0000',
                    prefixIcon: Icon(Icons.phone_outlined, size: 18),
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      onPressed: _submit,
                      icon: const Icon(Icons.person_add_rounded, size: 18),
                      label: const Text('Confirm Registration'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
