import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:kouvention/cores/constants/tokens.dart';
import 'package:kouvention/features/auth/services/auth_service.dart';
import 'package:kouvention/features/chat/services/debug/debug_chat_seeder.dart';

/// Debug-only screen for seeding chats with N messages so the older-
/// message pagination (AGENTS.md §5 / §11.2) can be exercised on a real
/// device with a real Firestore. Gated by [kDebugMode] — the app bar
/// button that opens this view is only rendered in debug builds.
class DebugSeederView extends ConsumerStatefulWidget {
  const DebugSeederView({super.key});

  @override
  ConsumerState<DebugSeederView> createState() => _DebugSeederViewState();
}

class _DebugSeederViewState extends ConsumerState<DebugSeederView> {
  bool _isSeeding = false;
  int _seeded = 0;
  int _target = 0;
  String? _lastChatId;
  String? _error;
  int _softDeleted = 0;
  bool _isDeleting = false;

  Future<void> _seedChat(int count) async {
    if (_isSeeding) return;
    final currentUid = ref.read(authServiceProvider).currentUser?.uid;
    if (currentUid == null) {
      setState(() => _error = 'Not signed in');
      return;
    }

    setState(() {
      _isSeeding = true;
      _seeded = 0;
      _target = count;
      _error = null;
    });

    try {
      final seeder = ref.read(debugChatSeederProvider);
      await for (final progress in seeder.seedChat(
        currentUid: currentUid,
        messageCount: count,
      )) {
        if (!mounted) return;
        setState(() {
          _seeded = progress.seeded;
          _lastChatId = progress.chatId ?? _lastChatId;
        });
      }
    } catch (e, s) {
      if (!mounted) return;
      setState(() => _error = 'Seed failed: $e\n$s');
    } finally {
      if (mounted) setState(() => _isSeeding = false);
    }
  }

  Future<void> _deleteDebugChats() async {
    if (_isDeleting) return;
    final currentUid = ref.read(authServiceProvider).currentUser?.uid;
    if (currentUid == null) return;

    setState(() {
      _isDeleting = true;
      _error = null;
    });
    try {
      final seeder = ref.read(debugChatSeederProvider);
      final softDeleted = await seeder.deleteDebugChats(currentUid: currentUid);
      if (!mounted) return;
      setState(() {
        _softDeleted = softDeleted;
        _lastChatId = null;
      });
    } catch (e, s) {
      if (!mounted) return;
      setState(() => _error = 'Soft-delete failed: $e\n$s');
    } finally {
      if (mounted) setState(() => _isDeleting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Debug Seeder'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(16.w),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (!kDebugMode)
                const Padding(
                  padding: EdgeInsets.only(bottom: 16),
                  child: Text(
                    'WARNING: this view is only available in debug builds. '
                    'You should not be seeing it in production.',
                    style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                  ),
                ),
              const Text(
                'Seeds a direct chat with the Debug Bot and N text messages, '
                'spaced 1 minute apart ending now. Each message is a real '
                'Firestore document. Use this to exercise older-message '
                'pagination (Phase 5).',
                style: TextStyle(fontSize: 14),
              ),
              Gap(24.h),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _isSeeding ? null : () => _seedChat(250),
                      icon: const Icon(Icons.bolt),
                      label: const Text('Seed 250 messages'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                  Gap(12.w),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _isSeeding ? null : () => _seedChat(1000),
                      icon: const Icon(Icons.flash_on),
                      label: const Text('Seed 1000 messages'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
              Gap(16.h),
              if (_isSeeding || _seeded > 0)
                _ProgressCard(seeded: _seeded, target: _target),
              if (_lastChatId != null) ...[
                Gap(16.h),
                _LastChatCard(chatId: _lastChatId!),
              ],
              if (_softDeleted > 0) ...[
                Gap(8.h),
                Text(
                  'Soft-deleted $_softDeleted debug chat(s) from your chat list. '
                  'Firestore docs remain (security rules block chat deletion); '
                  'use the Firebase console to wipe them.',
                  style: const TextStyle(color: Colors.green, fontSize: 12),
                ),
              ],
              if (_error != null) ...[
                Gap(16.h),
                Container(
                  padding: EdgeInsets.all(12.w),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8.r),
                    border: Border.all(color: Colors.red),
                  ),
                  child: Text(
                    _error!,
                    style: const TextStyle(color: Colors.red, fontSize: 12),
                  ),
                ),
              ],
              const Spacer(),
              OutlinedButton.icon(
                onPressed: _isDeleting ? null : _deleteDebugChats,
                icon: const Icon(Icons.delete_sweep, color: Colors.red),
                label: Text(
                  _isDeleting ? 'Soft-deleting...' : 'Hide all debug chats',
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red,
                  side: const BorderSide(color: Colors.red),
                ),
              ),
              Gap(8.h),
              const Text(
                'Soft-delete: stamps a local deletedBy flag on every chat '
                'where the Debug Bot is a member, so they vanish from your '
                'chat list. Firestore docs are preserved (security rules '
                'block chat deletion); use the Firebase console to wipe them.',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProgressCard extends StatelessWidget {
  final int seeded;
  final int target;

  const _ProgressCard({required this.seeded, required this.target});

  @override
  Widget build(BuildContext context) {
    final pct = target == 0 ? 0.0 : seeded / target;
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12.r),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Seeded $seeded / $target',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          Gap(8.h),
          LinearProgressIndicator(
            value: pct,
            backgroundColor: Colors.grey[300],
            valueColor: AlwaysStoppedAnimation<Color>(Theme.of(context).colorScheme.primary),
          ),
        ],
      ),
    );
  }
}

class _LastChatCard extends StatelessWidget {
  final String chatId;

  const _LastChatCard({required this.chatId});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: Colors.green.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8.r),
        border: Border.all(color: Colors.green),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Last seeded chat:',
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green),
          ),
          Gap(4.h),
          SelectableText(
            chatId,
            style: const TextStyle(fontSize: 11, fontFamily: 'monospace'),
          ),
        ],
      ),
    );
  }
}
