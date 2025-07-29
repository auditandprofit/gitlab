import { s__ } from '~/locale';
import {
  buildPools as ceBuildPools,
  getAssignees,
  getLabels,
  getMilestone,
  getReactions,
} from '~/work_items/pages/local_board/object_pools';

export { groupBy } from '~/work_items/pages/local_board/object_pools';

const healthStatusTitle = (status) => {
  const map = {
    onTrack: s__('WorkItem|On track'),
    needsAttention: s__('WorkItem|Needs attention'),
    atRisk: s__('WorkItem|At risk'),
  };
  return map[status];
};

const getIteration = (widgets) => {
  const found = widgets.find((widget) => widget.iteration !== undefined);
  if (found?.iteration) {
    return found.iteration;
  }
  return undefined;
};

const getHealthStatus = (widgets) => {
  const found = widgets.find((widget) => widget.healthStatus !== undefined);
  if (found?.healthStatus) {
    return found.healthStatus;
  }
  return undefined;
};

const getWeight = (widgets) => {
  const found = widgets.find((widget) => widget.weight !== undefined);
  if (found?.weight) {
    return { value: found.weight };
  }
  return undefined;
};

const transformItem = (input) => {
  return {
    id: input.id,
    iid: input.iid,
    title: input.title,
    state: input.state,
    type: input.workItemType,
    reference: input.reference,
    author: input.author,
    assignees: getAssignees(input.widgets),
    labels: getLabels(input.widgets),
    milestone: getMilestone(input.widgets),
    iteration: getIteration(input.widgets),
    healthStatus: getHealthStatus(input.widgets),
    webUrl: input.webUrl,
    confidential: input.confidential,
    reactions: getReactions(input.widgets),
    weight: getWeight(input.widgets),
  };
};

export const buildPools = (rawList) => {
  const cePools = ceBuildPools(rawList, transformItem);

  const eePools = {
    healthStatus: new Map(),
    iterations: new Map(),
    weights: new Map(),
  };

  for (const raw of rawList) {
    const i = transformItem(raw);
    const workItemId = i.id;

    const { healthStatus, iteration, weight } = i;

    // populate health status pool
    if (healthStatus) {
      const healthStatusEntry = eePools.healthStatus.get(healthStatus) || {
        id: healthStatus,
        title: healthStatusTitle(healthStatus),
        workItems: [],
      };
      healthStatusEntry.workItems.push(workItemId);
      eePools.healthStatus.set(healthStatus, healthStatusEntry);
    }

    // populate iteration pool
    if (iteration) {
      const cadence = iteration.iterationCadence;
      const iterationEntry = eePools.iterations.get(cadence.id) || {
        id: cadence.id,
        title: cadence.title,
        workItems: [],
        ...cadence,
      };
      iterationEntry.workItems.push(workItemId);
      eePools.iterations.set(cadence.id, iterationEntry);
    }

    // populate weight pool
    if (weight) {
      const weightStr = weight.value.toString();
      const weightEntry = eePools.weights.get(weightStr) || {
        id: weightStr,
        title: weightStr,
        workItems: [],
      };
      weightEntry.workItems.push(workItemId);
      eePools.weights.set(weightStr, weightEntry);
    }
  }

  return {
    ...cePools,
    healthStatus: Object.fromEntries(eePools.healthStatus),
    iterations: Object.fromEntries(eePools.iterations),
    weights: Object.fromEntries(eePools.weights),
  };
};

export const getGroupOptions = () => {
  return [
    { value: 'label', label: s__('WorkItem|Label') },
    { value: 'assignee', label: s__('WorkItem|Assignee') },
    { value: 'author', label: s__('WorkItem|Author') },
    { value: 'milestone', label: s__('WorkItem|Milestone') },
    { value: 'healthStatus', label: s__('WorkItem|Health Status') },
    { value: 'iteration', label: s__('WorkItem|Iteration') },
    { value: 'weight', label: s__('WorkItem|Weight') },
  ];
};

export const getPoolNameForGrouping = (groupingName) => {
  return {
    label: 'labels',
    assignee: 'users',
    author: 'users',
    milestone: 'milestones',
    healthStatus: 'healthStatus',
    iteration: 'iterations',
    weight: 'weights',
  }[groupingName];
};
