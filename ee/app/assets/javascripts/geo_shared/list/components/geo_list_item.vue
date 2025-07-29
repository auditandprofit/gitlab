<script>
import { GlLink, GlButton } from '@gitlab/ui';
import GeoListItemStatus from './geo_list_item_status.vue';
import GeoListItemTimeAgo from './geo_list_item_time_ago.vue';
import GeoListItemErrors from './geo_list_item_errors.vue';

export default {
  components: {
    GlLink,
    GeoListItemTimeAgo,
    GeoListItemStatus,
    GeoListItemErrors,
    GlButton,
  },
  props: {
    name: {
      type: String,
      required: true,
    },
    detailsPath: {
      type: String,
      required: false,
      default: '',
    },
    statusArray: {
      type: Array,
      required: false,
      default: () => [],
    },
    timeAgoArray: {
      type: Array,
      required: false,
      default: () => [],
    },
    actionsArray: {
      type: Array,
      required: false,
      default: () => [],
    },
    errorsArray: {
      type: Array,
      required: false,
      default: () => [],
    },
  },
};
</script>

<template>
  <div class="gl-border-b gl-p-5">
    <div class="geo-list-item-grid gl-grid gl-items-center gl-pb-4">
      <geo-list-item-status :status-array="statusArray" />

      <gl-link v-if="detailsPath" class="gl-font-bold" :href="detailsPath">{{ name }}</gl-link>
      <span v-else class="gl-font-bold" data-testid="non-link-name">{{ name }}</span>

      <div>
        <gl-button
          v-for="action in actionsArray"
          :key="action.id"
          :data-testid="action.id"
          size="small"
          @click="$emit('actionClicked', action)"
        >
          {{ action.text }}
        </gl-button>
      </div>
    </div>

    <div class="gl-flex gl-flex-wrap gl-items-center">
      <span
        v-if="$scopedSlots['extra-details']"
        class="gl-border-r-1 gl-px-2 gl-text-sm gl-text-subtle gl-border-r-solid"
        data-testid="extra-details"
      >
        <slot name="extra-details"></slot>
      </span>

      <geo-list-item-time-ago
        v-for="(timeAgo, index) in timeAgoArray"
        :key="index"
        :label="timeAgo.label"
        :date-string="timeAgo.dateString"
        :default-text="timeAgo.defaultText"
        :show-divider="index < timeAgoArray.length - 1"
      />
    </div>
    <geo-list-item-errors v-if="errorsArray.length" :errors-array="errorsArray" class="gl-pl-2" />
  </div>
</template>
