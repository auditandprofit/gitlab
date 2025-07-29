<script>
import { GlButton, GlButtonGroup, GlIcon, GlTooltipDirective } from '@gitlab/ui';
import { safeDump } from 'js-yaml';
import AnalyticsDashboardPanel from '../analytics_dashboard_panel.vue';

import {
  PANEL_DISPLAY_TYPES,
  PANEL_DISPLAY_TYPE_ITEMS,
  PANEL_VISUALIZATION_HEIGHT,
} from '../../constants';

export default {
  name: 'AnalyticsVisualizationPreview',
  PANEL_DISPLAY_TYPES,
  PANEL_DISPLAY_TYPE_ITEMS,
  components: {
    GlButton,
    GlButtonGroup,
    GlIcon,
    AnalyticsDashboardPanel,
  },
  directives: {
    GlTooltip: GlTooltipDirective,
  },
  props: {
    selectedVisualizationType: {
      type: String,
      required: true,
    },
    displayType: {
      type: String,
      required: true,
    },
    isQueryPresent: {
      type: Boolean,
      required: true,
    },
    resultVisualization: {
      type: Object,
      required: false,
      default: null,
    },
    title: {
      type: String,
      required: false,
      default: '',
    },
  },
  computed: {
    previewYamlConfiguration() {
      return this.resultVisualization && safeDump(this.resultVisualization);
    },
  },
  PANEL_VISUALIZATION_HEIGHT,
};
</script>

<template>
  <div>
    <div v-if="!isQueryPresent">
      <div class="col-12 gl-mt-4">
        <div class="text-content">
          <p data-testid="measurement-hl" class="gl-mb-4 gl-mt-0 gl-text-subtle">
            {{ s__('Analytics|Start by choosing a measure') }}
          </p>
        </div>
      </div>
    </div>
    <div v-if="resultVisualization && isQueryPresent">
      <div class="gl-m-5 gl-flex gl-flex-wrap-reverse gl-items-center gl-justify-between gl-gap-5">
        <div class="gl-flex gl-gap-3">
          <gl-button-group>
            <gl-button
              v-for="buttonDisplayType in $options.PANEL_DISPLAY_TYPE_ITEMS"
              :key="buttonDisplayType.type"
              :selected="displayType === buttonDisplayType.type"
              :icon="buttonDisplayType.icon"
              :data-testid="`select-${buttonDisplayType.type}-button`"
              @click="$emit('selectedDisplayType', buttonDisplayType.type)"
              >{{ buttonDisplayType.title }}</gl-button
            >
          </gl-button-group>
          <gl-icon
            v-gl-tooltip
            :title="
              s__(
                'Analytics|The visualization preview displays only the last 7 days. Dashboard visualizations can display the entire date range.',
              )
            "
            name="information-o"
            class="gl-mb-3 gl-min-w-5 gl-self-end"
            variant="subtle"
          />
        </div>
      </div>
      <div class="border-light gl-border gl-m-5 gl-overflow-auto gl-rounded-base gl-shadow-sm">
        <div v-if="displayType === $options.PANEL_DISPLAY_TYPES.VISUALIZATION">
          <analytics-dashboard-panel
            v-if="selectedVisualizationType"
            :title="title"
            :visualization="resultVisualization"
            :style="{ height: $options.PANEL_VISUALIZATION_HEIGHT }"
            data-testid="preview-visualization"
            class="gl-border-none gl-shadow-none"
          />
          <div
            v-else
            class="col-12 gl-overflow-y-auto gl-bg-default"
            :style="{ height: $options.PANEL_VISUALIZATION_HEIGHT }"
          >
            <div class="text-content">
              <p class="gl-text-subtle">
                {{ s__('Analytics|Select a visualization type') }}
              </p>
            </div>
          </div>
        </div>

        <div v-if="displayType === $options.PANEL_DISPLAY_TYPES.CODE" class="gl-bg-default gl-p-4">
          <pre
            class="code highlight gl-flex gl-border-none gl-bg-transparent"
            data-testid="preview-code"
          ><code>{{ previewYamlConfiguration }}</code></pre>
        </div>
      </div>
    </div>
  </div>
</template>
