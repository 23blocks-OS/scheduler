import Stripe from "stripe";

import { type Container, createModule, ModuleLoader } from "@calcom/features/di/di";
import logger from "@calcom/lib/logger";

import { DI_TOKENS } from "../tokens";

const log = logger.getSubLogger({ prefix: ["StripeClient"] });

export const stripeClientModule = createModule();
const token = DI_TOKENS.STRIPE_CLIENT;
stripeClientModule.bind(token).toFactory(() => {
  if (!process.env.STRIPE_PRIVATE_KEY) {
    log.info("STRIPE_PRIVATE_KEY is not set - Stripe billing features disabled");
    return null;
  }

  return new Stripe(process.env.STRIPE_PRIVATE_KEY!, {
    apiVersion: "2020-08-27",
  });
});

export const stripeClientModuleLoader: ModuleLoader = {
  token,
  loadModule: function (container: Container) {
    container.load(token, stripeClientModule);
  },
};
