import { Injectable } from '@nestjs/common';
import {
  collectDefaultMetrics,
  Counter,
  Histogram,
  Registry,
} from 'prom-client';

/**
 * Prometheus metrics. Exposed at GET /metrics (see MetricsController) only
 * when METRICS_TOKEN is configured — the endpoint fails closed otherwise.
 *
 * Security-relevant series (alerting targets in Grafana/Alertmanager):
 *   yatrago_otp_lockouts_total        — OTP brute-force attempts
 *   yatrago_refresh_reuse_total       — stolen refresh tokens replayed
 *   yatrago_fraud_events_total{type}  — fraud engine activity
 *   http_requests_total{status}       — 5xx spikes
 *   http_request_duration_seconds     — latency
 */
@Injectable()
export class MetricsService {
  readonly registry = new Registry();

  readonly httpRequests = new Counter({
    name: 'http_requests_total',
    help: 'HTTP requests by method and status class',
    labelNames: ['method', 'status'] as const,
    registers: [this.registry],
  });

  readonly httpDuration = new Histogram({
    name: 'http_request_duration_seconds',
    help: 'HTTP request duration in seconds',
    labelNames: ['method'] as const,
    buckets: [0.01, 0.05, 0.1, 0.25, 0.5, 1, 2.5, 5],
    registers: [this.registry],
  });

  readonly otpSends = new Counter({
    name: 'yatrago_otp_sends_total',
    help: 'OTP SMS send attempts',
    registers: [this.registry],
  });

  readonly otpFailures = new Counter({
    name: 'yatrago_otp_failures_total',
    help: 'Failed OTP verification attempts',
    registers: [this.registry],
  });

  readonly otpLockouts = new Counter({
    name: 'yatrago_otp_lockouts_total',
    help: 'OTP verification lockouts (5 failures in 10 minutes)',
    registers: [this.registry],
  });

  readonly refreshReuse = new Counter({
    name: 'yatrago_refresh_reuse_total',
    help: 'Refresh-token reuse detections (token theft responses)',
    registers: [this.registry],
  });

  readonly fraudEvents = new Counter({
    name: 'yatrago_fraud_events_total',
    help: 'Fraud events recorded, by type',
    labelNames: ['type'] as const,
    registers: [this.registry],
  });

  constructor() {
    collectDefaultMetrics({ register: this.registry });
  }

  metrics(): Promise<string> {
    return this.registry.metrics();
  }
}
