/**
 * Nepal mobile numbers: +977 followed by a 10-digit mobile starting 96–98
 * (NTC/Ncell/SmartCell allocations). Landlines are deliberately excluded —
 * OTP delivery requires a mobile subscriber number.
 */
export const NEPAL_MOBILE_REGEX = /^\+9779[6-8]\d{8}$/;

export const NEPAL_MOBILE_MESSAGE =
  'Phone number must be a valid Nepal mobile number (+9779XXXXXXXXX)';
