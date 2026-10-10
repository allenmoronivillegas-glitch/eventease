import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/user_profile_service.dart';
import '../theme/app_theme.dart';

class OnboardingPage extends StatefulWidget {
  const OnboardingPage({
    required this.user,
    required this.onFinished,
    super.key,
  });

  final User user;
  final VoidCallback onFinished;

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  static const _categories = <String, String>{
    'education': 'Education',
    'business': 'Business',
    'community': 'Community',
    'social': 'Social',
    'technology': 'Technology',
    'other': 'Other',
  };
  static const _eventSizes = <String, String>{
    'under_50': 'Under 50',
    '50_100': '50–100',
    '101_500': '101–500',
    'over_500': 'More than 500',
  };
  static const _organizationTypes = [
    'School',
    'Business',
    'Community',
    'Nonprofit',
    'Individual',
    'Other',
  ];

  final _profileService = UserProfileService();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _cityController = TextEditingController();
  final _organizationController = TextEditingController();
  final _invitationCodeController = TextEditingController();
  final _personalFormKey = GlobalKey<FormState>();
  final Set<String> _selectedCategories = {};

  String? _role;
  String? _organizationType;
  String? _expectedEventSize;
  int _step = 0;
  bool _announcements = true;
  bool _reminders = true;
  bool _saving = false;
  bool _saved = false;
  String? _saveError;

  @override
  void initState() {
    super.initState();
    _nameController.text = widget.user.displayName ?? '';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _cityController.dispose();
    _organizationController.dispose();
    _invitationCodeController.dispose();
    super.dispose();
  }

  void _continue() {
    if (_step == 0 && _role == null) {
      _showMessage('Choose how you’ll use EventEase to continue.');
      return;
    }
    if (_step == 1 && !_personalFormKey.currentState!.validate()) return;
    setState(() {
      _step = (_step + 1).clamp(0, 3);
      _saveError = null;
    });
  }

  void _back() {
    if (_saving || _step == 0) return;
    setState(() {
      _step--;
      _saveError = null;
    });
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _finish() async {
    if (_saving || _saved) return;
    final role = _role;
    if (role == null) return;

    setState(() {
      _saving = true;
      _saveError = null;
    });

    try {
      await _profileService
          .saveOnboardingProfile(
            uid: widget.user.uid,
            displayName: _nameController.text.trim(),
            email: widget.user.email,
            phone: _nullableText(_phoneController.text),
            city: _nullableText(_cityController.text),
            role: role,
            organizationName: _nullableText(_organizationController.text),
            organizationType: role == 'organizer' ? _organizationType : null,
            eventCategories: _selectedCategories.toList()..sort(),
            expectedEventSize: role == 'organizer' ? _expectedEventSize : null,
            invitationCode: role == 'attendee'
                ? _nullableText(_invitationCodeController.text)
                : null,
            notificationPreferences: role == 'attendee'
                ? {
                    'eventAnnouncements': _announcements,
                    'eventReminders': _reminders,
                  }
                : null,
          )
          .timeout(const Duration(seconds: 20));
      if (!mounted) return;
      setState(() {
        _saving = false;
        _saved = true;
      });
      if (mounted) widget.onFinished();
    } catch (error) {
      if (error is TimeoutException) {
        debugPrint('[OnboardingPage] Profile save timed out after 20 seconds');
      } else if (error is FirebaseException) {
        debugPrint('[OnboardingPage] Profile save failed (code=${error.code})');
      } else {
        debugPrint(
          '[OnboardingPage] Profile save failed '
          '(${error.runtimeType})',
        );
      }
      if (mounted) {
        setState(() {
          _saving = false;
          _saveError = _profileSaveErrorMessage(error);
        });
      }
    }
  }

  String _profileSaveErrorMessage(Object error) {
    if (error is TimeoutException) {
      return 'Saving your profile took too long. Check your connection and try again.';
    }
    if (error is FirebaseException) {
      switch (error.code) {
        case 'permission-denied':
          return 'Firestore denied permission to save your profile. Check your account permissions or contact support.';
        case 'unauthenticated':
        case 'user-mismatch':
          return 'Your sign-in changed or expired. Sign in again before saving your profile.';
        case 'unavailable':
        case 'deadline-exceeded':
        case 'network-request-failed':
          return 'Could not reach Firestore to save your profile. Check your connection and try again.';
        default:
          return 'Your profile could not be saved (Firestore error: ${error.code}). Please try again.';
      }
    }
    return 'Your profile could not be saved. Please try again.';
  }

  String? _nullableText(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  @override
  Widget build(BuildContext context) {
    if (_saved) return _buildSuccess();

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _brandHeader(),
                  const SizedBox(height: 28),
                  _progressHeader(),
                  const SizedBox(height: 20),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _stepContent(),
                          if (_saveError != null) ...[
                            const SizedBox(height: 16),
                            _errorBanner(_saveError!),
                          ],
                          const SizedBox(height: 24),
                          _navigationButtons(),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _brandHeader() {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(9),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppTheme.primary, AppTheme.accent],
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(
            Icons.event_seat_rounded,
            color: Colors.white,
            size: 22,
          ),
        ),
        const SizedBox(width: 10),
        const Text(
          'EventEase',
          style: TextStyle(
            color: AppTheme.textPrimary,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _progressHeader() {
    final titles = ['Your role', 'About you', 'Preferences', 'Review'];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'STEP ${_step + 1} OF 4',
                style: const TextStyle(
                  color: AppTheme.primary,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1,
                ),
              ),
            ),
            Text(
              titles[_step],
              style: const TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: (_step + 1) / 4,
            minHeight: 7,
            backgroundColor: AppTheme.primaryLight,
            color: AppTheme.primary,
          ),
        ),
      ],
    );
  }

  Widget _stepContent() {
    return switch (_step) {
      0 => _roleStep(),
      1 => _personalStep(),
      2 => _preferencesStep(),
      _ => _reviewStep(),
    };
  }

  Widget _stepTitle(String title, String subtitle) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 23,
              height: 1.2,
              fontWeight: FontWeight.bold,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: const TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 14,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _roleStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _stepTitle(
          'How will you use EventEase?',
          'Choose the option that best describes you.',
        ),
        _roleCard(
          value: 'organizer',
          title: 'Event Organizer',
          description: 'Create and manage events, schedules, and attendees.',
          icon: Icons.event_available_rounded,
          details: const [
            'Organize schedules and announcements',
            'Manage registrations and attendees',
          ],
        ),
        const SizedBox(height: 12),
        _roleCard(
          value: 'attendee',
          title: 'Attendee / Invitee',
          description: 'Discover events and take part in the ones you love.',
          icon: Icons.groups_rounded,
          details: const [
            'View event information and schedules',
            'Register or respond to invitations',
          ],
        ),
      ],
    );
  }

  Widget _roleCard({
    required String value,
    required String title,
    required String description,
    required IconData icon,
    required List<String> details,
  }) {
    final selected = _role == value;
    return Semantics(
      button: true,
      selected: selected,
      label: title,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => setState(() {
          _role = value;
          _saveError = null;
        }),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: selected ? AppTheme.primaryLight : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected ? AppTheme.primary : AppTheme.cardBorder,
              width: selected ? 2 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: selected ? Colors.white : AppTheme.background,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(icon, color: AppTheme.primary, size: 23),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Icon(
                    selected
                        ? Icons.radio_button_checked_rounded
                        : Icons.radio_button_off_rounded,
                    color: selected ? AppTheme.primary : AppTheme.textMuted,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                description,
                style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 10),
              ...details.map(
                (detail) => Padding(
                  padding: const EdgeInsets.only(top: 5),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.check_rounded,
                        size: 16,
                        color: AppTheme.primary,
                      ),
                      const SizedBox(width: 7),
                      Expanded(
                        child: Text(
                          detail,
                          style: const TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _personalStep() {
    return Form(
      key: _personalFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _stepTitle(
            'Tell us about yourself',
            'Your name helps people recognize you in EventEase.',
          ),
          _fieldLabel('Full name'),
          TextFormField(
            controller: _nameController,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              hintText: 'Your full name',
              prefixIcon: Icon(Icons.person_outline_rounded),
            ),
            validator: (value) => (value == null || value.trim().isEmpty)
                ? 'Enter your full name'
                : null,
          ),
          const SizedBox(height: 16),
          _fieldLabel('Email address'),
          TextFormField(
            initialValue: widget.user.email ?? '',
            readOnly: true,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.mail_outline_rounded),
              helperText: 'This is linked to your sign-in account.',
            ),
          ),
          const SizedBox(height: 16),
          _fieldLabel('Phone number (optional)'),
          TextFormField(
            controller: _phoneController,
            keyboardType: TextInputType.phone,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              hintText: 'Your phone number',
              prefixIcon: Icon(Icons.phone_outlined),
            ),
          ),
          const SizedBox(height: 16),
          _fieldLabel('City or location (optional)'),
          TextFormField(
            controller: _cityController,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.done,
            decoration: const InputDecoration(
              hintText: 'City, region, or area',
              prefixIcon: Icon(Icons.location_on_outlined),
            ),
          ),
        ],
      ),
    );
  }

  Widget _preferencesStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _stepTitle(
          _role == 'organizer'
              ? 'Tell us about your events'
              : 'What events interest you?',
          _role == 'organizer'
              ? 'These details help us tailor your event workspace.'
              : 'Choose the kinds of events you would like to hear about.',
        ),
        if (_role == 'organizer') ...[
          _fieldLabel('Organization or team name (optional)'),
          TextField(
            controller: _organizationController,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              hintText: 'Organization or team',
              prefixIcon: Icon(Icons.business_outlined),
            ),
          ),
          const SizedBox(height: 16),
          _fieldLabel('Organization type'),
          DropdownButtonFormField<String>(
            initialValue: _organizationType,
            decoration: const InputDecoration(
              hintText: 'Select a type',
              prefixIcon: Icon(Icons.category_outlined),
            ),
            items: _organizationTypes
                .map((type) => DropdownMenuItem(value: type, child: Text(type)))
                .toList(),
            onChanged: (value) => setState(() => _organizationType = value),
          ),
          const SizedBox(height: 20),
        ] else ...[
          _fieldLabel('Organization, school, or group (optional)'),
          TextField(
            controller: _organizationController,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              hintText: 'Your organization or group',
              prefixIcon: Icon(Icons.groups_outlined),
            ),
          ),
          const SizedBox(height: 16),
          _fieldLabel('Invitation code (optional)'),
          TextField(
            controller: _invitationCodeController,
            textCapitalization: TextCapitalization.characters,
            decoration: const InputDecoration(
              hintText: 'Enter a code if you have one',
              prefixIcon: Icon(Icons.confirmation_number_outlined),
            ),
          ),
          const SizedBox(height: 20),
        ],
        _fieldLabel(
          _role == 'organizer' ? 'Event categories' : 'Event interests',
        ),
        _categoryChoices(),
        if (_role == 'organizer') ...[
          const SizedBox(height: 20),
          _fieldLabel('Expected event size'),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _eventSizes.entries.map((entry) {
              return ChoiceChip(
                label: Text(entry.value),
                selected: _expectedEventSize == entry.key,
                onSelected: (_) => setState(
                  () => _expectedEventSize = _expectedEventSize == entry.key
                      ? null
                      : entry.key,
                ),
              );
            }).toList(),
          ),
        ] else ...[
          const SizedBox(height: 20),
          _fieldLabel('Event announcements and reminders'),
          _notificationSwitch(
            title: 'Event announcements',
            subtitle: 'Updates and important event information',
            value: _announcements,
            onChanged: (value) => setState(() => _announcements = value),
          ),
          _notificationSwitch(
            title: 'Event reminders',
            subtitle: 'Friendly reminders before an event',
            value: _reminders,
            onChanged: (value) => setState(() => _reminders = value),
          ),
        ],
      ],
    );
  }

  Widget _categoryChoices() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _categories.entries.map((entry) {
        final selected = _selectedCategories.contains(entry.key);
        return FilterChip(
          label: Text(entry.value),
          selected: selected,
          onSelected: (value) => setState(() {
            if (value) {
              _selectedCategories.add(entry.key);
            } else {
              _selectedCategories.remove(entry.key);
            }
          }),
        );
      }).toList(),
    );
  }

  Widget _notificationSwitch({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(
        title,
        style: const TextStyle(
          color: AppTheme.textPrimary,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
      ),
      value: value,
      activeTrackColor: AppTheme.primary,
      onChanged: onChanged,
    );
  }

  Widget _reviewStep() {
    final role = _role;
    final roleLabel = role == 'organizer'
        ? 'Event Organizer'
        : 'Attendee / Invitee';
    final categories =
        _selectedCategories.map((value) => _categories[value]!).toList()
          ..sort();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _stepTitle(
          'You’re almost ready!',
          'Review your details before finishing setup.',
        ),
        _summarySection(
          title: 'Your details',
          icon: Icons.person_outline_rounded,
          rows: [
            _summaryRow('Name', _nameController.text.trim()),
            _summaryRow('Email', widget.user.email ?? 'Not provided'),
            _summaryRow('Role', roleLabel),
            if (_phoneController.text.trim().isNotEmpty)
              _summaryRow('Phone', _phoneController.text.trim()),
            if (_cityController.text.trim().isNotEmpty)
              _summaryRow('Location', _cityController.text.trim()),
          ],
        ),
        const SizedBox(height: 14),
        _summarySection(
          title: role == 'organizer'
              ? 'Organizer profile'
              : 'Event preferences',
          icon: role == 'organizer'
              ? Icons.event_available_rounded
              : Icons.interests_rounded,
          rows: [
            if (_organizationController.text.trim().isNotEmpty)
              _summaryRow(
                role == 'organizer' ? 'Organization' : 'Group',
                _organizationController.text.trim(),
              ),
            if (role == 'organizer' && _organizationType != null)
              _summaryRow('Organization type', _organizationType!),
            _summaryRow(
              role == 'organizer' ? 'Event categories' : 'Interests',
              categories.isEmpty ? 'None selected' : categories.join(', '),
            ),
            if (role == 'organizer' && _expectedEventSize != null)
              _summaryRow(
                'Expected event size',
                _eventSizes[_expectedEventSize]!,
              ),
            if (role == 'attendee' &&
                _invitationCodeController.text.trim().isNotEmpty)
              _summaryRow(
                'Invitation code',
                _invitationCodeController.text.trim(),
              ),
            if (role == 'attendee')
              _summaryRow(
                'Announcements',
                _announcements ? 'Enabled' : 'Disabled',
              ),
            if (role == 'attendee')
              _summaryRow('Reminders', _reminders ? 'Enabled' : 'Disabled'),
          ],
        ),
      ],
    );
  }

  Widget _summarySection({
    required String title,
    required IconData icon,
    required List<Widget> rows,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.background,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: AppTheme.primary, size: 19),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...rows,
        ],
      ),
    );
  }

  Widget _summaryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(top: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 128,
            child: Text(
              label,
              style: const TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 12,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _fieldLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Text(
        label,
        style: const TextStyle(
          color: AppTheme.textPrimary,
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _navigationButtons() {
    final isLastStep = _step == 3;
    return Row(
      children: [
        if (_step > 0) ...[
          Expanded(
            child: OutlinedButton.icon(
              onPressed: _saving ? null : _back,
              icon: const Icon(Icons.arrow_back_rounded, size: 18),
              label: const Text('Back'),
            ),
          ),
          const SizedBox(width: 12),
        ],
        Expanded(
          flex: _step == 0 ? 1 : 2,
          child: ElevatedButton(
            onPressed: _saving ? null : (isLastStep ? _finish : _continue),
            child: _saving
                ? const SizedBox(
                    width: 19,
                    height: 19,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        isLastStep
                            ? 'Finish Setup'
                            : _step == 0
                            ? 'Get started'
                            : 'Continue',
                      ),
                      if (!isLastStep) ...[
                        const SizedBox(width: 7),
                        const Icon(Icons.arrow_forward_rounded, size: 18),
                      ],
                    ],
                  ),
          ),
        ),
      ],
    );
  }

  Widget _errorBanner(String message) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.dangerLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.danger.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.error_outline_rounded,
            color: AppTheme.danger,
            size: 18,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: AppTheme.danger, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuccess() {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: const BoxDecoration(
                    color: AppTheme.successLight,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check_rounded,
                    color: AppTheme.success,
                    size: 42,
                  ),
                ),
                const SizedBox(height: 18),
                const Text(
                  'You’re all set!',
                  style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Your EventEase profile is ready. Taking you to your workspace…',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppTheme.textSecondary),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
