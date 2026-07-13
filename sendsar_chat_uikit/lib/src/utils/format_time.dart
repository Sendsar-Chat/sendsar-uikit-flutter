/// Short relative time for inbox rows (e.g. "2m", "3h", "Mon").
String formatRelativeTime(String? iso) {
  if (iso == null || iso.isEmpty) return '';
  final then = DateTime.tryParse(iso);
  if (then == null) return '';

  final diffSec = DateTime.now().difference(then).inSeconds;
  if (diffSec < 60) return 'now';
  if (diffSec < 3600) return '${diffSec ~/ 60}m';
  if (diffSec < 86400) return '${diffSec ~/ 3600}h';
  if (diffSec < 604800) {
    const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return weekdays[then.weekday - 1];
  }
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return '${months[then.month - 1]} ${then.day}';
}
