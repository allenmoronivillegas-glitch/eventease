import 'package:flutter/material.dart';
import '../models/event_model.dart';
import '../theme/app_theme.dart';

class SendAnnouncementDialog extends StatefulWidget {
  final List<EventItem> events;
  final String? initialEventId;
  final Function(AnnouncementItem) onAnnouncementSent;

  const SendAnnouncementDialog({
    super.key,
    required this.events,
    this.initialEventId,
    required this.onAnnouncementSent,
  });

  @override
  State<SendAnnouncementDialog> createState() => _SendAnnouncementDialogState();
}

class _SendAnnouncementDialogState extends State<SendAnnouncementDialog> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _messageController = TextEditingController();

  late String _selectedEventId;
  String _priority = 'Normal';
  String _recipientGroup = 'All Attendees';

  final List<String> _priorities = ['Normal', 'Urgent', 'Update'];
  final List<String> _audiences = [
    'All Attendees',
    'VIP Only',
    'Speakers & Staff',
    'Checked-In Only',
  ];

  @override
  void initState() {
    super.initState();
    _selectedEventId = widget.initialEventId ??
        (widget.events.isNotEmpty ? widget.events.first.id : '');
  }

  @override
  void dispose() {
    _titleController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  void _submit() {
    if (_formKey.currentState!.validate()) {
      final announcement = AnnouncementItem(
        id: 'ANN-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}',
        eventId: _selectedEventId,
        title: _titleController.text.trim(),
        message: _messageController.text.trim(),
        timestamp: 'Just now',
        priority: _priority,
        sentTo: _recipientGroup,
      );

      widget.onAnnouncementSent(announcement);
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Broadcast sent to $_recipientGroup!'),
          backgroundColor: _priority == 'Urgent' ? AppTheme.danger : AppTheme.primary,
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
        constraints: const BoxConstraints(maxWidth: 540),
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
                            color: AppTheme.accentLight,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.campaign_rounded,
                              color: AppTheme.accent),
                        ),
                        const SizedBox(width: 12),
                        const Text(
                          'Broadcast Announcement',
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
                  'Instantly broadcast push notifications & email updates to event participants.',
                  style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
                ),
                const Divider(height: 28, color: AppTheme.cardBorder),
                const Text('Event Destination *',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                const SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  value: _selectedEventId.isNotEmpty ? _selectedEventId : null,
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
                LayoutBuilder(
                  builder: (context, constraints) {
                    final bool isNarrow = constraints.maxWidth < 400;
                    final targetField = Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Audience Target',
                            style: TextStyle(
                                fontWeight: FontWeight.w600, fontSize: 13)),
                        const SizedBox(height: 6),
                        DropdownButtonFormField<String>(
                          value: _recipientGroup,
                          items: _audiences
                              .map((a) => DropdownMenuItem(
                                    value: a,
                                    child: Text(a),
                                  ))
                              .toList(),
                          onChanged: (val) =>
                              setState(() => _recipientGroup = val!),
                          decoration: const InputDecoration(),
                        ),
                      ],
                    );

                    final priorityField = Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Priority Level',
                            style: TextStyle(
                                fontWeight: FontWeight.w600, fontSize: 13)),
                        const SizedBox(height: 6),
                        DropdownButtonFormField<String>(
                          value: _priority,
                          items: _priorities
                              .map((p) => DropdownMenuItem(
                                    value: p,
                                    child: Text(p),
                                  ))
                              .toList(),
                          onChanged: (val) => setState(() => _priority = val!),
                          decoration: const InputDecoration(),
                        ),
                      ],
                    );

                    if (isNarrow) {
                      return Column(
                        children: [
                          targetField,
                          const SizedBox(height: 16),
                          priorityField,
                        ],
                      );
                    }
                    return Row(
                      children: [
                        Expanded(child: targetField),
                        const SizedBox(width: 14),
                        Expanded(child: priorityField),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 16),
                const Text('Headline / Title *',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _titleController,
                  decoration: const InputDecoration(
                    hintText: 'e.g. Schedule Update: Hall B Keynote delayed 15 mins',
                    prefixIcon: Icon(Icons.title_rounded, size: 18),
                  ),
                  validator: (v) =>
                      v == null || v.isEmpty ? 'Title is required' : null,
                ),
                const SizedBox(height: 16),
                const Text('Message Details *',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _messageController,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    hintText: 'Enter announcement content for attendees...',
                  ),
                  validator: (v) =>
                      v == null || v.isEmpty ? 'Message is required' : null,
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
                      icon: const Icon(Icons.send_rounded, size: 18),
                      label: const Text('Broadcast Now'),
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
