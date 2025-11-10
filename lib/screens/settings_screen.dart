import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../providers/auth_provider.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _signingOut = false;
  bool _uploading = false;
  bool? _localNotifications;
  static const _prefsNotificationsKey = 'notifications_enabled_v1';

  Future<void> _loadLocalNotifications(bool defaultValue) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final stored = prefs.getBool(_prefsNotificationsKey);
      if (!mounted) return;
      setState(() => _localNotifications = stored ?? defaultValue);
    } catch (_) {
      if (!mounted) return;
      setState(() => _localNotifications = defaultValue);
    }
  }

  String _maskEmail(String? email) {
    if (email == null || email.isEmpty) return '';
    final parts = email.split('@');
    if (parts.length != 2) return email;
    final name = parts[0];
    final domain = parts[1];
    if (name.length <= 1) return '*@$domain';
    return '${name[0]}***@${domain}';
  }

  Future<void> _pickAndUpload() async {
    final picker = ImagePicker();
    final picked =
        await picker.pickImage(source: ImageSource.gallery, maxWidth: 1200);
    if (picked == null) return;
    setState(() => _uploading = true);
    try {
      // Always read bytes (XFile supports readAsBytes on all platforms).
      final bytes = await picked.readAsBytes();
      await ref.read(authServiceProvider).uploadProfilePictureBytes(bytes,
          contentType: picked.mimeType ?? 'image/jpeg');
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Profile photo updated')));
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error uploading photo: $e')));
    }
    setState(() => _uploading = false);
  }

  Future<void> _confirmAndSignOut() async {
    final yes = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
              title: Text('Sign out'),
              content: Text('Are you sure you want to sign out?'),
              actions: [
                TextButton(
                    onPressed: () => Navigator.of(ctx).pop(false),
                    child: Text('Cancel')),
                TextButton(
                    onPressed: () => Navigator.of(ctx).pop(true),
                    child: Text('Sign out')),
              ],
            ));
    if (yes != true) return;
    setState(() => _signingOut = true);
    try {
      await ref.read(authServiceProvider).signOutAll();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error signing out: $e')));
    }
    setState(() => _signingOut = false);
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(userProfileProvider);

    return Scaffold(
      appBar: AppBar(title: Text('Settings')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: profileAsync.when(
          data: (profile) {
            // If there's no Firestore profile, but an auth user exists,
            // show auth info and allow creating the profile document.
            final authUser = ref.read(firebaseAuthProvider).currentUser;
            if (profile == null) {
              if (authUser == null) return Center(child: Text('Not signed in'));
              // Only show minimal info when a Firestore profile is not yet created
              final displayName = authUser.displayName ?? '';
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Profile not set up yet',
                          style: Theme.of(context).textTheme.titleLarge),
                      SizedBox(height: 12),
                      if (displayName.isNotEmpty) Text('Name: $displayName'),
                      SizedBox(height: 8),
                      Text('Email: ${authUser.email ?? ''}'),
                      SizedBox(height: 12),
                      ElevatedButton(
                        onPressed: () async {
                          try {
                            await ref
                                .read(authServiceProvider)
                                .ensureProfileExists();
                            ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Profile created')));
                          } catch (e) {
                            ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Error: $e')));
                          }
                        },
                        child: Text('Create profile'),
                      )
                    ],
                  ),
                ),
              );
            }
            final initials = profile.displayName.isNotEmpty
                ? profile.displayName
                    .trim()
                    .split(' ')
                    .map((s) => s.isNotEmpty ? s[0] : '')
                    .take(2)
                    .join()
                : profile.email.split('@').first.substring(0, 1).toUpperCase();

            // initialize local notifications flag once per load so toggling feels instant
            if (_localNotifications == null)
              _loadLocalNotifications(profile.notifications);

            return SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Profile',
                      style: Theme.of(context).textTheme.titleLarge),
                  SizedBox(height: 12),
                  Row(children: [
                    GestureDetector(
                      onTap: _uploading ? null : _pickAndUpload,
                      child: CircleAvatar(
                        radius: 36,
                        backgroundColor: Colors.grey[200],
                        backgroundImage: profile.imageUrl.isNotEmpty
                            ? NetworkImage(profile.imageUrl)
                            : null,
                        child: profile.imageUrl.isEmpty
                            ? Text(initials,
                                style: TextStyle(
                                    fontSize: 20, fontWeight: FontWeight.w600))
                            : null,
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                        child: Text(profile.displayName,
                            style: Theme.of(context).textTheme.titleMedium)),
                    if (_uploading) CircularProgressIndicator(),
                  ]),
                  SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(child: Text('Name: ${profile.displayName}')),
                      TextButton(
                          onPressed: () async {
                            final newName = await showDialog<String?>(
                                context: context,
                                builder: (ctx) {
                                  final ctrl = TextEditingController(
                                      text: profile.displayName);
                                  return AlertDialog(
                                    title: Text('Edit name'),
                                    content: TextField(controller: ctrl),
                                    actions: [
                                      TextButton(
                                          onPressed: () =>
                                              Navigator.of(ctx).pop(),
                                          child: Text('Cancel')),
                                      TextButton(
                                          onPressed: () => Navigator.of(ctx)
                                              .pop(ctrl.text.trim()),
                                          child: Text('Save')),
                                    ],
                                  );
                                });
                            if (newName != null && newName.isNotEmpty) {
                              try {
                                await ref
                                    .read(authServiceProvider)
                                    .updateDisplayName(newName);
                                ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Name updated')));
                              } catch (e) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Error: $e')));
                              }
                            }
                          },
                          child: Text('Edit'))
                    ],
                  ),
                  // Only show minimal profile info: name and masked email
                  Text('Email: ${_maskEmail(profile.email)}'),
                  SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(child: Text('Notifications')),
                      Switch(
                        value: _localNotifications ?? profile.notifications,
                        onChanged: (v) async {
                          // update UI immediately (local simulation)
                          setState(() => _localNotifications = v);
                          // persist locally
                          try {
                            final prefs = await SharedPreferences.getInstance();
                            await prefs.setBool(_prefsNotificationsKey, v);
                          } catch (_) {
                            // ignore local persistence errors
                          }
                          // persist to Firestore in background
                          try {
                            await ref
                                .read(authServiceProvider)
                                .updateNotifications(v);
                            if (mounted)
                              ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                      content: Text(v
                                          ? 'Notifications enabled'
                                          : 'Notifications disabled')));
                          } catch (e) {
                            // revert local flag on error and in prefs
                            setState(() =>
                                _localNotifications = profile.notifications);
                            try {
                              final prefs =
                                  await SharedPreferences.getInstance();
                              await prefs.setBool(_prefsNotificationsKey,
                                  profile.notifications);
                            } catch (_) {}
                            if (mounted)
                              ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Error: $e')));
                          }
                        },
                      ),
                    ],
                  ),
                  SizedBox(height: 24),
                  Divider(),
                  SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _signingOut ? null : _confirmAndSignOut,
                      icon: _signingOut
                          ? SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                  color: Colors.white, strokeWidth: 2))
                          : Icon(Icons.logout),
                      label: Text(_signingOut ? 'Signing out...' : 'Sign out'),
                      style: ElevatedButton.styleFrom(
                          backgroundColor:
                              Theme.of(context).colorScheme.primary),
                    ),
                  ),
                ],
              ),
            );
          },
          loading: () => Center(child: CircularProgressIndicator()),
          error: (e, st) => Center(child: Text('Error: $e')),
        ),
      ),
    );
  }
}
