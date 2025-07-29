import * as CE from '~/work_items/constants';

/*
 * We're disabling the import/export rule here because we want to
 * re-export the constants from the CE file while also overriding
 * anything that's EE-specific.
 */
/* eslint-disable import/export */
export * from '~/work_items/constants';

export const optimisticUserPermissions = {
  ...CE.optimisticUserPermissions,
  blockedWorkItems: true,
};

export const newWorkItemOptimisticUserPermissions = {
  ...CE.newWorkItemOptimisticUserPermissions,
  blockedWorkItems: true,
};
/* eslint-enable import/export */
