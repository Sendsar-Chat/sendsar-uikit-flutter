class DemoUser {
  const DemoUser({
    required this.chatUserId,
    required this.displayName,
  });

  final String chatUserId;
  final String displayName;
}

/// Demo identities — same as sendsar-uikit-angular sample-app.
const demoUsers = [
  DemoUser(chatUserId: 'usr_shop_1', displayName: 'Alice'),
  DemoUser(chatUserId: 'usr_shop_2', displayName: 'Bob'),
  DemoUser(chatUserId: 'usr_shop_3', displayName: 'Shop Support'),
  DemoUser(chatUserId: 'usr_shop_4', displayName: 'Carol'),
  DemoUser(chatUserId: 'usr_shop_5', displayName: 'Dave'),
];

/// Base URL for the sample BFF (`sample-bff/` in this repo).
///
/// Default port is 4400 (see `sample-bff/.env.example`).
/// Override: `flutter run --dart-define=BFF_BASE_URL=http://localhost:4400`
const bffBaseUrl = String.fromEnvironment(
  'BFF_BASE_URL',
  defaultValue: 'http://localhost:4400',
);
