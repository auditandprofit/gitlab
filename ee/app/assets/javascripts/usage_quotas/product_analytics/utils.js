/**
 * Determines if a project has been onboarded with product analytics based on its usage data
 */
export const projectHasProductAnalyticsEnabled = (project) =>
  project.productAnalyticsEventsStored?.some((usage) => usage.count !== null);
