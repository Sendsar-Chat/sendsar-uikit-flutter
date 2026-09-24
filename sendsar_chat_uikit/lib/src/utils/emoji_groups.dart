class SendsarEmojiGroup {
  const SendsarEmojiGroup({
    required this.label,
    required this.emojis,
  });

  final String label;
  final List<String> emojis;
}

const defaultEmojiGroups = <SendsarEmojiGroup>[
  SendsarEmojiGroup(
    label: 'Popular',
    emojis: ['👍', '❤️', '😂', '🔥', '🙏', '👏', '😭', '😍', '🎉', '😊', '✨', '🤔'],
  ),
  SendsarEmojiGroup(
    label: 'Smileys',
    emojis: ['😀', '😁', '😂', '🤣', '😊', '😍', '😘', '😎', '🥳', '😭', '😡', '🤔'],
  ),
  SendsarEmojiGroup(
    label: 'People',
    emojis: ['🙌', '👋', '👌', '💪', '🤝', '👀', '✅', '❌', '👎', '🙏', '👏', '👍'],
  ),
  SendsarEmojiGroup(
    label: 'Hearts & Symbols',
    emojis: ['❤️', '💛', '💚', '💙', '💜', '🖤', '🤍', '💯', '⭐', '✨', '🔥', '🎯'],
  ),
  SendsarEmojiGroup(
    label: 'Celebration',
    emojis: ['🎉', '🥳', '🎊', '🙌', '👏', '🍾', '🏆', '🚀', '🌟', '🎂', '🎁', '🍀'],
  ),
];
