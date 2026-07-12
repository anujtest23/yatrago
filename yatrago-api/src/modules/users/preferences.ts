// Channel × category notification matrix and privacy settings, with
// all-defaults merge helpers. Stored on User.notificationPreferences and
// User.privacySettings (JSON). Merges are strict: only known keys from a
// client payload are applied, so an untrusted body can never inject fields.

export const NOTIFICATION_CHANNELS = ['push', 'email', 'sms'] as const;
export type NotificationChannel = (typeof NOTIFICATION_CHANNELS)[number];

export const PREFERENCE_CATEGORIES = [
  'booking',
  'payment',
  'wallet',
  'chat',
  'promotions',
  'security',
] as const;
export type PreferenceCategory = (typeof PREFERENCE_CATEGORIES)[number];

export type ChannelMatrix = Record<
  PreferenceCategory,
  Record<NotificationChannel, boolean>
>;

function fullyOn(): Record<NotificationChannel, boolean> {
  return { push: true, email: true, sms: true };
}

export function defaultNotificationPreferences(): ChannelMatrix {
  const matrix = {} as ChannelMatrix;
  for (const cat of PREFERENCE_CATEGORIES) matrix[cat] = fullyOn();
  // Promotions default to push-only; security cannot be fully silenced by SMS
  // is left on for transactional safety.
  matrix.promotions = { push: true, email: false, sms: false };
  return matrix;
}

export function mergeNotificationPreferences(stored: unknown): ChannelMatrix {
  const result = defaultNotificationPreferences();
  if (stored && typeof stored === 'object' && !Array.isArray(stored)) {
    const s = stored as Record<string, any>;
    for (const cat of PREFERENCE_CATEGORIES) {
      const catVal = s[cat];
      if (catVal && typeof catVal === 'object') {
        for (const ch of NOTIFICATION_CHANNELS) {
          if (typeof catVal[ch] === 'boolean') result[cat][ch] = catVal[ch];
        }
      }
    }
  }
  return result;
}

// ── Privacy ──────────────────────────────────────────────────────
export const VISIBILITY_OPTIONS = ['public', 'contacts', 'private'] as const;
export type Visibility = (typeof VISIBILITY_OPTIONS)[number];

export interface PrivacySettings {
  profileVisibility: Visibility;
  phoneVisibility: Visibility;
  rideVisibility: Visibility;
  marketingConsent: boolean;
  analyticsConsent: boolean;
}

export function defaultPrivacySettings(): PrivacySettings {
  return {
    profileVisibility: 'public',
    phoneVisibility: 'contacts',
    rideVisibility: 'public',
    marketingConsent: false,
    analyticsConsent: true,
  };
}

export function mergePrivacySettings(stored: unknown): PrivacySettings {
  const result = defaultPrivacySettings();
  if (stored && typeof stored === 'object' && !Array.isArray(stored)) {
    const s = stored as Record<string, any>;
    for (const key of ['profileVisibility', 'phoneVisibility', 'rideVisibility'] as const) {
      if (VISIBILITY_OPTIONS.includes(s[key])) result[key] = s[key];
    }
    for (const key of ['marketingConsent', 'analyticsConsent'] as const) {
      if (typeof s[key] === 'boolean') result[key] = s[key];
    }
  }
  return result;
}
