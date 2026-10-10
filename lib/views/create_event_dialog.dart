import 'package:flutter/material.dart';

import '../models/event_model.dart';
import '../theme/app_theme.dart';

class CreateEventDialog extends StatefulWidget {
  final Function(EventItem) onEventCreated;

  const CreateEventDialog({super.key, required this.onEventCreated});

  @override
  State<CreateEventDialog> createState() => _CreateEventDialogState();
}

class _CreateEventDialogState extends State<CreateEventDialog> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  final _locationController = TextEditingController();
  final _dateController = TextEditingController(text: 'Dec 15, 2026');
  final _timeController = TextEditingController(text: '10:00 AM - 04:00 PM');
  final _capacityController = TextEditingController(text: '300');
  final _priceController = TextEditingController(text: '0.00');

  String _selectedCategory = 'Technology';
  bool _isVirtual = false;

  final List<String> _categories = [
    'Technology',
    'Design',
    'Business',
    'Developer',
    'Workshop',
    'Networking',
  ];

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    _locationController.dispose();
    _dateController.dispose();
    _timeController.dispose();
    _capacityController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  void _submit() {
    if (_formKey.currentState!.validate()) {
      final newEvent = EventItem(
        id: 'EVT-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}',
        title: _titleController.text.trim(),
        description: _descController.text.trim(),
        category: _selectedCategory,
        date: _dateController.text.trim(),
        time: _timeController.text.trim(),
        location: _locationController.text.trim(),
        isVirtual: _isVirtual,
        totalCapacity: int.tryParse(_capacityController.text.trim()) ?? 100,
        registeredCount: 0,
        checkedInCount: 0,
        ticketPrice: double.tryParse(_priceController.text.trim()) ?? 0.0,
        bannerImageUrl:
            'https://picsum.photos/seed/${_titleController.text.hashCode}/900/400',
        status: 'Upcoming',
      );

      widget.onEventCreated(newEvent);
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Event "${newEvent.title}" created successfully!'),
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
      backgroundColor: AppTheme.surface,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600, maxHeight: 750),
        child: Padding(
          padding: const EdgeInsets.all(28.0),
          child: Form(
            key: _formKey,
            child: Column(
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
                          child: Icon(
                            Icons.add_box_rounded,
                            color: AppTheme.primary,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Create New Event',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: Icon(Icons.close, color: AppTheme.textSecondary),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Fill in the details to publish your event to the attendee portal.',
                  style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
                ),
                Divider(height: 28, color: AppTheme.cardBorder),
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Event Title *',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _titleController,
                          decoration: const InputDecoration(
                            hintText: 'e.g. AI & Cloud Architecture Summit',
                          ),
                          validator: (v) => v == null || v.isEmpty
                              ? 'Title is required'
                              : null,
                        ),
                        const SizedBox(height: 16),
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final bool isNarrow = constraints.maxWidth < 400;
                            final categoryField = Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Category',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                DropdownButtonFormField<String>(
                                  initialValue: _selectedCategory,
                                  items: _categories
                                      .map(
                                        (c) => DropdownMenuItem(
                                          value: c,
                                          child: Text(c),
                                        ),
                                      )
                                      .toList(),
                                  onChanged: (val) =>
                                      setState(() => _selectedCategory = val!),
                                  decoration: const InputDecoration(),
                                ),
                              ],
                            );

                            final capacityField = Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Capacity *',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                TextFormField(
                                  controller: _capacityController,
                                  keyboardType: TextInputType.number,
                                  decoration: const InputDecoration(
                                    hintText: 'e.g. 500',
                                  ),
                                  validator: (v) => v == null || v.isEmpty
                                      ? 'Required'
                                      : null,
                                ),
                              ],
                            );

                            if (isNarrow) {
                              return Column(
                                children: [
                                  categoryField,
                                  const SizedBox(height: 16),
                                  capacityField,
                                ],
                              );
                            }
                            return Row(
                              children: [
                                Expanded(child: categoryField),
                                const SizedBox(width: 16),
                                Expanded(child: capacityField),
                              ],
                            );
                          },
                        ),
                        const SizedBox(height: 16),
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final bool isNarrow = constraints.maxWidth < 400;
                            final dateField = Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Date *',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                TextFormField(
                                  controller: _dateController,
                                  decoration: const InputDecoration(
                                    hintText: 'e.g. Oct 24, 2026',
                                    prefixIcon: Icon(
                                      Icons.calendar_today,
                                      size: 18,
                                    ),
                                  ),
                                ),
                              ],
                            );

                            final timeField = Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Time *',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                TextFormField(
                                  controller: _timeController,
                                  decoration: const InputDecoration(
                                    hintText: 'e.g. 09:00 AM - 05:00 PM',
                                    prefixIcon: Icon(
                                      Icons.access_time,
                                      size: 18,
                                    ),
                                  ),
                                ),
                              ],
                            );

                            if (isNarrow) {
                              return Column(
                                children: [
                                  dateField,
                                  const SizedBox(height: 16),
                                  timeField,
                                ],
                              );
                            }
                            return Row(
                              children: [
                                Expanded(child: dateField),
                                const SizedBox(width: 16),
                                Expanded(child: timeField),
                              ],
                            );
                          },
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Location / Venue *',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _locationController,
                          decoration: const InputDecoration(
                            hintText: 'e.g. Moscone Center, San Francisco or Virtual Link',
                            prefixIcon: Icon(
                              Icons.location_on_outlined,
                              size: 18,
                            ),
                          ),
                          validator: (v) => v == null || v.isEmpty
                              ? 'Location is required'
                              : null,
                        ),
                        const SizedBox(height: 14),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text(
                            'Is this a virtual or hybrid event?',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          value: _isVirtual,
                          activeThumbColor: AppTheme.primary,
                          onChanged: (val) => setState(() => _isVirtual = val),
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          'Description',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _descController,
                          maxLines: 3,
                          decoration: const InputDecoration(
                            hintText: 'Describe the key highlights, target audience, agenda...',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
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
                      icon: const Icon(Icons.check, size: 18),
                      label: const Text('Publish Event'),
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
