import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../../core/constants/app_colors.dart';
import '../models/notification_model.dart';
import '../providers/notifications_provider.dart';

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifsAsync = ref.watch(notificationsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notificaciones'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/dashboard');
            }
          },
        ),
        actions: [
          TextButton(
            onPressed: () =>
                ref.read(notificationsControllerProvider.notifier).markAllRead(),
            child: const Text('Marcar todo leído'),
          ),
        ],
      ),
      body: notifsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.cloud_off_rounded,
                    size: 56, color: AppColors.textHint),
                SizedBox(height: 12),
                Text('No pudimos cargar tus notificaciones',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w600)),
                SizedBox(height: 6),
                Text('Revisa tu conexión e intenta de nuevo.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 14, color: AppColors.textSecondary)),
              ],
            ),
          ),
        ),
        data: (notifs) {
          if (notifs.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.notifications_none_outlined,
                      size: 64, color: AppColors.textHint),
                  SizedBox(height: 16),
                  Text(
                    'Sin notificaciones',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Aquí aparecerán tus actualizaciones',
                    style:
                        TextStyle(color: AppColors.textHint, fontSize: 13),
                  ),
                ],
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: notifs.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (_, i) => _NotificationTile(notif: notifs[i]),
          );
        },
      ),
    );
  }
}

class _NotificationTile extends ConsumerWidget {
  final AppNotification notif;
  const _NotificationTile({required this.notif});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final icon = _iconForType(notif.type);
    final color = _colorForType(notif.type);

    return InkWell(
      onTap: () {
        ref.read(notificationsControllerProvider.notifier).markRead(notif.id);
        // Navegar a la reserva si existe
        if (notif.bookingId != null) {
          context.push('/bookings');
        }
      },
      child: Container(
        color: notif.isRead ? null : color.withValues(alpha: 0.05),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Ícono de tipo
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          notif.title,
                          style: TextStyle(
                            fontWeight: notif.isRead
                                ? FontWeight.w500
                                : FontWeight.w700,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      if (!notif.isRead)
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: AppColors.primary,
                            shape: BoxShape.circle,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    notif.body,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                      height: 1.4,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    timeago.format(notif.createdAt, locale: 'es'),
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textHint,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _iconForType(NotificationType type) {
    switch (type) {
      case NotificationType.bookingAccepted:
        return Icons.check_circle_outline;
      case NotificationType.bookingRejected:
        return Icons.cancel_outlined;
      case NotificationType.bookingCompleted:
        return Icons.emoji_events_outlined;
      case NotificationType.newBookingRequest:
        return Icons.notifications_active_outlined;
      case NotificationType.newReview:
        return Icons.star_outline;
      case NotificationType.requestExpired:
        return Icons.hourglass_disabled_outlined;
    }
  }

  Color _colorForType(NotificationType type) {
    switch (type) {
      case NotificationType.bookingAccepted:
        return AppColors.success;
      case NotificationType.bookingRejected:
        return AppColors.error;
      case NotificationType.bookingCompleted:
        return AppColors.primary;
      case NotificationType.newBookingRequest:
        return AppColors.warning;
      case NotificationType.newReview:
        return AppColors.goldDark;
      case NotificationType.requestExpired:
        return AppColors.textSecondary;
    }
  }
}
