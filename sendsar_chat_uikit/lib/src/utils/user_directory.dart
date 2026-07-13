/// Maps chat user ids to display metadata for labels, avatars, and presence.
class UserDirectoryEntry {
  const UserDirectoryEntry({
    required this.id,
    required this.displayName,
    this.avatarUrl,
  });

  final String id;
  final String displayName;
  final String? avatarUrl;
}

Map<String, UserDirectoryEntry> userDirectoryMap(
  List<UserDirectoryEntry> users,
) {
  return {for (final u in users) u.id: u};
}

String displayNameFor(
  String userId,
  Map<String, UserDirectoryEntry> users,
) {
  return users[userId]?.displayName ?? userId;
}

String initialsFor(String name) {
  final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
  final list = parts.toList();
  if (list.isEmpty) return '?';
  if (list.length == 1) {
    return list[0].length >= 2
        ? list[0].substring(0, 2).toUpperCase()
        : list[0].toUpperCase();
  }
  return '${list.first[0]}${list.last[0]}'.toUpperCase();
}
