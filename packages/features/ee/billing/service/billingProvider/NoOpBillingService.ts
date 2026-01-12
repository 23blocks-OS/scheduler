import logger from "@calcom/lib/logger";

import type { IBillingProviderService } from "./IBillingProviderService";

const log = logger.getSubLogger({ prefix: ["NoOpBillingService"] });

/**
 * No-operation billing service used when Stripe is not configured.
 * All methods return empty/null results and log warnings when called.
 */
export class NoOpBillingService implements IBillingProviderService {
  private logDisabled(method: string) {
    log.warn(`${method} called but Stripe is not configured - STRIPE_PRIVATE_KEY not set`);
  }

  async checkoutSessionIsPaid(_paymentId: string): Promise<boolean> {
    this.logDisabled("checkoutSessionIsPaid");
    return false;
  }

  async handleSubscriptionCancel(_subscriptionId: string): Promise<void> {
    this.logDisabled("handleSubscriptionCancel");
  }

  async handleSubscriptionCreation(_subscriptionId: string): Promise<void> {
    this.logDisabled("handleSubscriptionCreation");
  }

  async handleSubscriptionUpdate(_args: {
    subscriptionId: string;
    subscriptionItemId: string;
    membershipCount: number;
  }): Promise<void> {
    this.logDisabled("handleSubscriptionUpdate");
  }

  async handleEndTrial(_subscriptionId: string): Promise<void> {
    this.logDisabled("handleEndTrial");
  }

  async createCustomer(_args: {
    email: string;
    metadata?: Record<string, string>;
  }): Promise<{ stripeCustomerId: string }> {
    this.logDisabled("createCustomer");
    return { stripeCustomerId: "" };
  }

  async createPaymentIntent(_args: {
    customerId: string;
    amount: number;
    metadata?: Record<string, string | number>;
  }): Promise<{ id: string; client_secret: string | null }> {
    this.logDisabled("createPaymentIntent");
    return { id: "", client_secret: null };
  }

  async createOneTimeCheckout(_args: {
    priceId: string;
    quantity: number;
    successUrl: string;
    cancelUrl: string;
    metadata?: Record<string, string>;
  }): Promise<{ checkoutUrl: string | null; sessionId: string }> {
    this.logDisabled("createOneTimeCheckout");
    return { checkoutUrl: null, sessionId: "" };
  }

  async createSubscriptionCheckout(_args: {
    customerId: string;
    successUrl: string;
    cancelUrl: string;
    priceId: string;
    quantity: number;
    metadata?: Record<string, string | number>;
    mode?: "subscription" | "setup" | "payment";
    allowPromotionCodes?: boolean;
    customerUpdate?: {
      address?: "auto" | "never";
    };
    automaticTax?: {
      enabled: boolean;
    };
    discounts?: Array<{
      coupon: string;
    }>;
    subscriptionData?: {
      metadata?: Record<string, string | number>;
      trial_period_days?: number;
    };
  }): Promise<{ checkoutUrl: string | null; sessionId: string }> {
    this.logDisabled("createSubscriptionCheckout");
    return { checkoutUrl: null, sessionId: "" };
  }

  async createPrice(_args: {
    amount: number;
    currency: string;
    interval: "month" | "year";
    nickname?: string;
    productId: string;
    metadata?: Record<string, string | number>;
  }): Promise<{ priceId: string }> {
    this.logDisabled("createPrice");
    return { priceId: "" };
  }

  async getPrice(_priceId: string): Promise<null> {
    this.logDisabled("getPrice");
    return null;
  }

  async getSubscriptionStatus(_subscriptionId: string): Promise<null> {
    this.logDisabled("getSubscriptionStatus");
    return null;
  }

  async getCheckoutSession(_checkoutSessionId: string): Promise<null> {
    this.logDisabled("getCheckoutSession");
    return null;
  }

  async getCustomer(_customerId: string): Promise<null> {
    this.logDisabled("getCustomer");
    return null;
  }

  async getSubscriptions(_customerId: string): Promise<null> {
    this.logDisabled("getSubscriptions");
    return null;
  }

  async updateCustomer(_args: { customerId: string; email: string; userId?: number }): Promise<void> {
    this.logDisabled("updateCustomer");
  }

  extractSubscriptionDates(_subscription: {
    start_date: number;
    trial_end?: number | null;
    cancel_at?: number | null;
  }): {
    subscriptionStart: Date;
    subscriptionTrialEnd: Date | null;
    subscriptionEnd: Date | null;
  } {
    this.logDisabled("extractSubscriptionDates");
    return {
      subscriptionStart: new Date(),
      subscriptionTrialEnd: null,
      subscriptionEnd: null,
    };
  }
}
