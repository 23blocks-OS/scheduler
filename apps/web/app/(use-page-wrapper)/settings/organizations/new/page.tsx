import { _generateMetadata } from "app/_utils";


import LegacyPage, { LayoutWrapper } from "~/settings/organizations/new/create-new-view";

export const generateMetadata = async () =>
  await _generateMetadata(
    (t) => t("set_up_your_organization"),
    (t) => t("organizations_description"),
    undefined,
    undefined,
    "/settings/organizations/new"
  );

const ServerPage = async () => {
  return (
    <LayoutWrapper>
      <LegacyPage />
    </LayoutWrapper>
  );
};

export default ServerPage;
