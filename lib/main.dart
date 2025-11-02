import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'screens/screens.dart';
import 'services/services.dart';
import 'utils/theme.dart';

// Background message handler
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  print('Background message received: ${message.messageId}');
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Firebase
  await Firebase.initializeApp();
  
  // Set up background message handler
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  
  // Initialize Notification Service
  final notificationService = NotificationService();
  await notificationService.initialize();
  
  // Auto-subscribe to bitcoin-signals topic
  await notificationService.subscribeToTopic('bitcoin-signals');
  print('Subscribed to bitcoin-signals topic');
  
  runApp(BitcoinWatcherApp(notificationService: notificationService));
}

class BitcoinWatcherApp extends StatelessWidget {
  final NotificationService notificationService;

  const BitcoinWatcherApp({
    Key? key,
    required this.notificationService,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Bitcoin Watcher',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: MainNavigator(notificationService: notificationService),
    );
  }
}

class MainNavigator extends StatefulWidget {
  final NotificationService notificationService;

  const MainNavigator({
    Key? key,
    required this.notificationService,
  }) : super(key: key);

  @override
  State<MainNavigator> createState() => _MainNavigatorState();
}

class _MainNavigatorState extends State<MainNavigator> {
  int _currentIndex = 0;
  
  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    
    _screens = [
      const HomeScreen(),
      const HistoryScreen(),
      const SettingsScreen(),
    ];

    // Handle notification taps
    widget.notificationService.onNotificationTap = (signalId) {
      // Navigate to history screen when notification is tapped
      setState(() => _currentIndex = 1);
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() => _currentIndex = index);
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.history_outlined),
            selectedIcon: Icon(Icons.history),
            label: 'History',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}
