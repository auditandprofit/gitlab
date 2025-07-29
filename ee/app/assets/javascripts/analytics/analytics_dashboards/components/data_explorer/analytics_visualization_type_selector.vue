<script>
import { GlFormSelect } from '@gitlab/ui';
import { s__ } from '~/locale';
import {
  VISUALIZATION_TYPE_DATA_TABLE,
  VISUALIZATION_TYPE_LINE_CHART,
  VISUALIZATION_TYPE_COLUMN_CHART,
  VISUALIZATION_TYPE_SINGLE_STAT,
} from 'ee/analytics/analytics_dashboards/constants';

const TYPES = [
  {
    value: VISUALIZATION_TYPE_LINE_CHART,
    text: s__('Analytics|Line chart'),
  },
  {
    value: VISUALIZATION_TYPE_COLUMN_CHART,
    text: s__('Analytics|Column chart'),
  },
  {
    value: VISUALIZATION_TYPE_DATA_TABLE,
    text: s__('Analytics|Data table'),
  },
  {
    value: VISUALIZATION_TYPE_SINGLE_STAT,
    text: s__('Analytics|Single statistic'),
  },
];

export default {
  name: 'AnalyticsVisualizationTypeSelector',
  components: {
    GlFormSelect,
  },
  props: {
    state: {
      type: Boolean,
      required: false,
      default: null,
    },
    value: {
      type: String,
      required: true,
    },
  },
  TYPES,
};
</script>

<template>
  <gl-form-select
    :value="value"
    :state="state"
    :options="$options.TYPES"
    @input="$emit('input', $event)"
  />
</template>
