<script>
import { GlButtonGroup, GlButton } from '@gitlab/ui';
// eslint-disable-next-line no-restricted-imports
import { mapState } from 'vuex';

import { ITEM_TABS } from '../constants';
import ToggleLabels from './toggle_labels.vue';

export default {
  ITEM_TABS,
  components: {
    GlButtonGroup,
    GlButton,
    ToggleLabels,
  },
  props: {
    activeTab: {
      type: String,
      required: true,
    },
  },
  computed: {
    ...mapState(['allowSubEpics']),
  },
};
</script>

<template>
  <div class="gl-flex gl-flex-col gl-border-b-0 gl-px-5 gl-py-3 sm:gl-flex-row">
    <div>
      <gl-button-group v-if="allowSubEpics" data-testid="buttons" class="gl-flex gl-grow">
        <gl-button
          class="js-epic-tree-tab"
          data-testid="tree-view-button"
          :selected="activeTab === $options.ITEM_TABS.TREE"
          @click="() => $emit('tab-change', $options.ITEM_TABS.TREE)"
        >
          {{ __('Tree view') }}
        </gl-button>
        <gl-button
          class="js-epic-roadmap-tab"
          data-testid="roadmap-view-button"
          :selected="activeTab === $options.ITEM_TABS.ROADMAP"
          @click="() => $emit('tab-change', $options.ITEM_TABS.ROADMAP)"
        >
          {{ __('Roadmap view') }}
        </gl-button>
      </gl-button-group>
    </div>
    <div
      v-if="activeTab === $options.ITEM_TABS.TREE"
      class="gl-mt-3 gl-flex sm:gl-ml-auto sm:gl-mt-0 sm:gl-inline-flex"
    >
      <toggle-labels class="!gl-ml-0 sm:!gl-ml-3" />
    </div>
  </div>
</template>
