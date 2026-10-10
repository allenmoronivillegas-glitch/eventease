import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/user_profile_service.dart';
import 'app_theme.dart';

class ThemeController extends ChangeNotifier with WidgetsBindingObserver {
  ThemeController({FirebaseAuth? auth, UserProfileService? profileService})
    : _auth = auth ?? FirebaseAuth.instance,
      _profileService = profileService ?? UserProfileService() {
    WidgetsBinding.instance.addObserver(this);
    _applyTheme();
  }

  final FirebaseAuth _auth;
  final UserProfileService _profileService;
  SharedPreferences? _preferences;
  StreamSubscription<User?>? _authSubscription;
  StreamSubscription<Map<String, dynamic>?>? _profileSubscription;
  int _accountLoadGeneration = 0;

  ThemeMode _themeMode = ThemeMode.system;
  String _accentId = 'indigo';
  String? _activeUid;
  ThemeMode get themeMode => _themeMode;
  String get accentId => _accentId;

  Future<void> initialize() async {
    _preferences = await SharedPreferences.getInstance();
    await _switchAccount(_auth.currentUser);
    _authSubscription = _auth.authStateChanges().listen(
      (user) => unawaited(_switchAccount(user)),
      onError: (Object error) {
        debugPrint('[ThemeController] Auth state stream failed: $error');
      },
    );
  }

  Future<void> setAppearance({ThemeMode? themeMode, String? accentId}) async {
    if (themeMode != null) _themeMode = themeMode;
    if (accentId != null &&
        AppTheme.accents.any((accent) => accent.id == accentId)) {
      _accentId = accentId;
    }
    _applyTheme();
    notifyListeners();

    final uid = _activeUid;
    final preferences = _preferences;
    if (preferences == null) return;
    await preferences.setString(_localKey(uid, 'themeMode'), _themeMode.name);
    await preferences.setString(_localKey(uid, 'accentColor'), _accentId);
    if (uid != null) {
      await _profileService.saveAppearancePreferences(
        uid: uid,
        themeMode: _themeMode.name,
        accentColor: _accentId,
      );
    }
  }

  @override
  void didChangePlatformBrightness() {
    if (_themeMode == ThemeMode.system) {
      _applyTheme();
      notifyListeners();
    }
  }

  Future<void> _switchAccount(User? user) async {
    final uid = user?.uid;
    if (uid == _activeUid && _profileSubscription != null) return;

    final generation = ++_accountLoadGeneration;
    final previousSubscription = _profileSubscription;
    _profileSubscription = null;
    _activeUid = uid;
    await previousSubscription?.cancel();
    if (generation != _accountLoadGeneration) return;

    final preferences = _preferences;
    if (preferences != null) {
      _themeMode = _parseThemeMode(
        preferences.getString(_localKey(uid, 'themeMode')),
      );
      _accentId = _validatedAccent(
        preferences.getString(_localKey(uid, 'accentColor')),
      );
      _applyTheme();
      notifyListeners();
    }

    if (uid == null) return;
    _profileSubscription = _profileService
        .watchProfile(uid)
        .listen(
          (profile) {
            if (_activeUid != uid || profile == null) return;
            final mode = profile['themeMode'];
            final accent = profile['accentColor'];
            if (mode is String || accent is String) {
              _themeMode = _parseThemeMode(mode is String ? mode : null);
              _accentId = _validatedAccent(accent is String ? accent : null);
              _applyTheme();
              notifyListeners();
              unawaited(_saveLocalPreferences(uid));
            }
          },
          onError: (Object error) {
            debugPrint(
              '[ThemeController] Profile preference stream failed: $error',
            );
          },
        );
  }

  Future<void> _saveLocalPreferences(String uid) async {
    final preferences = _preferences;
    if (preferences == null || _activeUid != uid) return;
    await preferences.setString(_localKey(uid, 'themeMode'), _themeMode.name);
    await preferences.setString(_localKey(uid, 'accentColor'), _accentId);
  }

  ThemeMode _parseThemeMode(String? value) {
    return switch (value) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
  }

  String _validatedAccent(String? value) {
    return AppTheme.accents.any((accent) => accent.id == value)
        ? value!
        : 'indigo';
  }

  String _localKey(String? uid, String preference) =>
      'eventease_${uid ?? 'guest'}_$preference';

  void _applyTheme() {
    final brightness = switch (_themeMode) {
      ThemeMode.light => Brightness.light,
      ThemeMode.dark => Brightness.dark,
      ThemeMode.system =>
        WidgetsBinding.instance.platformDispatcher.platformBrightness,
    };
    AppTheme.configure(accentId: _accentId, brightness: brightness);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    final authSubscription = _authSubscription;
    final profileSubscription = _profileSubscription;
    if (authSubscription != null) unawaited(authSubscription.cancel());
    if (profileSubscription != null) {
      unawaited(profileSubscription.cancel());
    }
    super.dispose();
  }
}

class ThemeControllerScope extends InheritedNotifier<ThemeController> {
  const ThemeControllerScope({
    required ThemeController controller,
    required super.child,
    super.key,
  }) : super(notifier: controller);

  static ThemeController of(BuildContext context) {
    final scope = context
        .dependOnInheritedWidgetOfExactType<ThemeControllerScope>();
    assert(scope != null, 'No ThemeControllerScope found in this context.');
    return scope!.notifier!;
  }
}
