import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/splash_screen.dart';
import '../../features/auth/onboarding_screen.dart';
import '../../features/auth/login_screen.dart';
import '../../features/auth/signup_screen.dart';
import '../../features/auth/verify_email_screen.dart';
import '../../features/auth/forgot_password_screen.dart';
import '../../features/auth/blocked_screen.dart';
import '../../features/feed/feed_screen.dart';
import '../../features/map/map_screen.dart';
import '../../features/chat/chat_list_screen.dart';
import '../../features/chat/chat_thread_screen.dart';
import '../../features/chat/community_chat_screen.dart';
import '../../features/chat/new_chat_screen.dart';
import '../../features/calls/incoming_call_screen.dart';
import '../../features/calls/outgoing_call_screen.dart';
import '../../features/calls/call_background_screen.dart';
import '../../features/calls/call_history_screen.dart';
import '../../features/event/location_picker_screen.dart';
import '../../features/chat/invitations_screen.dart';
import '../../features/profile/edit_profile_screen.dart';
import '../../features/profile/my_profile_screen.dart';
import '../../features/profile/promoter_profile_screen.dart';
import '../../features/profile/reviews_screen.dart';
import '../../features/notifications/notifications_screen.dart';
import '../../features/event/event_detail_screen.dart';
import '../../features/ticket/ticket_screen.dart';
import '../../core/models/ticket_model.dart';
import '../../features/ticket/my_tickets_screen.dart';
import '../../features/ticket/checkin_scanner_screen.dart';
import '../../features/ticket/event_checkins_screen.dart';
import '../../features/ticket/event_staff_screen.dart';
import '../../features/event/event_coorganizers_screen.dart';
import '../../features/event/event_dashboard_screen.dart';
import '../../features/event/event_boost_screen.dart';
import '../../features/event/event_invite_screen.dart';
import '../../features/billing/plans_screen.dart';
import '../../features/payment/payment_screen.dart';
import '../../features/event/order_cart_screen.dart';
import '../../features/event/co_organizer_invitations_screen.dart';
import '../../features/event/event_create_screen.dart';
import '../models/event_model.dart';
import '../../features/event/event_participants_screen.dart';
import '../../features/event/event_rate_screen.dart';
import '../../features/event/private_join_requests_screen.dart';
import '../../features/settings/settings_screen.dart';
import '../../features/settings/help_screen.dart';
import '../../features/settings/privacy_screen.dart';
import '../../features/settings/blocked_users_screen.dart';
import '../../features/support/support_tickets_screen.dart';
import '../../features/support/new_support_ticket_screen.dart';
import '../../features/support/support_thread_screen.dart';
import '../../features/profile/saved_events_screen.dart';
import '../../features/profile/my_events_screen.dart';
import '../../features/ticket/event_waitlist_screen.dart';
import '../providers/auth_provider.dart';
import '../providers/maintenance_provider.dart';
import '../../features/system/maintenance_screen.dart';
import 'main_shell.dart';
import '../../features/profile/identity_verification_screen.dart';
import '../../features/ticket/event_tickets_screen.dart';

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

// ── Slide transition helper ───────────────────────────────────────────────────

CustomTransitionPage<T> _slide<T>(GoRouterState state, Widget child) =>
    CustomTransitionPage<T>(
      key: state.pageKey,
      child: child,
      transitionsBuilder: (_, animation, __, child) => SlideTransition(
        position: Tween<Offset>(begin: const Offset(1.0, 0.0), end: Offset.zero)
            .animate(
              CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
            ),
        child: child,
      ),
    );

// ── Routes ────────────────────────────────────────────────────────────────────

final _routes = [
  // ── Auth ──────────────────────────────────────────────────────────────────
  GoRoute(path: '/splash', builder: (_, _) => const SplashScreen()),
  GoRoute(path: '/onboarding', builder: (_, _) => const OnboardingScreen()),
  GoRoute(path: '/login', builder: (_, _) => const LoginScreen()),
  GoRoute(path: '/signup', builder: (_, _) => const SignupScreen()),
  GoRoute(
    path: '/verify-email',
    builder: (_, state) => VerifyEmailScreen(
      email: state.uri.queryParameters['email'],
      password: state.extra as String?,
    ),
  ),
  GoRoute(
    path: '/forgot',
    builder: (_, s) => ForgotPasswordScreen(prefilledEmail: s.extra as String?),
  ),
  GoRoute(path: '/blocked', builder: (_, _) => const BlockedScreen()),
  GoRoute(path: '/maintenance', builder: (_, _) => const MaintenanceScreen()),

  // ── Notifications ──────────────────────────────────────────────────────────
  GoRoute(
    path: '/notifications',
    pageBuilder: (_, s) => _slide(s, const NotificationsScreen()),
  ),
  GoRoute(
    path: '/invitations',
    pageBuilder: (_, s) => _slide(s, const InvitationsScreen()),
  ),
  GoRoute(
    path: '/calls/history',
    pageBuilder: (_, s) => _slide(s, const CallHistoryScreen()),
  ),
  GoRoute(
    path: '/call/incoming',
    builder: (_, _) => const IncomingCallScreen(),
  ),
  GoRoute(
    path: '/call/outgoing',
    builder: (_, s) {
      final extra = s.extra as Map<String, dynamic>? ?? {};
      return OutgoingCallScreen(
        callType: extra['callType'] as String? ?? 'audio',
        remoteUserName: extra['remoteUserName'] as String? ?? '',
        remoteUserAvatarUrl: extra['remoteUserAvatarUrl'] as String?,
      );
    },
  ),
  GoRoute(
    path: '/location-picker',
    builder: (_, s) {
      final extra = s.extra as Map<String, dynamic>? ?? {};
      return LocationPickerScreen(
        initialLat: extra['lat'] as double?,
        initialLng: extra['lng'] as double?,
      );
    },
  ),

  // ── Events ────────────────────────────────────────────────────────────────
  GoRoute(path: '/event/new', builder: (_, _) => const EventCreateScreen()),
  GoRoute(
    path: '/event/:id/edit',
    builder: (_, s) {
      final event = s.extra as EventModel?;
      return EventCreateScreen(initialEvent: event);
    },
  ),
  GoRoute(
    path: '/event/:id/clone',
    builder: (_, s) {
      final event = s.extra as EventModel?;
      return EventCreateScreen(initialEvent: event, isClone: true);
    },
  ),
  GoRoute(
    path: '/event/:id',
    pageBuilder: (_, s) => _slide(
        s,
        EventDetailScreen(
          id: s.pathParameters['id']!,
          inviteCode: s.uri.queryParameters['invite'],
        )),
  ),
  
  GoRoute(
    path: '/event/:id/participants',
    builder: (_, s) =>
        EventParticipantsScreen(eventId: s.pathParameters['id']!),
  ),
  GoRoute(
    path: '/event/:id/rate',
    builder: (_, s) => EventRateScreen(eventId: s.pathParameters['id']!),
  ),
  GoRoute(
    path: '/event/:id/scan',
    builder: (_, s) {
      final extra = s.extra as Map<String, dynamic>?;
      return CheckinScannerScreen(
        eventId: s.pathParameters['id']!,
        eventTitle: extra?['title'] as String? ?? '',
      );
    },
  ),
  GoRoute(
    path: '/ticket/:eventId',
    pageBuilder: (_, s) => _slide(
      s,
      TicketScreen(
        eventId: s.pathParameters['eventId']!,
        ticket: s.extra as TicketModel?,
      ),
    ),
  ),
  GoRoute(
    path: '/event/:eventId/tickets',
    pageBuilder: (_, s) => _slide(
      s,
      EventTicketsScreen(
        eventId: s.pathParameters['eventId']!,
        eventTitle: (s.extra as Map<String, dynamic>?)?['title'] as String? ?? '',
      ),
    ),
  ),
  GoRoute(
    path: '/my-tickets',
    pageBuilder: (_, s) => _slide(s, const MyTicketsScreen()),
  ),
  GoRoute(
    path: '/event/:id/checkins',
    builder: (_, s) {
      final extra = s.extra as Map<String, dynamic>?;
      return EventCheckinsScreen(
        eventId: s.pathParameters['id']!,
        eventTitle: extra?['title'] as String? ?? '',
      );
    },
  ),
  GoRoute(
    path: '/event/:id/staff',
    builder: (_, s) {
      final extra = s.extra as Map<String, dynamic>?;
      return EventStaffScreen(
        eventId: s.pathParameters['id']!,
        eventTitle: extra?['title'] as String? ?? '',
      );
    },
  ),

  GoRoute(
    path: '/event/:id/dashboard',
    builder: (_, s) {
      final extra = s.extra as Map<String, dynamic>?;
      return EventDashboardScreen(
        eventId: s.pathParameters['id']!,
        eventTitle: extra?['title'] as String? ?? '',
      );
    },
  ),

  GoRoute(
    path: '/event/:id/boost',
    builder: (_, s) {
      final extra = s.extra as Map<String, dynamic>?;
      return EventBoostScreen(
        eventId: s.pathParameters['id']!,
        eventTitle: extra?['title'] as String? ?? '',
      );
    },
  ),

  GoRoute(
    path: '/event/:id/pay',
    builder: (_, s) {
      final extra = (s.extra as Map<String, dynamic>?) ?? const {};
      return PaymentScreen(
        eventId: s.pathParameters['id']!,
        categoryId: extra['categoryId'] as String? ?? '',
        categoryName: extra['categoryName'] as String? ?? '',
        amount: (extra['amount'] as num?)?.toInt() ?? 0,
      );
    },
  ),

  GoRoute(
    path: '/event/:id/participate',
    builder: (_, s) => OrderCartScreen(event: s.extra as EventModel),
  ),

  GoRoute(
    path: '/event/:id/invite',
    builder: (_, s) {
      final extra = s.extra as Map<String, dynamic>?;
      return EventInviteScreen(
        eventId: s.pathParameters['id']!,
        eventTitle: extra?['title'] as String? ?? '',
      );
    },
  ),

  GoRoute(
    path: '/event/:id/private-requests',
    builder: (_, s) {
      final extra = s.extra as Map<String, dynamic>?;
      return PrivateJoinRequestsScreen(
        eventId: s.pathParameters['id']!,
        eventTitle: extra?['title'] as String? ?? '',
      );
    },
  ),

  GoRoute(
    path: '/event/:id/co-organizers',
    builder: (_, s) {
      final extra = s.extra as Map<String, dynamic>?;
      return EventCoOrganizersScreen(
        eventId: s.pathParameters['id']!,
        eventTitle: extra?['title'] as String? ?? '',
      );
    },
  ),
  GoRoute(
    path: '/co-organizer-invitations',
    builder: (_, _) => const CoOrganizerInvitationsScreen(),
  ),

  // ── Chat ──────────────────────────────────────────────────────────────────
  GoRoute(
    path: '/chat/new',
    builder: (_, s) {
      final extra = s.extra as Map<String, dynamic>? ?? {};
      return NewChatScreen(
        userId: extra['userId'] as String,
        displayName: extra['displayName'] as String,
        avatarUrl: extra['avatarUrl'] as String?,
      );
    },
  ),
  GoRoute(
    path: '/chat/:roomId',
    pageBuilder: (_, s) =>
        _slide(s, ChatThreadScreen(roomId: s.pathParameters['roomId']!)),
  ),
  GoRoute(
    path: '/community/:promoterId',
    builder: (_, s) =>
        CommunityChatScreen(promoterId: s.pathParameters['promoterId']!),
  ),

  // ── Profiles ──────────────────────────────────────────────────────────────
  GoRoute(
    path: '/settings',
    pageBuilder: (_, s) => _slide(s, const SettingsScreen()),
  ),
  GoRoute(
    path: '/help',
    pageBuilder: (_, s) => _slide(s, const HelpScreen()),
  ),
  GoRoute(
    path: '/calls/background',
    pageBuilder: (_, s) => _slide(s, const CallBackgroundScreen()),
  ),
  GoRoute(
    path: '/plans',
    pageBuilder: (_, s) => _slide(s, const PlansScreen()),
  ),
  GoRoute(
    path: '/privacy',
    pageBuilder: (_, s) => _slide(s, const PrivacyScreen()),
  ),
  GoRoute(
    path: '/blocked-users',
    pageBuilder: (_, s) => _slide(s, const BlockedUsersScreen()),
  ),
  GoRoute(
    path: '/support',
    pageBuilder: (_, s) => _slide(s, const SupportTicketsScreen()),
  ),
  GoRoute(
    path: '/support/new',
    pageBuilder: (_, s) => _slide(s, const NewSupportTicketScreen()),
  ),
  GoRoute(
    path: '/support/:id',
    pageBuilder: (_, s) =>
        _slide(s, SupportThreadScreen(id: s.pathParameters['id']!)),
  ),
  GoRoute(
    path: '/saved-events',
    pageBuilder: (_, s) => _slide(s, const SavedEventsScreen()),
  ),
  GoRoute(
    path: '/my-events',
    pageBuilder: (_, s) => _slide(
      s,
      MyEventsScreen(
        initialTab: s.uri.queryParameters['tab'] ?? 'participating',
      ),
    ),
  ),
  GoRoute(
    path: '/event/:id/waitlist',
    builder: (_, s) {
      final extra = s.extra as Map<String, dynamic>?;
      return EventWaitlistScreen(
        eventId: s.pathParameters['id']!,
        eventTitle: extra?['title'] as String? ?? '',
      );
    },
  ),
  GoRoute(
    path: '/me/edit',
    pageBuilder: (_, s) => _slide(s, const EditProfileScreen()),
  ),
  GoRoute(
    path: '/identity-verification',
    pageBuilder: (_, s) => _slide(s, const IdentityVerificationScreen()),
  ),
  GoRoute(
    path: '/promoter/:id',
    pageBuilder: (_, s) =>
        _slide(s, PromoterProfileScreen(id: s.pathParameters['id']!)),
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
          final lat = double.tryParse(q['eventLat'] ?? '');
          final lng = double.tryParse(q['eventLng'] ?? '');
          final title = q['eventTitle'];
          final id = q['eventId'];
          return MapScreen(
            destinationLat: lat,
            destinationLng: lng,
            destinationTitle: title,
            destinationId: id,
          );
        },
      ),
      GoRoute(path: '/messages', builder: (_, _) => const ChatListScreen()),
      GoRoute(path: '/me', builder: (_, _) => const MyProfileScreen()),
    ],
  ),
];

// ── RouterNotifier — drives GoRouter refreshes on auth state change ───────────

const _publicRoutes = [
  '/splash',
  '/onboarding',
  '/login',
  '/signup',
  '/verify-email',
  '/forgot',
];

class RouterNotifier extends ChangeNotifier {
  final Ref _ref;

  RouterNotifier(this._ref) {
    _ref.listen<AsyncValue<AuthState>>(
      authNotifierProvider,
      (_, _) => notifyListeners(),
    );
    // Bascule immédiate vers / depuis l'écran de maintenance.
    _ref.listen<MaintenanceInfo?>(
      maintenanceProvider,
      (_, _) => notifyListeners(),
    );
  }

  String? redirect(BuildContext context, GoRouterState state) {
    final loc = state.matchedLocation;

    // Maintenance globale : priorité absolue, confine sur l'écran dédié.
    final maintenance = _ref.read(maintenanceProvider);
    if (maintenance != null) {
      return loc == '/maintenance' ? null : '/maintenance';
    }
    // Maintenance levée : on quitte l'écran et on relance le flux normal.
    if (loc == '/maintenance') return '/splash';

    final authValue = _ref.read(authNotifierProvider);

    // Keep current location while resolving (splash handles this visually)
    if (authValue.isLoading) return null;

    final auth = authValue.valueOrNull;
    final isAuthenticated = auth is AuthAuthenticated;
    final isPublic = _publicRoutes.any((r) => loc.startsWith(r));

    // Compte bloqué par la modération : confiné à l'écran dédié.
    if (auth is AuthBlocked) {
      return loc == '/blocked' ? null : '/blocked';
    }

    if (!isAuthenticated && !isPublic) return '/login';

    if (auth is AuthAuthenticated) {
      final isVerified = auth.user.isVerified;
      // Redirect unverified users to email verification (allow resend endpoint)
      if (!isVerified && loc != '/verify-email') {
        return '/verify-email';
      }
      // Once verified (or if already verified), redirect away from auth screens
      if (loc == '/login' ||
          loc == '/signup' ||
          loc == '/onboarding' ||
          loc == '/verify-email') {
        if (isVerified) return '/feed';
      }
    }
    return null;
  }
}
