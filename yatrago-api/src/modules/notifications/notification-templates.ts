// Central registry of notification copy, keyed by template id.
//
// NOTE: The ~15 existing NotificationsService.createNotification call
// sites intentionally still use inline title/body strings — they have
// NOT been migrated to this registry (avoids churn). The registry is
// consumed by the SMS fallback sends (D3) and is available for a
// future migration of the in-app copy.

export type NotificationTemplateId =
  | 'booking_accepted'
  | 'booking_rejected'
  | 'booking_expired'
  | 'ride_cancelled_by_driver'
  | 'ride_cancelled_by_admin'
  | 'trip_started'
  | 'trip_completed'
  | 'refund_issued'
  | 'payout_requested'
  | 'payout_approved'
  | 'payout_rejected'
  | 'sos_confirmation';

type TemplateFn = (params: Record<string, string>) => {
  title: string;
  body: string;
};

export const NOTIFICATION_TEMPLATES: Record<NotificationTemplateId, TemplateFn> = {
  booking_accepted: (p) => ({
    title: 'Booking Confirmed!',
    body: `Your YatraGo booking from ${p.origin} to ${p.dest} has been accepted by the driver.`,
  }),
  booking_rejected: (p) => ({
    title: 'Booking Rejected',
    body: `Your YatraGo booking request${p.origin ? ` from ${p.origin} to ${p.dest}` : ''} was not accepted. You can search for another ride.`,
  }),
  booking_expired: () => ({
    title: 'Booking Expired',
    body: 'Your YatraGo booking request expired without confirmation. Any payment has been refunded to your wallet.',
  }),
  ride_cancelled_by_driver: (p) => ({
    title: 'Ride Cancelled',
    body: `Your YatraGo ride from ${p.origin} to ${p.dest} was cancelled by the driver.${p.refunded === 'true' ? ' A full refund has been credited to your wallet.' : ''}`,
  }),
  ride_cancelled_by_admin: (p) => ({
    title: 'Ride Cancelled',
    body: `Your YatraGo ride from ${p.origin} to ${p.dest} was cancelled by YatraGo.${p.refunded === 'true' ? ' A full refund has been credited to your wallet.' : ''}`,
  }),
  trip_started: (p) => ({
    title: 'Your trip has started!',
    body: `Your YatraGo ride from ${p.origin} to ${p.dest} is now in progress.`,
  }),
  trip_completed: (p) => ({
    title: 'Trip Completed!',
    body: `You have arrived at ${p.dest}. How was your ride? Please rate your driver.`,
  }),
  refund_issued: (p) => ({
    title: 'Refund Issued',
    body: `NPR ${p.amount} has been credited to your YatraGo wallet.`,
  }),
  payout_requested: (p) => ({
    title: 'Payout Requested',
    body: `Your payout request of NPR ${p.amount} via ${p.method} has been received and is pending review.`,
  }),
  payout_approved: (p) => ({
    title: 'Payout Completed',
    body: `Your payout of NPR ${p.amount} via ${p.method} has been processed.`,
  }),
  payout_rejected: (p) => ({
    title: 'Payout Rejected',
    body: `Your payout of NPR ${p.amount} was rejected: ${p.reason}. The amount has been returned to your wallet.`,
  }),
  sos_confirmation: (p) => ({
    title: 'SOS Alert Sent',
    body: `Your emergency alert has been sent to ${p.contactCount} emergency contact(s) and the YatraGo safety team.`,
  }),
};

export function renderTemplate(
  id: NotificationTemplateId,
  params: Record<string, string> = {},
): { title: string; body: string } {
  return NOTIFICATION_TEMPLATES[id](params);
}
