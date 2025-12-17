import 'package:flutter/material.dart';
import 'screens/home_screen.dart';
import 'services/instance_manager.dart';
import 'services/app_state_manager.dart';
import 'services/biometric_service.dart';

Future<void> main() async {
  // Ensure Flutter is initialized
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize instance manager
  await InstanceManager().init();

  // Initialize app state manager (loads active instances)
  await AppStateManager().initialize();

  // Initialize biometric service
  await BiometricService().init();

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  final BiometricService _biometricService = BiometricService();
  bool _isAuthenticated = false;
  bool _isAuthenticating = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkInitialAuthentication();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      // App going to background - clear auth time if timeout enabled
      _biometricService.clearAuthenticationTime();
    } else if (state == AppLifecycleState.resumed) {
      // App coming back from background - check if re-auth needed
      _checkReAuthentication();
    }
  }

  Future<void> _checkReAuthentication() async {
    if (await _biometricService.isBiometricEnabled() &&
        await _biometricService.needsReAuthentication()) {
      setState(() => _isAuthenticated = false);
      _authenticate();
    }
  }

  Future<void> _checkInitialAuthentication() async {
    if (!await _biometricService.isBiometricEnabled()) {
      setState(() => _isAuthenticated = true);
      return;
    }

    await _authenticate();
  }

  Future<void> _authenticate() async {
    if (_isAuthenticating) return;

    setState(() => _isAuthenticating = true);

    final success = await _biometricService.authenticate(
      reason: 'Unlock Arr Client',
      biometricOnly: false,
    );

    if (mounted) {
      setState(() {
        _isAuthenticated = success;
        _isAuthenticating = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Arr Client',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      themeMode: ThemeMode.system,
      home: _isAuthenticated
          ? const HomeScreen()
          : _BiometricLockScreen(onRetry: _authenticate),
    );
  }
}

class _BiometricLockScreen extends StatelessWidget {
  final VoidCallback onRetry;

  const _BiometricLockScreen({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.lock_outline,
              size: 80,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 24),
            Text(
              'Arr Client',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Locked',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: Theme.of(context).colorScheme.secondary,
              ),
            ),
            const SizedBox(height: 48),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.fingerprint),
              label: const Text('Unlock'),
            ),
          ],
        ),
      ),
    );
  }
}
