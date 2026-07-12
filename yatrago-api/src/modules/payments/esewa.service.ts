import {
  Injectable,
  Logger,
  ServiceUnavailableException,
} from '@nestjs/common';
import { createHmac, timingSafeEqual } from 'crypto';
import { appConfig } from '../../config/app.config';

/**
 * The fields eSewa's ePay-v2 form requires. The signature covers exactly
 * `total_amount`, `transaction_uuid` and `product_code` (in that order) so
 * none of the money-relevant fields can be altered in the browser mid-flight.
 */
export interface EsewaFormFields {
  amount: string;
  tax_amount: string;
  total_amount: string;
  transaction_uuid: string;
  product_code: string;
  product_service_charge: string;
  product_delivery_charge: string;
  success_url: string;
  failure_url: string;
  signed_field_names: string;
  signature: string;
}

export type EsewaStatus =
  | 'COMPLETE'
  | 'PENDING'
  | 'CANCELED'
  | 'NOT_FOUND'
  | 'AMBIGUOUS'
  | 'FULL_REFUND'
  | 'PARTIAL_REFUND'
  | string;

export interface EsewaStatusResult {
  status: EsewaStatus;
  refId?: string;
  totalAmount?: number;
}

/**
 * Thin, side-effect-free adapter around eSewa ePay-v2.
 *
 * Security notes:
 *  - The HMAC secret is read from config (env), never hardcoded here.
 *  - `signedFieldNames` is fixed to the money fields; the signature is base64
 *    HMAC-SHA256 over "k=v,k=v,k=v" in the documented order.
 *  - The status endpoint is the SINGLE SOURCE OF TRUTH for whether a payment
 *    happened. We call it server-to-server over HTTPS and never trust the
 *    browser's success redirect payload.
 */
@Injectable()
export class EsewaService {
  private readonly logger = new Logger(EsewaService.name);
  private readonly cfg = appConfig.esewa;

  private static readonly SIGNED_FIELDS =
    'total_amount,transaction_uuid,product_code';

  /** base64(HMAC_SHA256(message, secret)) over the ePay-v2 signed message. */
  private sign(totalAmount: string, transactionUuid: string): string {
    const message =
      `total_amount=${totalAmount},` +
      `transaction_uuid=${transactionUuid},` +
      `product_code=${this.cfg.productCode}`;
    return createHmac('sha256', this.cfg.secretKey)
      .update(message)
      .digest('base64');
  }

  /**
   * Build the fully-signed form the WebView will POST to eSewa. `amount` is a
   * whole-rupee integer already validated upstream. No tax/charges on a wallet
   * load, so total == amount.
   */
  buildForm(params: {
    amount: number;
    transactionUuid: string;
  }): { gatewayUrl: string; fields: EsewaFormFields } {
    const total = String(params.amount);
    const fields: EsewaFormFields = {
      amount: total,
      tax_amount: '0',
      total_amount: total,
      transaction_uuid: params.transactionUuid,
      product_code: this.cfg.productCode,
      product_service_charge: '0',
      product_delivery_charge: '0',
      success_url: this.cfg.successUrl,
      failure_url: this.cfg.failureUrl,
      signed_field_names: EsewaService.SIGNED_FIELDS,
      signature: this.sign(total, params.transactionUuid),
    };
    return { gatewayUrl: this.cfg.gatewayUrl, fields };
  }

  /**
   * Authoritative check: ask eSewa (server-to-server, HTTPS) whether this
   * transaction actually settled. Returns the normalised status plus the
   * provider ref and the amount eSewa recorded so the caller can assert it
   * matches what we asked for.
   */
  async queryStatus(params: {
    transactionUuid: string;
    totalAmount: number;
  }): Promise<EsewaStatusResult> {
    const url = new URL(this.cfg.statusUrl);
    url.searchParams.set('product_code', this.cfg.productCode);
    url.searchParams.set('total_amount', String(params.totalAmount));
    url.searchParams.set('transaction_uuid', params.transactionUuid);

    // Never let a wallet callback loop on eSewa hanging.
    const controller = new AbortController();
    const timer = setTimeout(() => controller.abort(), 15_000);
    try {
      const res = await fetch(url.toString(), {
        method: 'GET',
        headers: { Accept: 'application/json' },
        signal: controller.signal,
      });
      if (!res.ok) {
        this.logger.warn(
          `eSewa status HTTP ${res.status} for ${params.transactionUuid}`,
        );
        // Surface as retryable rather than silently treating as failure.
        throw new ServiceUnavailableException(
          'Payment status check failed. Please try again.',
        );
      }
      const body = (await res.json()) as {
        status?: string;
        ref_id?: string;
        total_amount?: number | string;
      };
      const totalAmount =
        body.total_amount != null
          ? Number(String(body.total_amount).replace(/,/g, ''))
          : undefined;
      return {
        status: (body.status ?? 'NOT_FOUND') as EsewaStatus,
        refId: body.ref_id ?? undefined,
        totalAmount,
      };
    } catch (err) {
      if (err instanceof ServiceUnavailableException) throw err;
      this.logger.error(
        `eSewa status query error for ${params.transactionUuid}: ${
          (err as Error).message
        }`,
      );
      throw new ServiceUnavailableException(
        'Could not reach the payment provider. Please try again.',
      );
    } finally {
      clearTimeout(timer);
    }
  }

  /**
   * Verify the signature on the base64 `data` blob eSewa appends to the
   * success redirect. This is a defence-in-depth cross-check ONLY — crediting
   * is still gated on {@link queryStatus}. Constant-time compared.
   */
  verifyCallbackSignature(dataB64: string): boolean {
    try {
      const json = JSON.parse(
        Buffer.from(dataB64, 'base64').toString('utf8'),
      ) as Record<string, string>;
      const signedNames = (json.signed_field_names ?? '').split(',');
      const message = signedNames
        .map((f) => `${f}=${json[f] ?? ''}`)
        .join(',');
      const expected = createHmac('sha256', this.cfg.secretKey)
        .update(message)
        .digest('base64');
      const a = Buffer.from(expected);
      const b = Buffer.from(json.signature ?? '');
      return a.length === b.length && timingSafeEqual(a, b);
    } catch {
      return false;
    }
  }
}
