<script>
// eslint-disable-next-line no-restricted-imports
import { mapState } from 'vuex';
import { ParentType } from '../constants';
import EpicHealthStatus from './epic_health_status.vue';

export default {
  components: {
    EpicHealthStatus,
    EpicCountables: () =>
      import('ee_else_ce/vue_shared/components/epic_countables/epic_countables.vue'),
  },
  computed: {
    ...mapState([
      'parentItem',
      'weightSum',
      'descendantCounts',
      'healthStatus',
      'allowSubEpics',
      'allowIssuableHealthStatus',
    ]),
    showHealthStatus() {
      return this.healthStatus && this.allowIssuableHealthStatus;
    },
    parentIsEpic() {
      return this.parentItem.type === ParentType.Epic;
    },
  },
};
</script>

<template>
  <div class="gl-flex gl-flex-wrap gl-items-center">
    <div class="gl-flex gl-shrink-0 gl-flex-wrap gl-items-center">
      <div v-if="parentIsEpic" class="gl-inline-flex gl-flex-wrap gl-align-middle gl-leading-1">
        <epic-countables
          :allow-sub-epics="allowSubEpics"
          :opened-epics-count="descendantCounts.openedEpics"
          :closed-epics-count="descendantCounts.closedEpics"
          :opened-issues-count="descendantCounts.openedIssues"
          :closed-issues-count="descendantCounts.closedIssues"
          :opened-issues-weight="weightSum.openedIssues"
          :closed-issues-weight="weightSum.closedIssues"
        />
      </div>
    </div>
    <div
      class="gl-sm-ml-2 gl-ml-0 gl-mt-2 gl-flex gl-flex-wrap gl-align-middle gl-leading-1 sm:gl-mt-0 sm:gl-inline-flex"
    >
      <epic-health-status v-if="showHealthStatus" :health-status="healthStatus" />
    </div>
  </div>
</template>
