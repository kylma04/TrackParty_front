import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:trackparty/app.dart';
import 'package:trackparty/core/api/api_exception.dart';
import 'package:trackparty/core/models/event_model.dart';
import 'package:trackparty/core/models/notification_model.dart';
import 'package:trackparty/core/providers/event_provider.dart';
import 'package:trackparty/core/providers/notification_provider.dart';
import 'package:trackparty/features/event/event_detail_screen.dart';
import 'package:trackparty/features/notifications/notifications_screen.dart';
import 'package:trackparty/widgets/tp_button.dart';
import 'package:trackparty/widgets/tp_screen_header.dart';

class _NotFoundEventDetailNotifier extends EventDetailNotifier {
  @override
  Future<EventModel> build(String id) async {
    throw const ApiException(
      message: 'Événement introuvable',
      statusCode: 404,
    );
  }
}

class _FakeNotificationsNotifier extends NotificationsNotifier {
  final NotifPage initialPage;
  _FakeNotificationsNotifier(this.initialPage);

  @override
  Future<NotifPage> build() async => initialPage;
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting('fr_FR', null);
  });

  group('parseDeepLinkRoute', () {
    test('parses trackparty:// and https://trackparty.ci event links', () {
      expect(
        parseDeepLinkRoute(
          Uri.parse('trackparty://event/evt-123?invite=CODE42'),
        ),
        '/event/evt-123?invite=CODE42',
      );
      expect(
        parseDeepLinkRoute(
          Uri.parse('https://trackparty.ci/event/evt-123?invite=CODE42'),
        ),
        '/event/evt-123?invite=CODE42',
      );
      expect(
        parseDeepLinkRoute(Uri.parse('trackparty://event/evt-123/scan')),
        '/event/evt-123/scan',
      );
      expect(
        parseDeepLinkRoute(Uri.parse('https://trackparty.ci/event/evt-123/scan')),
        '/event/evt-123/scan',
      );
      expect(
        parseDeepLinkRoute(Uri.parse('https://trackparty.ci/event/evt-123')),
        '/event/evt-123',
      );
      expect(parseDeepLinkRoute(Uri.parse('trackparty://unknown')), isNull);
    });
  });

  group('TpBackButton fallback navigation', () {
    testWidgets('redirects to /feed when navigation stack cannot pop',
        (tester) async {
      final router = GoRouter(
        initialLocation: '/solo',
        routes: [
          GoRoute(
            path: '/feed',
            builder: (_, _) => const Scaffold(body: Text('FEED_HOME')),
          ),
          GoRoute(
            path: '/solo',
            builder: (_, _) => const Scaffold(body: Center(child: TpBackButton())),
          ),
        ],
      );

      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();

      await tester.tap(find.byType(TpBackButton));
      await tester.pumpAndSettle();

      expect(find.text('FEED_HOME'), findsOneWidget);
    });

    testWidgets('pops back when navigation stack has history', (tester) async {
      final router = GoRouter(
        initialLocation: '/feed',
        routes: [
          GoRoute(
            path: '/feed',
            builder: (context, _) => Scaffold(
              body: TextButton(
                onPressed: () => context.push('/child'),
                child: const Text('OPEN_CHILD'),
              ),
            ),
          ),
          GoRoute(
            path: '/child',
            builder: (_, _) => const Scaffold(body: Center(child: TpBackButton())),
          ),
        ],
      );

      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();

      await tester.tap(find.text('OPEN_CHILD'));
      await tester.pumpAndSettle();
      expect(find.byType(TpBackButton), findsOneWidget);

      await tester.tap(find.byType(TpBackButton));
      await tester.pumpAndSettle();

      expect(find.text('OPEN_CHILD'), findsOneWidget);
    });
  });

  group('Deleted event navigation recovery', () {
    GoRouter buildEventRouter({required String initialLocation}) => GoRouter(
          initialLocation: initialLocation,
          routes: [
            GoRoute(
              path: '/feed',
              builder: (context, _) => Scaffold(
                body: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('FEED_HOME'),
                      TextButton(
                        onPressed: () => context.push('/event/deleted-evt'),
                        child: const Text('OPEN_DELETED'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            GoRoute(
              path: '/event/:id',
              builder: (_, state) =>
                  EventDetailScreen(id: state.pathParameters['id']!),
            ),
          ],
        );

    testWidgets(
        '404 error view shows active Retour button and falls back to /feed when !canPop()',
        (tester) async {
      final router = buildEventRouter(initialLocation: '/event/deleted-evt');

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            eventDetailProvider.overrideWith(_NotFoundEventDetailNotifier.new),
          ],
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text("Cet événement n'est plus disponible"), findsOneWidget);
      final backBtn = tester.widget<TpButton>(find.byType(TpButton));
      expect(backBtn.label, 'Retour');
      expect(backBtn.state, TpButtonState.idle);
      expect(backBtn.onPressed, isNotNull);
      expect(find.byType(TpBackButton), findsOneWidget);

      await tester.tap(find.byType(TpButton));
      await tester.pumpAndSettle();

      expect(find.text('FEED_HOME'), findsOneWidget);
    });

    testWidgets('404 leading TpBackButton also falls back to /feed when !canPop()',
        (tester) async {
      final router = buildEventRouter(initialLocation: '/event/deleted-evt');

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            eventDetailProvider.overrideWith(_NotFoundEventDetailNotifier.new),
          ],
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byType(TpBackButton));
      await tester.pumpAndSettle();

      expect(find.text('FEED_HOME'), findsOneWidget);
    });

    testWidgets('404 Retour button pops back cleanly when pushed from /feed',
        (tester) async {
      final router = buildEventRouter(initialLocation: '/feed');

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            eventDetailProvider.overrideWith(_NotFoundEventDetailNotifier.new),
          ],
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('OPEN_DELETED'));
      await tester.pumpAndSettle();
      expect(find.text("Cet événement n'est plus disponible"), findsOneWidget);

      await tester.tap(find.byType(TpButton));
      await tester.pumpAndSettle();
      expect(find.text('FEED_HOME'), findsOneWidget);
    });
  });

  group('NotificationsScreen unavailable invitation state', () {
    testWidgets('renders expired/deleted label instead of Voir CTA',
        (tester) async {
      final unavailableNotif = NotificationModel.fromJson({
        'id': 'notif-1',
        'notification_type': 'invitation',
        'title': 'Org t\'a invité',
        'body': 'à Soirée supprimée',
        'payload': {
          'invitation_id': 'inv-1',
          'event_id': 'evt-deleted',
        },
        'is_read': false,
        'created_at': DateTime.now().toIso8601String(),
        'action_status': 'unavailable',
      });
      expect(unavailableNotif.actionStatus, 'unavailable');

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            notificationsProvider.overrideWith(
              () => _FakeNotificationsNotifier(
                NotifPage(items: [unavailableNotif], hasMore: false),
              ),
            ),
          ],
          child: const MaterialApp(home: NotificationsScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('Invitation expirée ou événement supprimé'),
        findsOneWidget,
      );
      expect(find.text('Voir'), findsNothing);
    });
  });
}
