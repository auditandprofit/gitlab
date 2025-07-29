import {
  DESTINATION_TYPE_HTTP,
  DESTINATION_TYPE_AMAZON_S3,
  DESTINATION_TYPE_GCP_LOGGING,
} from '../constants';

import updateGroupStreamingDestination from './mutations/update_group_streaming_destination.mutation.graphql';
import createGroupStreamingDestination from './mutations/create_group_streaming_destination.mutation.graphql';
import addGroupEventTypeFiltersToDestination from './mutations/add_group_event_type_filters.mutation.graphql';
import addGroupNamespaceFiltersToDestination from './mutations/add_group_namespace_filters.mutation.graphql';
import deleteGroupEventTypeFiltersFromDestination from './mutations/delete_group_event_type_filters.mutation.graphql';
import deleteGroupNamespaceFiltersFromDestination from './mutations/delete_group_namespace_filters.mutation.graphql';
import updateInstanceStreamingDestination from './mutations/update_instance_streaming_destination.mutation.graphql';
import createInstanceStreamingDestination from './mutations/create_instance_streaming_destination.mutation.graphql';
import addInstanceEventTypeFiltersToDestination from './mutations/add_instance_event_type_filters.mutation.graphql';
import deleteInstanceEventTypeFiltersFromDestination from './mutations/delete_instance_event_type_filters.mutation.graphql';
import {
  addAuditEventsStreamingDestinationToCache,
  updateAuditEventsStreamingDestinationFromCache,
  updateEventTypeFiltersFromCache,
  addNamespaceFilterToCache,
} from './cache_update_consolidated_api';

const getCategoryInGraphqlFormat = (category) => {
  switch (category) {
    case DESTINATION_TYPE_HTTP:
      return 'http';
    case DESTINATION_TYPE_GCP_LOGGING:
      return 'gcp';
    case DESTINATION_TYPE_AMAZON_S3:
      return 'aws';
    default:
      return category;
  }
};

const getCreatedEventTypeFiltersData = (data, isInstance) =>
  isInstance
    ? data.auditEventsInstanceDestinationEventsAdd
    : data.auditEventsGroupDestinationEventsAdd;

const getCreatedDestinationData = (data, isInstance) =>
  isInstance
    ? data.instanceAuditEventStreamingDestinationsCreate
    : data.groupAuditEventStreamingDestinationsCreate;

/**
 * Add event type filters to a destination.
 *
 * @param {Object} $apollo - The Apollo client instance.
 * @param {Object} destination - The destination object.
 * @param {Boolean} isInstance - Flag indicating if the destination is an instance-level destination.
 * @param {Array} eventTypeFiltersToAdd - Array of event type filters to add.
 * @param {String} fetchPolicy - The fetch policy for the mutation.
 *
 * @returns {Promise<Array>} An array of errors.
 */
const addEventTypeFilters = async ({
  $apollo,
  destination,
  isInstance,
  eventTypeFiltersToAdd,
  fetchPolicy,
}) => {
  if (!eventTypeFiltersToAdd.length || !destination.id) {
    return [];
  }

  const variables = {
    destinationId: destination.id,
    eventTypeFilters: eventTypeFiltersToAdd,
  };

  const update = (cache, { data }) => {
    const { errors, eventTypeFilters } = getCreatedEventTypeFiltersData(data, isInstance);

    if (errors.length || fetchPolicy === 'no-cache') {
      return;
    }

    updateEventTypeFiltersFromCache({
      store: cache,
      isInstance,
      destinationId: destination.id,
      filters: eventTypeFilters,
    });
  };

  const { data } = await $apollo.mutate({
    mutation: isInstance
      ? addInstanceEventTypeFiltersToDestination
      : addGroupEventTypeFiltersToDestination,
    variables,
    fetchPolicy,
    update,
  });

  return getCreatedEventTypeFiltersData(data, isInstance).errors;
};

/**
 * Remove event type filters from a destination.
 *
 * @param {Object} $apollo - The Apollo client instance.
 * @param {Object} destination - The destination object.
 * @param {Boolean} isInstance - Flag indicating if the destination is an instance-level destination.
 * @param {Array} eventTypeFiltersToRemove - Array of event type filters to remove.
 *
 * @returns {Promise<Array>} An array of errors.
 */
const removeEventTypeFilters = async ({
  $apollo,
  destination,
  isInstance,
  eventTypeFiltersToRemove,
}) => {
  if (!eventTypeFiltersToRemove.length || !destination.id) {
    return [];
  }

  const variables = {
    destinationId: destination.id,
    eventTypeFilters: eventTypeFiltersToRemove,
  };

  const { data } = await $apollo.mutate({
    mutation: isInstance
      ? deleteInstanceEventTypeFiltersFromDestination
      : deleteGroupEventTypeFiltersFromDestination,
    variables,
    fetchPolicy: 'no-cache',
    update: () => {},
  });

  return isInstance
    ? data.auditEventsInstanceDestinationEventsDelete.errors
    : data.auditEventsGroupDestinationEventsDelete.errors;
};

/**
 * Add namespace filters to a destination.
 *
 * @param {Object} $apollo - The Apollo client instance.
 * @param {Object} destination - The destination object.
 * @param {String} fetchPolicy - The fetch policy for the mutation.
 *
 * @returns {Promise<Array>} An array of errors.
 */
const addNamespaceFilters = async ({ $apollo, destination, fetchPolicy }) => {
  const variables = {
    destinationId: destination.id,
    namespacePath: destination.namespaceFilter.namespace,
  };

  const update = (cache, { data }) => {
    if (
      data.auditEventsGroupDestinationNamespaceFilterCreate.errors.length ||
      fetchPolicy === 'no-cache'
    ) {
      return;
    }

    addNamespaceFilterToCache({
      store: cache,
      destinationId: destination.id,
      filter: data.auditEventsGroupDestinationNamespaceFilterCreate.namespaceFilter,
    });
  };

  return $apollo.mutate({
    mutation: addGroupNamespaceFiltersToDestination,
    variables,
    fetchPolicy,
    update,
  });
};

/**
 * Remove namespace filters from a destination.
 * The API allows more than 1 namespace filter per destination,
 * but we enforce 1 per destination for now.
 *
 * @param {Object} $apollo - The Apollo client instance.
 * @param {Object} destination - The destination object.
 *
 * @returns {Promise<Array>} An array of errors.
 */
const removeNamespaceFilters = async ($apollo, destination) => {
  if (!destination.namespaceFilters.length) {
    return [];
  }

  const removeFiltersPromises = destination.namespaceFilters.map(async (namespaceFilter) => {
    const { data } = await $apollo.mutate({
      mutation: deleteGroupNamespaceFiltersFromDestination,
      variables: {
        namespaceFilterId: namespaceFilter.id,
      },
      fetchPolicy: 'no-cache',
      update: () => {},
    });

    return data.auditEventsGroupDestinationNamespaceFilterDelete.errors;
  });

  const results = await Promise.all(removeFiltersPromises);

  return results.reduce((errors, errs) => [...errors, ...errs], []);
};

/**
 * Executes the apollo mutaion to create a new destination.
 *
 * @param {Object} $apollo - The Apollo client instance.
 * @param {Object} destination - The destination object.
 * @param {Boolean} isInstance - Flag indicating if the destination is an instance-level destination.
 * @param {String} groupPath - The full path of the group (if not instance-level).
 *
 * @returns {Promise} The `$apollo.mutate` promise
 */
const executeCreateDestinationMutation = ({ $apollo, destination, isInstance, groupPath }) => {
  const update = (cache, { data }) => {
    if (getCreatedDestinationData(data, isInstance).errors.length) return;

    addAuditEventsStreamingDestinationToCache({
      store: cache,
      isInstance,
      fullPath: groupPath,
      newDestination: getCreatedDestinationData(data, isInstance).externalAuditEventDestination,
    });
  };

  const variables = {
    input: {
      name: destination.name,
      secretToken: destination.secretToken,
      category: getCategoryInGraphqlFormat(destination.category),
      config: {
        ...destination.config,
      },
      ...(isInstance ? {} : { groupPath }),
    },
  };

  return $apollo.mutate({
    mutation: isInstance ? createInstanceStreamingDestination : createGroupStreamingDestination,
    variables,
    update,
  });
};

/**
 * Create a new destination.
 *
 * @param {Object} $apollo - The Apollo client instance.
 * @param {Object} destination - The destination object.
 * @param {Boolean} isInstance - Flag indicating if the destination is an instance-level destination.
 * @param {String} groupPath - The full path of the group (if not instance-level).
 * @param {Array} eventTypeFiltersToAdd - Array of event type filters to add.
 * @param {Boolean} hasChangedNamespaceFilter - Flag indicating if the namespace filter has changed.
 *
 * @returns {Promise<{ errors: Array }>}
 */
export const createDestination = async ({
  $apollo,
  destination,
  isInstance,
  groupPath,
  eventTypeFiltersToAdd,
  hasChangedNamespaceFilter,
}) => {
  const errors = [];
  const fetchPolicy = 'network-only';
  const createdDestination = {};

  const { data } = await executeCreateDestinationMutation({
    $apollo,
    destination,
    isInstance,
    groupPath,
  });

  errors.push(...getCreatedDestinationData(data, isInstance).errors);

  if (errors.length) return { errors };
  createdDestination.id = getCreatedDestinationData(
    data,
    isInstance,
  ).externalAuditEventDestination.id;

  errors.push(
    ...(await addEventTypeFilters({
      $apollo,
      destination: createdDestination,
      isInstance,
      eventTypeFiltersToAdd,
      fetchPolicy,
    })),
  );

  if (hasChangedNamespaceFilter) {
    const { data: namespaceFilterData } = await addNamespaceFilters({
      $apollo,
      destination: {
        ...destination,
        ...createdDestination,
      },
      fetchPolicy,
    });
    errors.push(...namespaceFilterData.auditEventsGroupDestinationNamespaceFilterCreate.errors);
  }

  return { errors };
};

const getUpdatedDestinationData = (data, isInstance) =>
  isInstance
    ? data.instanceAuditEventStreamingDestinationsUpdate
    : data.groupAuditEventStreamingDestinationsUpdate;

/**
 * Executes the apollo mutaion to update an existing destination.
 *
 * @param {Object} $apollo - The Apollo client instance.
 * @param {Object} destination - The destination object.
 * @param {Boolean} isInstance - Flag indicating if the destination is an instance-level destination.
 * @param {String} groupPath - The full path of the group (if not instance-level).
 *
 * @returns {Promise} The `$apollo.mutate` promise
 */
const executeUpdateDestinationMutation = ({ $apollo, destination, isInstance }) => {
  const variables = {
    input: {
      id: destination.id,
      name: destination.name,
      config: {
        ...destination.config,
      },
      ...(destination.secretToken ? { secretToken: destination.secretToken } : {}),
    },
  };

  return $apollo.mutate({
    mutation: isInstance ? updateInstanceStreamingDestination : updateGroupStreamingDestination,
    variables,
    fetchPolicy: 'no-cache',
    update: () => {},
  });
};

/**
 * Update an existing destination.
 *
 * @param {Object} $apollo - The Apollo client instance.
 * @param {Object} destination - The destination object.
 * @param {Boolean} isInstance - Flag indicating if the destination is an instance-level destination.
 * @param {Array} eventTypeFiltersToAdd - Array of event type filters to add.
 * @param {Array} eventTypeFiltersToRemove - Array of event type filters to remove.
 * @param {Boolean} hasChangedNamespaceFilter - Flag indicating if the namespace filter has changed.
 *
 * @returns {Promise<{ errors: Array }>}
 */
export const updateDestination = async ({
  $apollo,
  destination,
  isInstance,
  eventTypeFiltersToAdd,
  eventTypeFiltersToRemove,
  hasChangedNamespaceFilter,
}) => {
  const errors = [];
  const fetchPolicy = 'no-cache';
  let updatedNamespaceFilter;

  const { data } = await executeUpdateDestinationMutation({
    $apollo,
    destination,
    isInstance,
  });

  errors.push(...getUpdatedDestinationData(data, isInstance).errors);
  errors.push(
    ...(await removeEventTypeFilters({
      $apollo,
      destination,
      isInstance,
      eventTypeFiltersToRemove,
    })),
  );

  errors.push(
    ...(await addEventTypeFilters({
      $apollo,
      destination,
      isInstance,
      eventTypeFiltersToAdd,
      fetchPolicy,
    })),
  );

  if (hasChangedNamespaceFilter) {
    errors.push(...(await removeNamespaceFilters($apollo, destination)));
    const { data: namespaceFilterData } = await addNamespaceFilters({
      $apollo,
      destination,
      fetchPolicy,
    });
    errors.push(...namespaceFilterData.auditEventsGroupDestinationNamespaceFilterCreate.errors);
    updatedNamespaceFilter =
      namespaceFilterData.auditEventsGroupDestinationNamespaceFilterCreate.namespaceFilter;
  }

  if (errors.length) return { errors };

  const updatedData = {
    ...getUpdatedDestinationData(data, isInstance).externalAuditEventDestination,
    eventTypeFilters: JSON.parse(JSON.stringify(destination.eventTypeFilters)),
  };

  if (updatedNamespaceFilter) {
    updatedData.namespaceFilters = [updatedNamespaceFilter];
  }

  updateAuditEventsStreamingDestinationFromCache({
    store: $apollo.provider.defaultClient.cache,
    isInstance,
    updatedData,
  });

  return { errors };
};
