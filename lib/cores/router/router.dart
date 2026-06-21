import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:kouvention/cores/router/router_constants.dart';
import 'package:kouvention/cores/router/router_guard.dart';
import 'package:kouvention/cores/widgets/main_shell.dart';
import 'package:kouvention/features/auth/services/auth_service.dart';
import 'package:kouvention/features/auth/views/add_name_view.dart';
import 'package:kouvention/features/auth/views/email_sign_in_view.dart';
import 'package:kouvention/features/auth/views/login_view.dart';
import 'package:kouvention/features/auth/views/sign_up_view.dart';
import 'package:kouvention/features/chat/viewmodel/media/media_preview_viewmodel.dart';
import 'package:kouvention/features/chat/views/chat_list_view.dart';
import 'package:kouvention/features/chat/views/chat_profile_view.dart';
import 'package:kouvention/features/chat/views/chat_room_view.dart';
import 'package:kouvention/features/chat/views/group_setup_view.dart';
import 'package:kouvention/features/chat/views/media_preview_view.dart';
import 'package:kouvention/features/chat/views/new_chat_view.dart';
import 'package:kouvention/features/chat/views/new_group_chat_view.dart';
import 'package:kouvention/features/onboarding/views/onboarding_view.dart';
import 'package:kouvention/features/privacy_policy/views/privacy_policy_view.dart';
import 'package:kouvention/features/profile/views/appearence_settings_view.dart';
import 'package:kouvention/features/profile/views/edit_name_view.dart';
import 'package:kouvention/features/profile/views/edit_status_view..dart';
import 'package:kouvention/features/profile/views/notification_settings_view.dart';
import 'package:kouvention/features/profile/views/privacy_settings_view.dart';
import 'package:kouvention/features/profile/views/profile_view.dart';
import 'package:kouvention/features/splash/views/splash_view.dart';
import 'package:kouvention/features/story/models/story_viewer_args.dart';
import 'package:kouvention/features/story/views/story_feed_view.dart';
import 'package:kouvention/features/story/views/story_viewer_view.dart';
import 'package:kouvention/features/user/models/user_model.dart';

GoRouter? _router;
GoRouter get router => _router!;

final RouteObserver<ModalRoute<void>> routeObserver =
    RouteObserver<ModalRoute<void>>();

final GlobalKey<NavigatorState> _chatBranchKey = GlobalKey<NavigatorState>(
  debugLabel: 'chatBranch',
);
final GlobalKey<NavigatorState> _profileBranchKey = GlobalKey<NavigatorState>(
  debugLabel: 'profileBranch',
);
final GlobalKey<NavigatorState> _storyBranchKey = GlobalKey<NavigatorState>(
  debugLabel: 'storyBranch',
);

setupRouter({
  required String initialRouter,
  required AuthService authService,
  required RouterGuard routerGuard,
}) {
  if (_router != null) return;

  _router = GoRouter(
    initialLocation: initialRouter,
    navigatorKey: navigatorKey,
    refreshListenable: routerGuard,
    observers: [routeObserver],
    redirect: (context, state) {
      final currentPath = state.matchedLocation;
      debugPrint('GUARD: path = $currentPath');

      // Splash always return true.
      if (currentPath == RouterRoutes.splash.path) return null;

      if (!routerGuard.onboardingSeen) {
        // navigate if the user is not in onboarding
        if (currentPath != RouterRoutes.onboarding.path) {
          debugPrint('GUARD: has not seen onboarding → /onboarding');
          return RouterRoutes.onboarding.path;
        }
        // already in onboarding, just stay still
        return null;
      }

      if (!routerGuard.privacyPolicySeen) {
        // navigate if user on page other than privacy policy
        if (currentPath != RouterRoutes.privacyPolicy.path) {
          debugPrint('GUARD: has not seen privacy policy → /privacyPolicy');
          return RouterRoutes.privacyPolicy.path;
        }

        return null;
      }

      if (!routerGuard.isLoggedIn) {
        final authPages = [
          RouterRoutes.login.path,
          RouterRoutes.signUp.path,
          RouterRoutes.emailSignIn.path,
        ];
        if (!authPages.contains(currentPath)) {
          debugPrint('GUARD: not logged in → /login');
          return RouterRoutes.login.path;
        }

        return null;
      }

      // --------------- USER ALREADY PASS EVERY CONDITIONS
      final authPages = [
        RouterRoutes.login.path,
        RouterRoutes.signUp.path,
        RouterRoutes.emailSignIn.path,
      ];

      if (authPages.contains(currentPath)) {
        debugPrint('GUARD: Logged in but on auth page -> /chats');
        return RouterRoutes.chatList.path;
      }

      // What if user hasn't set a name?
      if (!routerGuard.hasDisplayName) {
        if (currentPath != RouterRoutes.addName.path) {
          debugPrint('GUARD: no display name → /add-name');
          return RouterRoutes.addName.path;
        }
      }

      debugPrint('GUARD: all checks passed ✅');
      return null;
    },
    routes: [
      // ── Public routes (no navbar) ─────────────────
      GoRoute(
        path: RouterRoutes.splash.path,
        name: RouterRoutes.splash.name,
        builder: (_, _) => const SplashView(),
      ),
      GoRoute(
        path: RouterRoutes.login.path,
        name: RouterRoutes.login.name,
        builder: (_, _) => LoginView(),
      ),
      GoRoute(
        path: RouterRoutes.emailSignIn.path,
        name: RouterRoutes.emailSignIn.name,
        builder: (_, _) => EmailSignInView(),
      ),
      GoRoute(
        path: RouterRoutes.addName.path,
        name: RouterRoutes.addName.name,
        builder: (_, _) => AddNameView(),
      ),
      GoRoute(
        path: RouterRoutes.signUp.path,
        name: RouterRoutes.signUp.name,
        builder: (_, _) => SignUpView(),
      ),
      GoRoute(
        path: RouterRoutes.onboarding.path,
        name: RouterRoutes.onboarding.name,
        builder: (_, _) => const OnboardingView(),
      ),
      GoRoute(
        path: RouterRoutes.privacyPolicy.path,
        name: RouterRoutes.privacyPolicy.name,
        builder: (_, _) => PrivacyPolicyView(),
      ),

      // ── Shell (navbar visible) ────────────────────
      StatefulShellRoute.indexedStack(
        builder: (_, __, navigationShell) =>
            MainShell(navigationShell: navigationShell),
        branches: [
          // Tab 0: Chats
          StatefulShellBranch(
            navigatorKey: _chatBranchKey,
            routes: [
              GoRoute(
                path: RouterRoutes.chatList.path,
                name: RouterRoutes.chatList.name,
                builder: (_, _) => ChatListView(),
              ),
            ],
          ),
          // Tab 1: Stories
          StatefulShellBranch(
            navigatorKey: _storyBranchKey,
            routes: [
              GoRoute(
                path: RouterRoutes.storyFeed.path,
                name: RouterRoutes.storyFeed.name,
                builder: (_, _) => const StoryFeedView(),
              ),
            ],
          ),
          // Tab 2: Profile
          StatefulShellBranch(
            navigatorKey: _profileBranchKey,
            routes: [
              GoRoute(
                path: RouterRoutes.profile.path,
                name: RouterRoutes.profile.name,
                builder: (_, _) => ProfileView(),
              ),
            ],
          ),
        ],
      ),

      // ── Protected routes (no navbar) ──────────────
      GoRoute(
        path: RouterRoutes.storyViewer.path,
        name: RouterRoutes.storyViewer.name,
        builder: (_, state) =>
            StoryViewerView(args: state.extra as StoryViewerArgs),
      ),
      GoRoute(
        path: RouterRoutes.chatRoom.path,
        name: RouterRoutes.chatRoom.name,
        builder: (_, state) {
          final chatId = state.pathParameters['chatId']!;
          return ChatRoomView(chatId: chatId);
        },
        routes: [
          GoRoute(
            path: 'media-preview',
            name: RouterRoutes.mediaPreview.name,
            builder: (context, state) {
              final chatId = state.pathParameters['chatId']!;
              final args = state.extra as MediaPreviewArgs;
              return MediaPreviewView(chatId: chatId, args: args);
            },
          ),
        ],
      ),
      GoRoute(
        path: RouterRoutes.newChat.path,
        name: RouterRoutes.newChat.name,
        builder: (_, _) => NewChatView(),
      ),
      GoRoute(
        path: RouterRoutes.newGroupChat.path,
        name: RouterRoutes.newGroupChat.name,
        builder: (_, _) => NewGroupChatView(),
      ),
      GoRoute(
        path: RouterRoutes.groupSetup.path,
        name: RouterRoutes.groupSetup.name,
        builder: (_, state) =>
            GroupSetupView(selectedUsers: state.extra as List<UserModel>),
      ),
      GoRoute(
        path: RouterRoutes.chatDetail.path,
        name: RouterRoutes.chatDetail.name,
        builder: (_, state) {
          final chatId = state.pathParameters['chatId'] as String;
          return ChatProfileView(chatId: chatId);
        },
      ),
      GoRoute(
        path: RouterRoutes.editName.path,
        name: RouterRoutes.editName.name,
        builder: (_, state) => EditNameView(currentName: state.extra as String),
      ),
      GoRoute(
        path: RouterRoutes.editStatus.path,
        name: RouterRoutes.editStatus.name,
        builder: (_, state) =>
            EditStatusView(currentStatus: state.extra as String?),
      ),
      GoRoute(
        path: RouterRoutes.privacySettings.path,
        name: RouterRoutes.privacySettings.name,
        builder: (_, _) => const PrivacySettingsView(),
      ),
      GoRoute(
        path: RouterRoutes.notificationSettings.path,
        name: RouterRoutes.notificationSettings.name,
        builder: (_, _) => const NotificationSettingsView(),
      ),
      GoRoute(
        path: RouterRoutes.appearanceSettings.path,
        name: RouterRoutes.appearanceSettings.name,
        builder: (_, _) => const AppearanceSettingsView(),
      ),
    ],
  );
}
