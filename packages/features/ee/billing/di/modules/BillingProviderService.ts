import { type Container, createModule, ModuleLoader } from "@calcom/features/di/di";

import { NoOpBillingService } from "../../service/billingProvider/NoOpBillingService";
import { StripeBillingService } from "../../service/billingProvider/StripeBillingService";
import { DI_TOKENS } from "../tokens";
import { stripeClientModuleLoader } from "./StripeClient";

const billingProviderServiceModule = createModule();
const token = DI_TOKENS.BILLING_PROVIDER_SERVICE;

// Factory that returns StripeBillingService if Stripe is configured, otherwise NoOpBillingService
billingProviderServiceModule.bind(token).toFactory((stripeClient) => {
  if (!stripeClient) {
    return new NoOpBillingService();
  }
  return new StripeBillingService(stripeClient);
}, [DI_TOKENS.STRIPE_CLIENT]);

export const billingProviderServiceModuleLoader: ModuleLoader = {
  token,
  loadModule: (container: Container) => {
    // Load dependency first
    stripeClientModuleLoader.loadModule(container);

    // Then load this module
    container.load(DI_TOKENS.BILLING_PROVIDER_SERVICE_MODULE, billingProviderServiceModule);
  },
};
