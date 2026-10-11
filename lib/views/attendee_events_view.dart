import 'package:flutter/material.dart';

import '../models/event_model.dart';
import '../services/firestore_service.dart';
import '../theme/app_theme.dart';

class AttendeeEventsView extends StatefulWidget {
  final FirestoreService firestoreService;

  const AttendeeEventsView({super.key, required this.firestoreService});

  @override
  State<AttendeeEventsView> createState() => _AttendeeEventsViewState();
}

class _AttendeeEventsViewState extends State<AttendeeEventsView> {
  late Stream<List<EventItem>> _eventsStream;
  late Stream<Set<String>> _registrationIdsStream;

  @override
  void initState() {
    super.initState();
    _refreshStreams();
  }

  void _refreshStreams() {
    _eventsStream = widget.firestoreService.getPublishedEvents();
    _registrationIdsStream = widget.firestoreService
        .watchMyRegistrationEventIds();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<EventItem>>(
      stream: _eventsStream,
      builder: (context, eventsSnapshot) {
        if (eventsSnapshot.hasError) {
          return _status(
            icon: Icons.cloud_off_outlined,
            message: 'Could not load events. Check your connection and retry.',
            action: TextButton(
              onPressed: () => setState(_refreshStreams),
              child: const Text('Retry'),
            ),
          );
        }
        if (!eventsSnapshot.hasData) {
          return Center(
            child: CircularProgressIndicator(color: AppTheme.primary),
          );
        }
        final events = eventsSnapshot.data!;
        if (events.isEmpty) {
          return _status(
            icon: Icons.event_busy_outlined,
            message: 'No published events are available right now.',
          );
        }

        return StreamBuilder<Set<String>>(
          stream: _registrationIdsStream,
          builder: (context, registrationsSnapshot) {
            final registeredEventIds =
                registrationsSnapshot.data ?? const <String>{};
            return Column(
              children: [
                if (registrationsSnapshot.hasError)
                  MaterialBanner(
                    content: const Text(
                      'Registration status could not be loaded. Open an event '
                      'to retry before registering.',
                    ),
                    leading: const Icon(Icons.warning_amber_rounded),
                    actions: [
                      TextButton(
                        onPressed: () => setState(_refreshStreams),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: events.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final event = events[index];
                      final isRegistered = registeredEventIds.contains(
                        event.id,
                      );
                      return Card(
                        color: AppTheme.surface,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => AttendeeEventDetailsView(
                                event: event,
                                initialIsRegistered: isRegistered,
                                firestoreService: widget.firestoreService,
                              ),
                            ),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        event.title,
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleMedium
                                            ?.copyWith(
                                              fontWeight: FontWeight.bold,
                                              color: AppTheme.textPrimary,
                                            ),
                                      ),
                                    ),
                                    if (isRegistered)
                                      const Chip(
                                        avatar: Icon(
                                          Icons.check_circle_outline,
                                          size: 18,
                                        ),
                                        label: Text('Registered'),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                _eventInfo(
                                  Icons.calendar_today_outlined,
                                  '${event.date} · ${event.time}',
                                ),
                                const SizedBox(height: 5),
                                _eventInfo(
                                  Icons.location_on_outlined,
                                  event.location,
                                ),
                                if (event.description.isNotEmpty) ...[
                                  const SizedBox(height: 8),
                                  Text(
                                    event.description,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: AppTheme.textSecondary,
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 8),
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: TextButton(
                                    onPressed: () => Navigator.of(context).push(
                                      MaterialPageRoute<void>(
                                        builder: (_) =>
                                            AttendeeEventDetailsView(
                                              event: event,
                                              initialIsRegistered: isRegistered,
                                              firestoreService:
                                                  widget.firestoreService,
                                            ),
                                      ),
                                    ),
                                    child: const Text('View details'),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _status({
    required IconData icon,
    required String message,
    Widget? action,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 44, color: AppTheme.textMuted),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            ?action,
          ],
        ),
      ),
    );
  }

  Widget _eventInfo(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 17, color: AppTheme.textMuted),
        const SizedBox(width: 8),
        Expanded(
          child: Text(text, style: TextStyle(color: AppTheme.textSecondary)),
        ),
      ],
    );
  }
}

class AttendeeEventDetailsView extends StatefulWidget {
  final EventItem event;
  final bool initialIsRegistered;
  final FirestoreService firestoreService;

  const AttendeeEventDetailsView({
    super.key,
    required this.event,
    required this.initialIsRegistered,
    required this.firestoreService,
  });

  @override
  State<AttendeeEventDetailsView> createState() =>
      _AttendeeEventDetailsViewState();
}

class _AttendeeEventDetailsViewState extends State<AttendeeEventDetailsView> {
  late final Stream<Set<String>> _registrationIdsStream = widget
      .firestoreService
      .watchMyRegistrationEventIds();
  bool _isSaving = false;

  Future<void> _register() async {
    setState(() => _isSaving = true);
    try {
      final created = await widget.firestoreService.registerForEvent(
        widget.event.id,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            created
                ? 'You are registered for "${widget.event.title}".'
                : 'You are already registered for this event.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Registration failed: $error')));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _cancelRegistration() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Cancel registration?'),
        content: Text('Cancel your registration for "${widget.event.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Keep registration'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Cancel registration'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _isSaving = true);
    try {
      await widget.firestoreService.cancelEventRegistration(widget.event.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Your registration was cancelled.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not cancel registration: $error')),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final event = widget.event;
    return Scaffold(
      appBar: AppBar(title: const Text('Event details')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            event.title,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          _detail(Icons.calendar_today_outlined, event.date),
          _detail(Icons.schedule_outlined, event.time),
          _detail(Icons.location_on_outlined, event.location),
          _detail(
            Icons.confirmation_number_outlined,
            event.ticketPrice > 0
                ? '\$${event.ticketPrice.toStringAsFixed(2)}'
                : 'Free',
          ),
          const SizedBox(height: 20),
          Text(
            'About this event',
            style: Theme.of(context).textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            event.description.isEmpty
                ? 'No description provided.'
                : event.description,
            style: TextStyle(color: AppTheme.textSecondary, height: 1.5),
          ),
          const SizedBox(height: 28),
          StreamBuilder<Set<String>>(
            stream: _registrationIdsStream,
            builder: (context, snapshot) {
              final isRegistered = snapshot.hasData
                  ? snapshot.data!.contains(event.id)
                  : widget.initialIsRegistered;
              final canChangeRegistration =
                  snapshot.hasData && !snapshot.hasError && !_isSaving;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (snapshot.hasError)
                    const Padding(
                      padding: EdgeInsets.only(bottom: 12),
                      child: Text(
                        'Could not verify your registration status. Retry the '
                        'event list before changing your registration.',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  FilledButton.icon(
                    onPressed: !canChangeRegistration
                        ? null
                        : isRegistered
                        ? _cancelRegistration
                        : _register,
                    icon: _isSaving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Icon(
                            isRegistered
                                ? Icons.event_busy_outlined
                                : Icons.app_registration_outlined,
                          ),
                    label: Text(
                      isRegistered ? 'Cancel registration' : 'Register',
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _detail(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, color: AppTheme.primary),
          const SizedBox(width: 12),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}
