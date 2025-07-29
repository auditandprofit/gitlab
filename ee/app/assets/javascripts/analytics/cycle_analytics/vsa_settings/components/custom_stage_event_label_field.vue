<script>
import { GlButton, GlIcon, GlFormGroup, GlCollapsibleListbox } from '@gitlab/ui';
import { __ } from '~/locale';
import { DEFAULT_DEBOUNCE_AND_THROTTLE_MS } from '~/lib/utils/constants';
import getCustomStageLabels from '../graphql/get_custom_stage_labels.query.graphql';

export default {
  name: 'CustomStageEventLabelField',
  components: {
    GlButton,
    GlIcon,
    GlFormGroup,
    GlCollapsibleListbox,
  },
  inject: ['groupPath'],
  props: {
    index: {
      type: Number,
      required: true,
    },
    eventType: {
      type: String,
      required: true,
    },
    selectedLabelId: {
      type: String,
      required: false,
      default: null,
    },
    fieldLabel: {
      type: String,
      required: true,
    },
    requiresLabel: {
      type: Boolean,
      required: true,
    },
    isLabelValid: {
      type: Boolean,
      required: false,
      default: true,
    },
    labelError: {
      type: String,
      required: false,
      default: '',
    },
  },
  data() {
    return {
      labels: [],
      searchTerm: '',
    };
  },
  computed: {
    loading() {
      return this.$apollo.queries.labels.loading;
    },
    fieldName() {
      const { eventType, index } = this;
      return `custom-stage-${eventType}-label-${index}`;
    },
    items() {
      return this.labels.map(({ id, title, color }) => ({ value: id, text: title, color }));
    },
    selectedLabel() {
      return this.labels.find(({ id }) => id === this.selectedLabelId);
    },
    selected: {
      get() {
        return this.selectedLabelId;
      },
      set(id) {
        this.$emit('update-label', { id });
      },
    },
  },
  apollo: {
    labels: {
      query: getCustomStageLabels,
      debounce: DEFAULT_DEBOUNCE_AND_THROTTLE_MS,
      variables() {
        return {
          fullPath: this.groupPath,
          searchTerm: this.searchTerm,
        };
      },
      update({
        group: {
          labels: { nodes },
        },
      }) {
        return nodes;
      },
      error() {
        this.$emit('error', __('There was an error fetching label data for the selected group'));
      },
    },
  },
  methods: {
    onSearch(value) {
      this.searchTerm = value.trim();
    },
  },
  headerText: __('Select a label'),
};
</script>
<template>
  <div class="gl-ml-2 gl-w-1/2">
    <transition name="fade">
      <gl-form-group
        v-if="requiresLabel"
        :data-testid="fieldName"
        :label="fieldLabel"
        :state="isLabelValid"
        :invalid-feedback="labelError"
      >
        <gl-collapsible-listbox
          v-model="selected"
          block
          searchable
          :name="fieldName"
          :header-text="$options.headerText"
          :searching="loading"
          :items="items"
          @search="onSearch"
        >
          <template #toggle>
            <gl-button
              data-testid="listbox-toggle-btn"
              block
              button-text-classes="gl-w-full gl-flex gl-justify-between"
              :class="{ 'gl-shadow-inner-1-red-500': !isLabelValid }"
            >
              <div v-if="selectedLabel">
                <span
                  :style="{ backgroundColor: selectedLabel.color }"
                  class="dropdown-label-box gl-inline-block"
                >
                </span>
                {{ selectedLabel.title }}
              </div>
              <div v-else class="gl-text-subtle">{{ $options.headerText }}</div>
              <gl-icon name="chevron-down" />
            </gl-button>
          </template>
          <template #list-item="{ item: { text, color } }">
            <span :style="{ backgroundColor: color }" class="dropdown-label-box gl-inline-block">
            </span>
            {{ text }}
          </template>
        </gl-collapsible-listbox>
      </gl-form-group>
    </transition>
  </div>
</template>
