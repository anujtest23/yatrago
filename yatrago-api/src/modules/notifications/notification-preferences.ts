// Notification preference categories and the NotifType → category map.

export const NOTIFICATION_CATEGORIES = [
  'bookings',
  'trips',
  'payments',
  'promotions',
  'safety',
] as const;

export type NotificationCategory = (typeof NOTIFICATION_CATEGORIES)[number];

export type NotificationSettings = Record<NotificationCategory, boolean>;

export const DEFAULT_NOTIFICATION_SETTINGS: NotificationSettings = {
  bookings: true,
  trips: true,
  payments: true,
  promotions: true,
  safety: true,
};

export function categoryForNotifType(type: string): NotificationCategory {
  if (type.startsWith('booking_') || type === 'ride_reminder') return 'bookings';
  if (type.startsWith('trip_')) return 'trips';
  if (
    type === 'payment_received' ||
    type === 'refund_issued' ||
    type === 'payout_update'
  ) {
    return 'payments';
  }
  if (type === 'promotion') return 'promotions';
  if (type === 'sos_alert') return 'safety';
  // 'system' and anything unknown default to the bookings category
  return 'bookings';
}

// Merge whatever is stored on User.notificationSettings over all-true defaults.
export function mergeNotificationSettings(stored: unknown): NotificationSettings {
  const settings = { ...DEFAULT_NOTIFICATION_SETTINGS };
  if (stored && typeof stored === 'object' && !Array.isArray(stored)) {
    for (const category of NOTIFICATION_CATEGORIES) {
      const value = (stored as Record<string, unknown>)[category];
      if (typeof value === 'boolean') settings[category] = value;
    }
  }
  return settings;
}
