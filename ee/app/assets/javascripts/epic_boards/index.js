import Vue from 'vue';
import VueApollo from 'vue-apollo';

import { fullEpicBoardId } from 'ee_component/boards/boards_util';

import BoardApp from '~/boards/components/board_app.vue';

import {
  navigationType,
  isLoggedIn,
  parseBoolean,
  convertObjectPropsToCamelCase,
} from '~/lib/utils/common_utils';
import { defaultClient } from '~/graphql_shared/issuable_client';
import { TYPE_EPIC, WORKSPACE_GROUP, WORKSPACE_PROJECT } from '~/issues/constants';
import { queryToObject } from '~/lib/utils/url_utility';

Vue.use(VueApollo);

defaultClient.cache.policies.addTypePolicies({
  EpicList: {
    fields: {
      epics: {
        keyArgs: ['filters'],
      },
    },
  },
  EpicConnection: {
    merge(existing = { nodes: [] }, incoming, { args }) {
      if (!args?.after) {
        return incoming;
      }
      return {
        ...incoming,
        nodes: [...existing.nodes, ...incoming.nodes],
      };
    },
  },
  BoardEpicConnection: {
    merge(existing = { nodes: [] }, incoming, { args }) {
      if (!args.after) {
        return incoming;
      }
      return {
        ...incoming,
        nodes: [...existing.nodes, ...incoming.nodes],
      };
    },
  },
});

const apolloProvider = new VueApollo({
  defaultClient,
});

function mountBoardApp(el) {
  const {
    boardId,
    groupId,
    fullPath,
    rootPath,
    wiReportAbusePath,
    wiGroupPath,
    wiCanAdminLabel,
    wiIssuesListPath,
  } = el.dataset;

  const rawFilterParams = queryToObject(window.location.search, { gatherArrays: true });

  const initialFilterParams = {
    ...convertObjectPropsToCamelCase(rawFilterParams),
  };

  const boardType = el.dataset.parent;

  // eslint-disable-next-line no-new
  new Vue({
    el,
    name: 'BoardRoot',
    apolloProvider,
    provide: {
      initialBoardId: fullEpicBoardId(boardId),
      disabled: parseBoolean(el.dataset.disabled),
      boardId,
      groupId: parseInt(groupId, 10),
      rootPath,
      fullPath,
      initialFilterParams,
      boardBaseUrl: el.dataset.boardBaseUrl,
      boardType,
      isGroupBoard: boardType === WORKSPACE_GROUP,
      isProjectBoard: boardType === WORKSPACE_PROJECT,
      currentUserId: gon.current_user_id || null,
      labelsFetchPath: el.dataset.labelsFetchPath,
      labelsManagePath: el.dataset.labelsManagePath,
      labelsFilterBasePath: el.dataset.labelsFilterBasePath,
      timeTrackingLimitToHours: parseBoolean(el.dataset.timeTrackingLimitToHours),
      boardWeight: el.dataset.boardWeight ? parseInt(el.dataset.boardWeight, 10) : null,
      issuableType: TYPE_EPIC,
      emailsDisabled: !parseBoolean(el.dataset.emailsEnabled),
      hasMissingBoards: parseBoolean(el.dataset.hasMissingBoards),
      weights: JSON.parse(el.dataset.weights),
      isIssueBoard: false,
      isEpicBoard: true,
      // Permissions
      canUpdate: parseBoolean(el.dataset.canUpdate),
      canAdminList: parseBoolean(el.dataset.canAdminList),
      canAdminBoard: parseBoolean(el.dataset.canAdminBoard),
      canCreateEpic: parseBoolean(el.dataset.canCreateEpic),
      allowLabelCreate: parseBoolean(el.dataset.canUpdate),
      allowLabelEdit: parseBoolean(el.dataset.canUpdate),
      allowScopedLabels: parseBoolean(el.dataset.scopedLabels),
      isSignedIn: isLoggedIn(),
      // Features
      multipleAssigneesFeatureAvailable: parseBoolean(el.dataset.multipleAssigneesFeatureAvailable),
      epicFeatureAvailable: parseBoolean(el.dataset.epicFeatureAvailable),
      iterationFeatureAvailable: parseBoolean(el.dataset.iterationFeatureAvailable),
      weightFeatureAvailable: parseBoolean(el.dataset.weightFeatureAvailable),
      healthStatusFeatureAvailable: parseBoolean(el.dataset.healthStatusFeatureAvailable),
      scopedLabelsAvailable: parseBoolean(el.dataset.scopedLabels),
      allowSubEpics: parseBoolean(el.dataset.subEpicsFeatureAvailable),
      milestoneListsAvailable: false,
      assigneeListsAvailable: false,
      iterationListsAvailable: false,
      swimlanesFeatureAvailable: false,
      multipleIssueBoardsAvailable: true,
      scopedIssueBoardFeatureEnabled: true,
      reportAbusePath: wiReportAbusePath,
      groupPath: wiGroupPath,
      hasSubepicsFeature: parseBoolean(el.dataset.subEpicsFeatureAvailable),
      isGroup: true,
      canAdminLabel: parseBoolean(wiCanAdminLabel),
      hasIssuableHealthStatusFeature: parseBoolean(el.dataset.healthStatusFeatureAvailable),
      issuesListPath: wiIssuesListPath,
      hasLinkedItemsEpicsFeature: parseBoolean(el.dataset.hasLinkedItemsEpicsFeature),
      hasOkrsFeature: parseBoolean(el.dataset.hasOkrsFeature),
    },
    render: (createComponent) => createComponent(BoardApp),
  });
}

export default () => {
  const $boardApp = document.getElementById('js-issuable-board-app');

  // check for browser back and trigger a hard reload to circumvent browser caching.
  window.addEventListener('pageshow', (event) => {
    const isNavTypeBackForward =
      window.performance && window.performance.navigation.type === navigationType.TYPE_BACK_FORWARD;

    if (event.persisted || isNavTypeBackForward) {
      window.location.reload();
    }
  });

  mountBoardApp($boardApp);
};
