import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/user_profile_service.dart';
import '../theme/app_theme.dart';
import '../theme/theme_controller.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final _nameCtrl = TextEditingController();
  final _profileService = UserProfileService();

  bool _savingName = false;
  bool _uploadingPhoto = false;
  double _uploadProgress = 0;
  Uint8List? _pendingPhotoBytes;
  String? _pendingPhotoType;

  // Notification preferences (local only for now).
  // TODO: persist these (SharedPreferences or a Firestore user document).
  bool _newRegistrations = true;
  bool _checkInAlerts = true;
  bool _dailySummary = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl.text = FirebaseAuth.instance.currentUser?.displayName ?? '';
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  String _initials(User? user) {
    final name = (user?.displayName ?? '').trim();
    if (name.isNotEmpty) {
      final parts = name.split(RegExp(r'\s+'));
      final first = parts.first[0];
      final last = parts.length > 1 ? parts.last[0] : '';
      return (first + last).toUpperCase();
    }
    final email = user?.email ?? '';
    return email.isNotEmpty ? email[0].toUpperCase() : '?';
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _saveProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      _toast('Enter a display name first.');
      return;
    }
    setState(() => _savingName = true);
    try {
      await _profileService.saveDisplayName(uid: user.uid, displayName: name);
      await user.reload();
      if (mounted) _toast('Profile updated');
    } on FirebaseAuthException catch (e) {
      if (mounted) _toast(e.message ?? 'Could not update profile.');
    } finally {
      if (mounted) setState(() => _savingName = false);
    }
  }

  Future<void> _pickProfilePhoto() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['jpg', 'jpeg', 'png', 'webp'],
        allowMultiple: false,
        withData: true,
      );
      if (result == null || result.files.isEmpty || !mounted) return;
      final file = result.files.single;
      final bytes = file.bytes;
      const maxBytes = 5 * 1024 * 1024;
      if (file.size <= 0 || file.size > maxBytes || bytes == null) {
        _toast('Choose an image no larger than 5 MB.');
        return;
      }
      final contentType = switch (file.extension?.toLowerCase()) {
        'jpg' || 'jpeg' => 'image/jpeg',
        'png' => 'image/png',
        'webp' => 'image/webp',
        _ => null,
      };
      if (contentType == null) {
        _toast('Choose a PNG, JPEG, or WebP image.');
        return;
      }
      setState(() {
        _pendingPhotoBytes = bytes;
        _pendingPhotoType = contentType;
        _uploadProgress = 0;
      });
    } on PlatformException catch (error) {
      if (mounted) {
        _toast(error.message ?? 'Could not access the selected image.');
      }
    }
  }

  Future<void> _uploadProfilePhoto() async {
    final user = FirebaseAuth.instance.currentUser;
    final bytes = _pendingPhotoBytes;
    final contentType = _pendingPhotoType;
    if (user == null || bytes == null || contentType == null) return;
    setState(() {
      _uploadingPhoto = true;
      _uploadProgress = 0;
    });
    try {
      await _profileService.uploadProfilePhoto(
        uid: user.uid,
        bytes: bytes,
        contentType: contentType,
        onProgress: (progress) {
          if (mounted) setState(() => _uploadProgress = progress);
        },
      );
      if (!mounted) return;
      setState(() {
        _pendingPhotoBytes = null;
        _pendingPhotoType = null;
      });
      _toast('Profile photo updated.');
    } on ArgumentError catch (error) {
      if (mounted) _toast(error.message?.toString() ?? 'Invalid image.');
    } on FirebaseException catch (error) {
      if (!mounted) return;
      final message = error.code == 'unauthorized'
          ? 'You do not have permission to upload this photo.'
          : error.message ?? 'Could not upload the profile photo.';
      _toast(message);
    } finally {
      if (mounted) setState(() => _uploadingPhoto = false);
    }
  }

  Future<void> _changeAppearance({ThemeMode? mode, String? accentId}) async {
    try {
      await ThemeControllerScope.of(context)
          .setAppearance(themeMode: mode, accentId: accentId);
    } on FirebaseException catch (error) {
      if (mounted) {
        _toast(error.message ?? 'Could not sync appearance preferences.');
      }
    }
  }

  Future<void> _sendPasswordReset() async {
    final email = FirebaseAuth.instance.currentUser?.email;
    if (email == null) return;
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      if (mounted) _toast('Password reset email sent to $email');
    } on FirebaseAuthException catch (e) {
      if (mounted) _toast(e.message ?? 'Could not send reset email.');
    }
  }

  Future<void> _signOut() async {
    await FirebaseAuth.instance.signOut();
    if (!mounted) return;
    // AuthGate swaps to the login page; close this pushed page too.
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    Theme.of(context);
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text(
          'Settings',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.userChanges(),
        builder: (context, snapshot) {
          final user = snapshot.data ?? FirebaseAuth.instance.currentUser;
          final photoUrl = user?.photoURL;
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _profileHeader(user),
                  const SizedBox(height: 16),
                  _sectionCard(
                    title: 'Profile photo',
                    icon: Icons.photo_camera_outlined,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Choose a PNG, JPEG, or WebP image (up to 5 MB).',
                          style: TextStyle(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: [
                            OutlinedButton.icon(
                              onPressed: _uploadingPhoto
                                  ? null
                                  : _pickProfilePhoto,
                              icon: const Icon(Icons.photo_library_outlined),
                              label: Text(
                                photoUrl == null
                                    ? 'Choose photo'
                                    : 'Replace photo',
                              ),
                            ),
                            if (_pendingPhotoBytes != null)
                              ElevatedButton.icon(
                                onPressed: _uploadingPhoto
                                    ? null
                                    : _uploadProfilePhoto,
                                icon: const Icon(Icons.cloud_upload_outlined),
                                label: const Text('Upload photo'),
                              ),
                          ],
                        ),
                        if (_uploadingPhoto) ...[
                          const SizedBox(height: 12),
                          LinearProgressIndicator(value: _uploadProgress),
                          const SizedBox(height: 4),
                          Text('${(_uploadProgress * 100).round()}% uploaded'),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  _sectionCard(
                    title: 'Profile',
                    icon: Icons.person_outline_rounded,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _label('Display name'),
                        TextField(
                          controller: _nameCtrl,
                          textCapitalization: TextCapitalization.words,
                          decoration: const InputDecoration(
                            hintText: 'Your name',
                          ),
                        ),
                        const SizedBox(height: 14),
                        _label('Email'),
                        TextField(
                          controller: TextEditingController(
                            text: user?.email ?? '',
                          ),
                          enabled: false,
                          decoration: const InputDecoration(),
                        ),
                        const SizedBox(height: 16),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: ElevatedButton(
                            onPressed: _savingName ? null : _saveProfile,
                            child: _savingName
                                ? SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: AppTheme.surface,
                                    ),
                                  )
                                : const Text('Save changes'),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  _appearanceSection(ThemeControllerScope.of(context)),
                  const SizedBox(height: 16),
                  _sectionCard(
                    title: 'Notifications',
                    icon: Icons.notifications_none_rounded,
                    child: Theme(
                      data: Theme.of(context).copyWith(
                        switchTheme: SwitchThemeData(
                          thumbColor: WidgetStateProperty.resolveWith(
                            (states) => states.contains(WidgetState.selected)
                                ? Colors.white
                                : AppTheme.textMuted,
                          ),
                          trackColor: WidgetStateProperty.resolveWith(
                            (states) => states.contains(WidgetState.selected)
                                ? AppTheme.primary
                                : AppTheme.cardBorder,
                          ),
                          trackOutlineColor: WidgetStateProperty.all(
                            Colors.transparent,
                          ),
                        ),
                      ),
                      child: Column(
                        children: [
                          _switchRow(
                            'New registrations',
                            'When someone registers for your event',
                            _newRegistrations,
                            (v) => setState(() => _newRegistrations = v),
                          ),
                          Divider(height: 1, color: AppTheme.cardBorder),
                          _switchRow(
                            'Check-in alerts',
                            'When an attendee checks in',
                            _checkInAlerts,
                            (v) => setState(() => _checkInAlerts = v),
                          ),
                          Divider(height: 1, color: AppTheme.cardBorder),
                          _switchRow(
                            'Daily summary',
                            'Registrations and check-ins each morning',
                            _dailySummary,
                            (v) => setState(() => _dailySummary = v),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _sectionCard(
                    title: 'Security',
                    icon: Icons.lock_outline_rounded,
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Password',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.textPrimary,
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                'We\'ll email you a link to set a new one.',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppTheme.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        OutlinedButton(
                          onPressed: _sendPasswordReset,
                          child: const Text('Send reset link'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  _sectionCard(
                    title: 'Account',
                    icon: Icons.manage_accounts_outlined,
                    child: Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        OutlinedButton.icon(
                          onPressed: _signOut,
                          icon: const Icon(Icons.logout_rounded, size: 18),
                          label: const Text('Log out'),
                        ),
                        OutlinedButton.icon(
                          onPressed: null,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppTheme.danger,
                            side: BorderSide(
                              color: AppTheme.danger.withValues(alpha: 0.4),
                            ),
                          ),
                          icon: const Icon(
                            Icons.delete_forever_outlined,
                            size: 18,
                          ),
                          label: const Text('Account deletion unavailable'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Account deletion is temporarily unavailable because this '
                    'app does not yet safely remove the account’s Firestore '
                    'data and uploaded profile photo.',
                    style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ---------- Pieces ----------

  Widget _profileHeader(User? user) {
    final name = (user?.displayName ?? '').trim();
    final ImageProvider<Object>? photo = _pendingPhotoBytes != null
        ? MemoryImage(_pendingPhotoBytes!)
        : user?.photoURL == null
        ? null
        : NetworkImage(user!.photoURL!);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(),
      child: Row(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: AppTheme.primary,
            backgroundImage: photo,
            child: photo == null
                ? Text(
                    _initials(user),
                    style: TextStyle(
                      color: AppTheme.onPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  )
                : null,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name.isEmpty ? 'EventEase user' : name,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  user?.email ?? '',
                  style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _appearanceSection(ThemeController controller) {
    return _sectionCard(
      title: 'Appearance',
      icon: Icons.palette_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _label('Theme'),
          SegmentedButton<ThemeMode>(
            segments: const [
              ButtonSegment(
                value: ThemeMode.system,
                label: Text('System'),
                icon: Icon(Icons.settings_brightness_outlined),
              ),
              ButtonSegment(
                value: ThemeMode.light,
                label: Text('Light'),
                icon: Icon(Icons.light_mode_outlined),
              ),
              ButtonSegment(
                value: ThemeMode.dark,
                label: Text('Dark'),
                icon: Icon(Icons.dark_mode_outlined),
              ),
            ],
            selected: {controller.themeMode},
            onSelectionChanged: (selection) {
              if (selection.isNotEmpty) {
                _changeAppearance(mode: selection.first);
              }
            },
          ),
          const SizedBox(height: 18),
          _label('Accent color'),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final accent in AppTheme.accents)
                Semantics(
                  button: true,
                  selected: controller.accentId == accent.id,
                  label: '${accent.label} accent color',
                  child: Tooltip(
                    message: accent.label,
                    child: InkWell(
                      onTap: () => _changeAppearance(accentId: accent.id),
                      customBorder: const CircleBorder(),
                      child: Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: accent.color,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: controller.accentId == accent.id
                                ? Theme.of(context).colorScheme.onSurface
                                : Colors.transparent,
                            width: 2,
                          ),
                        ),
                        child: controller.accentId == accent.id
                            ? Icon(
                                Icons.check_rounded,
                                color: AppTheme.onAccentFor(accent.color),
                                size: 21,
                              )
                            : null,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  BoxDecoration _cardDecoration() {
    return BoxDecoration(
      color: AppTheme.surface,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: AppTheme.cardBorder),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.02),
          blurRadius: 10,
          offset: const Offset(0, 4),
        ),
      ],
    );
  }

  Widget _sectionCard({
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.primaryLight,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: AppTheme.primary, size: 18),
              ),
              const SizedBox(width: 10),
              Text(
                title,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }

  Widget _label(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: AppTheme.textPrimary,
        ),
      ),
    );
  }

  Widget _switchRow(
    String title,
    String subtitle,
    bool value,
    ValueChanged<bool> onChanged,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                ),
              ],
            ),
          ),
          Switch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}
