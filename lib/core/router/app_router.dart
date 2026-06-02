import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/splash_screen.dart';
import '../../features/auth/onboarding_screen.dart';
import '../../features/auth/login_screen.dart';
import '../../features/auth/signup_screen.dart';
import '../../features/auth/verify_email_screen.dart';
import '../../features/auth/forgot_password_screen.dart';
import '../../features/feed/feed_screen.dart';
import '../../features/map/map_screen.dart';
import '../../features/chat/chat_list_screen.dart';
import '../../features/chat/chat_thread_screen.dart';
import '../../features/chat/community_chat_screen.dart';
import '../../features/profile/edit_profile_screen.dart';
import '../../features/profile/my_profile_screen.dart';
import '../../features/profile/promoter_profile_screen.dart';
import '../../features/profile/reviews_screen.dart';
import '../../features/notifications/notifications_screen.dart';
import '../../features/event/event_detail_screen.dart';
import '../../features/event/event_create_screen.dart';
import '../../features/event/event_participants_screen.dart';
import '../../features/event/event_rate_screen.dart';
import '../providers/auth_provider.dart';
import 'main_shell.dart';

// ── Router provider ───────────────────────────────────────────────────────────

final routerProvider = Provider<GoRouter>((ref) {
  final notifier = RouterNotifier(ref);
  return GoRouter(
    initialLocation: '/splash',
    refreshListenable: notifier,
    redirect: notifier.redirect,
    routes: _routes,
  );
});

// ── Routes ────────────────────────────────────────────────────────────────────

final _routes = [
  // ── Auth ──────────────────────────────────────────────────────────────────
  GoRoute(path: '/splash', builder: (_, _) => const SplashScreen()),
  GoRoute(path: '/onboarding', builder: (_, _) => const OnboardingScreen()),
  GoRoute(path: '/login', builder: (_, _) => const LoginScreen()),
  GoRoute(path: '/signup', builder: (_, _) => const SignupScreen()),
  GoRoute(
    path: '/verify-email',
    builder: (_, state) => VerifyEmailScreen(email: state.uri.queryParameters['email']),
  ),
  GoRoute(path: '/forgot', builder: (_, _) => const ForgotPasswordScreen()),

  // ── Notifications ──────────────────────────────────────────────────────────
  GoRoute(path: '/notifications', builder: (_, _) => const NotificationsScreen()),

  // ── Events ────────────────────────────────────────────────────────────────
  GoRoute(path: '/event/new', builder: (_, _) => const EventCreateScreen()),
  GoRoute(path: '/event/:id', builder: (_, s) => EventDetailScreen(id: s.pathParameters['id']!)),
  GoRoute(
    path: '/event/:id/participants',
    builder: (_, s) => EventParticipantsScreen(eventId: s.pathParameters['id']!),
  ),
  GoRoute(
    path: '/event/:id/rate',
    builder: (_, s) => EventRateScreen(eventId: s.pathParameters['id']!),
  ),

  // ── Chat ──────────────────────────────────────────────────────────────────
  GoRoute(
    path: '/chat/:roomId',
    builder: (_, s) => ChatThreadScreen(roomId: s.pathParameters['roomId']!),
  ),
  GoRoute(
    path: '/community/:promoterId',
    builder: (_, s) => CommunityChatScreen(promoterId: s.pathParameters['promoterId']!),
  ),

  // ── Profiles ──────────────────────────────────────────────────────────────
  GoRoute(path: '/me/edit', builder: (_, _) => const EditProfileScreen()),
  GoRoute(
    path: '/promoter/:id',
    builder: (_, s) => PromoterProfileScreen(id: s.pathParameters['id']!),
  ),
  GoRoute(
    path: '/promoter/:id/reviews',
    builder: (_, s) => ReviewsScreen(promoterId: s.pathParameters['id']!),
  ),

  // ── Shell (tab bar) ───────────────────────────────────────────────────────
  ShellRoute(
    builder: (context, state, child) => MainShell(state: state, child: child),
    routes: [
      GoRoute(path: '/feed', builder: (_, _) => const FeedScreen()),
      GoRoute(
        path: '/map',
        builder: (_, state) {
          final q = state.uri.queryParameters;
          final lat   = double.tryParse(q['eventLat']   ?? '');
          final lng   = double.tryParse(q['eventLng']   ?? '');
          final title = q['eventTitle'];
          final id    = q['eventId'];
          return MapScreen(
            destinationLat:   lat,
            destinationLng:   lng,
            destinationTitle: title,
            destinationId:    id,
          );
        },
      ),
      GoRoute(path: '/messages', builder: (_, _) => const ChatListScreen()),
      GoRoute(path: '/me', builder: (_, _) => const MyProfileScreen()),
    ],
  ),
];

// ── RouterNotifier — drives GoRouter refreshes on auth state change ───────────

const _publicRoutes = ['/splash', '/onboarding', '/login', '/signup', '/verify-email', '/forgot'];

class RouterNotifier extends ChangeNotifier {
  final Ref _ref;

  RouterNotifier(this._ref) {
    _ref.listen<AsyncValue<AuthState>>(authNotifierProvider, (_, _) => notifyListeners());
  }

  String? redirect(BuildContext context, GoRouterState state) {
    final authValue = _ref.read(authNotifierProvider);

    // Keep current location while resolving (splash handles this visually)
    if (authValue.isLoading) return null;

    final auth = authValue.valueOrNull;
    final isAuthenticated = auth is AuthAuthenticated;
    final loc = state.matchedLocation;
    final isPublic = _publicRoutes.any((r) => loc.startsWith(r));

    if (!isAuthenticated && !isPublic) return '/login';

    if (auth is AuthAuthenticated) {
      final isVerified = auth.user.isVerified;
      // Redirect unverified users to email verification (allow resend endpoint)
      if (!isVerified && loc != '/verify-email') {
        return '/verify-email';
      }
      // Once verified (or if already verified), redirect away from auth screens
      if (loc == '/login' || loc == '/signup' || loc == '/onboarding' || loc == '/verify-email') {
        if (isVerified) return '/feed';
      }
    }
    return null;
  }
}
