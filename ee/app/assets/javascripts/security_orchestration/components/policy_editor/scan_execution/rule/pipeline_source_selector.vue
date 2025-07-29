<script>
import { GlCollapsibleListbox } from '@gitlab/ui';
import { s__ } from '~/locale';
import { getSelectedOptionsText } from '~/lib/utils/listbox_helpers';
import {
  PIPELINE_SOURCE_LISTBOX_OPTIONS,
  TARGETS_BRANCHES_PIPELINE_SOURCE_LISTBOX_OPTIONS,
} from '../constants';

export default {
  PIPELINE_SOURCE_LISTBOX_OPTIONS,
  TARGETS_BRANCHES_PIPELINE_SOURCE_LISTBOX_OPTIONS,
  name: 'PipelineSourceSelector',
  components: {
    GlCollapsibleListbox,
  },
  props: {
    allSources: {
      type: Boolean,
      required: false,
      default: true,
    },
    pipelineSources: {
      type: Object,
      required: false,
      default: () => ({}),
    },
  },
  computed: {
    items() {
      return this.allSources
        ? this.$options.PIPELINE_SOURCE_LISTBOX_OPTIONS
        : this.$options.TARGETS_BRANCHES_PIPELINE_SOURCE_LISTBOX_OPTIONS;
    },
    pipelineSourcesText() {
      return getSelectedOptionsText({
        options: PIPELINE_SOURCE_LISTBOX_OPTIONS,
        selected: this.sources,
        placeholder: s__('SecurityOrchestration|All pipeline sources'),
        maxOptionsShown: 2,
      });
    },
    sources() {
      return this.pipelineSources?.including || [];
    },
  },
  methods: {
    setPipelineSources(including) {
      this.$emit('select', { pipeline_sources: { including } });
    },
  },
};
</script>

<template>
  <gl-collapsible-listbox
    multiple
    data-testid="pipeline-source"
    :items="items"
    :selected="sources"
    :toggle-text="pipelineSourcesText"
    @select="setPipelineSources"
  />
</template>
