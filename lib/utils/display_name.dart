// Helper to consistently resolve a user's display name for UI.
String resolveDisplayNameFromUserData(dynamic data) {
  if (data == null) return 'Unknown user';
  final map = data is Map<String, dynamic>
      ? data
      : (data is Function ? null : data as Map<String, dynamic>?);
  if (map == null) return 'Unknown user';
  final displayName = (map['displayName'] ?? '').toString();
  if (displayName.isNotEmpty) return displayName;
  final email = (map['email'] ?? '').toString();
  if (email.isNotEmpty) return email;
  return 'Unknown user';
}
