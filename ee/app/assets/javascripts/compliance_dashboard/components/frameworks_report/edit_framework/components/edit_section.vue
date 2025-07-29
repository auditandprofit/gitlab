<script>
import { GlButton, GlCollapse, GlBadge } from '@gitlab/ui';
import { uniqueId } from 'lodash';
import { s__, __ } from '~/locale';

export default {
  components: {
    GlButton,
    GlBadge,
    GlCollapse,
  },
  props: {
    title: {
      type: String,
      required: true,
    },
    description: {
      type: String,
      required: true,
    },
    itemsCount: {
      type: Number,
      required: false,
      default: null,
    },
    isRequired: {
      type: Boolean,
      required: false,
      default: false,
    },
    isCompleted: {
      type: Boolean,
      required: false,
      default: false,
    },
    initiallyExpanded: {
      type: Boolean,
      required: false,
      default: false,
    },
  },

  data(props) {
    return {
      isExpanded: props.initiallyExpanded,
    };
  },
  computed: {
    collapseIconName() {
      return this.isExpanded ? 'chevron-lg-down' : 'chevron-lg-right';
    },
    collapseButtonLabel() {
      return this.isExpanded ? __('Collapse') : __('Expand');
    },
    showItemsCount() {
      return this.itemsCount !== null;
    },
    isSuccessState() {
      return this.itemsCount > 0 || this.isCompleted;
    },
  },
  created() {
    this.$emit('toggle', this.isExpanded);
  },

  methods: {
    toggleExpand() {
      this.isExpanded = !this.isExpanded;
      this.$emit('toggle', this.isExpanded);
    },
  },
  i18n: {
    required: s__('ComplianceFrameworks|Required'),
    optional: s__('ComplianceFrameworks|Optional'),
  },
  collapseId: uniqueId('edit-section-'),
};
</script>
<template>
  <div class="gl-mb-1">
    <div
      class="gl-flex gl-cursor-pointer gl-items-center gl-bg-strong gl-p-5"
      tabindex="-1"
      role="button"
      :aria-expanded="isExpanded"
      :aria-controls="$options.collapseId"
      @click="toggleExpand"
    >
      <div class="gl-grow">
        <div class="gl-flex gl-items-center">
          <h3 class="gl-heading-3 gl-mb-2">{{ title }}</h3>
          <gl-badge
            v-if="showItemsCount"
            class="gl-mb-2 gl-ml-3"
            variant="neutral"
            data-testid="count-badge"
            >{{ itemsCount }}</gl-badge
          >
        </div>
        <span>{{ description }}</span>
      </div>
      <gl-badge
        :variant="isSuccessState ? 'success' : 'neutral'"
        :icon="isSuccessState ? 'check-circle' : ''"
        class="gl-mx-3 gl-px-3 gl-py-2"
        data-testid="status-badge"
      >
        {{ isRequired ? $options.i18n.required : $options.i18n.optional }}
      </gl-badge>
      <gl-button
        class="gl-m-4 !gl-bg-strong"
        category="tertiary"
        :icon="collapseIconName"
        :aria-label="collapseButtonLabel"
        :aria-controls="$options.collapseId"
        :aria-expanded="isExpanded"
      />
    </div>
    <gl-collapse :id="$options.collapseId" :visible="isExpanded" class="gl-bg-subtle">
      <div class="gl-px-5 gl-py-6">
        <slot></slot>
      </div>
    </gl-collapse>
  </div>
</template>
