<script>
import { GlButton, GlFormGroup, GlFormInput, GlLink, GlSprintf } from '@gitlab/ui';
import { isEqual } from 'lodash';

import { getVisualizationOptions } from 'ee/analytics/analytics_dashboards/utils/data_explorer_options';
import { __, s__ } from '~/locale';
import { createAlert } from '~/alert';
import { confirmAction } from '~/lib/utils/confirm_via_gl_modal/confirm_action';
import { slugify } from '~/lib/utils/text_utility';
import { HTTP_STATUS_CREATED } from '~/lib/utils/http_status';
import { helpPagePath } from '~/helpers/help_page_helper';
import { InternalEvents } from '~/tracking';

import { fetchFilterOptions } from 'ee/analytics/analytics_dashboards/data_sources/cube_analytics';
import { saveProductAnalyticsVisualization } from 'ee/analytics/analytics_dashboards/api/dashboards_api';
import {
  FILE_ALREADY_EXISTS_SERVER_RESPONSE,
  PANEL_DISPLAY_TYPES,
  EVENT_LABEL_USER_VIEWED_DATA_EXPLORER,
  EVENT_LABEL_USER_CREATED_CUSTOM_VISUALIZATION,
  DEFAULT_VISUALIZATION_QUERY_STATE,
  DEFAULT_VISUALIZATION_TITLE,
  VISUALIZATION_TYPE_DATA_TABLE,
  NEW_DASHBOARD_SLUG,
} from '../constants';
import VisualizationPreview from './data_explorer/analytics_visualization_preview.vue';
import VisualizationTypeSelector from './data_explorer/analytics_visualization_type_selector.vue';

import VisualizationFilteredSearch from './data_explorer/filters/visualization_filtered_search.vue';

export default {
  name: 'AnalyticsDataExplorer',
  components: {
    GlButton,
    GlFormInput,
    GlFormGroup,
    GlLink,
    GlSprintf,
    VisualizationFilteredSearch,
    VisualizationTypeSelector,
    VisualizationPreview,
  },
  mixins: [InternalEvents.mixin()],
  inject: {
    customDashboardsProject: {
      type: Object,
      default: null,
    },
  },
  async beforeRouteLeave(to, from, next) {
    const confirmed = await this.confirmDiscardIfChanged();
    if (!confirmed) return;

    next();
  },
  data() {
    return {
      queryState: DEFAULT_VISUALIZATION_QUERY_STATE(),
      visualizationTitle: '',
      titleValidationError: null,
      selectedDisplayType: PANEL_DISPLAY_TYPES.VISUALIZATION,
      selectedVisualizationType: VISUALIZATION_TYPE_DATA_TABLE,
      isSaving: false,
      alert: null,
      filterOptions: {
        availableMeasures: [],
        availableDimensions: [],
        availableTimeDimensions: [],
      },
    };
  },
  computed: {
    resultVisualization() {
      const newCubeQuery = this.queryState.query;

      return {
        version: 1,
        type: this.selectedVisualizationType,
        data: {
          type: 'cube_analytics',
          query: newCubeQuery,
        },
        options: this.panelOptions,
      };
    },
    panelOptions() {
      return getVisualizationOptions(
        this.selectedVisualizationType,
        this.queryState.timeDimensions?.length,
        this.queryState.measureSubType,
      );
    },
    saveButtonText() {
      return this.$route?.params.dashboardid
        ? s__('Analytics|Save and add to Dashboard')
        : s__('Analytics|Save your visualization');
    },
    changesMade() {
      return (
        this.visualizationTitle !== DEFAULT_VISUALIZATION_TITLE ||
        this.selectedVisualizationType !== VISUALIZATION_TYPE_DATA_TABLE ||
        this.queryStateHasChanges
      );
    },
    queryStateHasChanges() {
      return !isEqual({ ...this.queryState }, DEFAULT_VISUALIZATION_QUERY_STATE());
    },
  },
  beforeDestroy() {
    this.alert?.dismiss();
    window.removeEventListener('beforeunload', this.onPageUnload);
  },
  async mounted() {
    const wrappers = document.querySelectorAll('.container-fluid.container-limited');

    wrappers.forEach((el) => {
      el.classList.remove('container-limited');
    });

    this.trackEvent(EVENT_LABEL_USER_VIEWED_DATA_EXPLORER);

    window.addEventListener('beforeunload', this.onPageUnload);

    try {
      // Fill the filter bar with possible filter options
      this.filterOptions = await fetchFilterOptions(document.body.dataset.projectId);
    } catch (error) {
      this.showAlert(s__('Analytics|An error occurred while loading data'), error, true);
    }
  },
  methods: {
    onFilterChange(query) {
      this.queryState.query = { ...query };
    },
    selectDisplayType(newType) {
      this.selectedDisplayType = newType;
    },
    onVisualizationTypeChange() {
      this.selectDisplayType(PANEL_DISPLAY_TYPES.VISUALIZATION);
    },
    getRequiredFieldError(fieldValue) {
      return fieldValue.length > 0 ? '' : __('This field is required.');
    },
    validateTitle(submitting) {
      // Don't validate if the title has not been submitted
      if (this.titleValidationError !== null || submitting) {
        this.titleValidationError = this.getRequiredFieldError(this.visualizationTitle);
      }
    },
    getMetricsValidationError() {
      if (!this.queryState.query?.measures?.length) {
        return s__('Analytics|Select a measurement');
      }
      return null;
    },
    async saveVisualization() {
      let invalid = false;

      this.validateTitle(true);
      if (this.titleValidationError) {
        this.$refs.titleInput.$el.focus();
        invalid = true;
      }

      const validationError = this.getMetricsValidationError();
      if (validationError) {
        this.showAlert(validationError);
        invalid = true;
      }

      if (invalid) return;

      this.isSaving = true;

      try {
        const filename = slugify(this.visualizationTitle, '_');

        const saveResult = await saveProductAnalyticsVisualization(
          filename,
          this.resultVisualization,
          this.customDashboardsProject,
        );

        if (saveResult.status === HTTP_STATUS_CREATED) {
          this.alert?.dismiss();

          this.$toast.show(s__('Analytics|Visualization was saved successfully'));

          this.trackEvent(EVENT_LABEL_USER_CREATED_CUSTOM_VISUALIZATION);

          this.resetToInitialState();

          if (this.$route?.params.dashboard) {
            this.routeToDashboard(this.$route?.params.dashboard);
          }
        } else {
          this.showAlert(
            this.$options.i18n.saveError,
            new Error(
              `Received an unexpected HTTP status while saving visualization: ${saveResult.status}`,
            ),
            true,
          );
        }
      } catch (error) {
        const { message = '' } = error?.response?.data || {};

        if (message === FILE_ALREADY_EXISTS_SERVER_RESPONSE) {
          this.titleValidationError = s__(
            'Analytics|A visualization with that name already exists.',
          );
        } else {
          this.showAlert(`${this.$options.i18n.saveError} ${message}`.trimEnd(), error, true);
        }
      } finally {
        this.isSaving = false;
      }
    },
    routeToDashboard(dashboard) {
      if (dashboard === NEW_DASHBOARD_SLUG) {
        this.$router.push('/new');
      } else {
        this.$router.push({
          name: 'dashboard-detail',
          params: {
            slug: dashboard,
            editing: true,
          },
        });
      }
    },
    routeToDashboardList() {
      this.$router.push('/');
    },
    confirmDiscardIfChanged() {
      if (!this.changesMade) {
        return true;
      }

      return confirmAction(
        s__('Analytics|Are you sure you want to cancel creating this visualization?'),
        {
          primaryBtnText: __('Discard changes'),
          cancelBtnText: s__('Analytics|Continue creating'),
        },
      );
    },
    onPageUnload(event) {
      if (!this.changesMade) return undefined;

      event.preventDefault();
      // This returnValue is required on some browsers. This message is displayed on older versions.
      // https://developer.mozilla.org/en-US/docs/Web/API/Window/beforeunload_event#compatibility_notes
      const returnValue = __('Are you sure you want to lose unsaved changes?');
      Object.assign(event, { returnValue });
      return returnValue;
    },
    showAlert(message, error = null, captureError = false) {
      this.alert = createAlert({
        message,
        error,
        captureError,
      });
    },

    resetToInitialState() {
      this.queryState = DEFAULT_VISUALIZATION_QUERY_STATE();
      this.visualizationTitle = '';
      this.selectedVisualizationType = VISUALIZATION_TYPE_DATA_TABLE;
    },
  },
  i18n: {
    saveError: s__('Analytics|Error while saving visualization.'),
  },
  helpPageUrl: helpPagePath('user/analytics/analytics_dashboards'),
};
</script>

<template>
  <div>
    <header class="gl-my-6">
      <h1 class="gl-heading-1 gl-m-0" data-testid="page-title">
        {{ s__('Analytics|Create your visualization') }}
      </h1>
      <p data-testid="page-description" class="gl-mb-0">
        {{
          s__(
            'Analytics|Use the data explorer to create custom visualizations. After you save a visualization, you can add it to a dashboard.',
          )
        }}
        <gl-sprintf :message="__('%{linkStart} Learn more%{linkEnd}.')">
          <template #link="{ content }">
            <gl-link data-testid="help-link" :href="$options.helpPageUrl">{{ content }}</gl-link>
          </template>
        </gl-sprintf>
      </p>
    </header>
    <section class="gl-flex">
      <div class="flex-fill gl-flex gl-flex-col">
        <gl-form-group
          :label="s__('Analytics|Visualization title')"
          label-for="title"
          class="gl-w-full gl-min-w-20 md:gl-max-w-7/10 lg:gl-w-3/10"
          data-testid="visualization-title-form-group"
          :invalid-feedback="titleValidationError"
          :state="!titleValidationError"
        >
          <gl-form-input
            id="title"
            ref="titleInput"
            v-model="visualizationTitle"
            dir="auto"
            type="text"
            :placeholder="s__('Analytics|Enter a visualization title')"
            :aria-label="s__('Analytics|Visualization title')"
            class="form-control gl-mr-4 gl-border-strong"
            data-testid="visualization-title-input"
            :state="!titleValidationError"
            required
            @input="validateTitle"
          />
        </gl-form-group>
      </div>
    </section>

    <section
      class="gl-border-t gl-border-b gl-mb-6 gl-flex gl-flex-wrap"
      data-testid="query-builder"
    >
      <div class="gl-border-b gl-flex gl-w-full gl-flex-col gl-gap-3 gl-py-4 md:gl-flex-row">
        <gl-form-group
          class="gl-m-0 gl-w-full md:gl-max-w-20"
          data-testid="visualization-type-form-group"
        >
          <visualization-type-selector
            ref="typeSelector"
            v-model="selectedVisualizationType"
            data-testid="visualization-type-dropdown"
            @input="onVisualizationTypeChange"
          />
        </gl-form-group>
        <visualization-filtered-search
          :query="queryState.query"
          :available-measures="filterOptions.availableMeasures"
          :available-dimensions="filterOptions.availableDimensions"
          :available-time-dimensions="filterOptions.availableTimeDimensions"
          data-testid="visualization-filtered-search"
          class="gl-my-3 gl-w-full"
          @input="onFilterChange"
          @submit="onFilterChange"
        />
      </div>

      <div class="gl-grow gl-overflow-auto gl-bg-subtle">
        <visualization-preview
          data-testid="visualization-previewer"
          :selected-visualization-type="selectedVisualizationType"
          :display-type="selectedDisplayType"
          :is-query-present="queryStateHasChanges"
          :loading="false"
          :result-visualization="queryStateHasChanges ? resultVisualization : null"
          :title="visualizationTitle"
          @selectedDisplayType="selectDisplayType"
        />
      </div>
    </section>
    <section>
      <gl-button
        :loading="isSaving"
        category="primary"
        variant="confirm"
        data-testid="visualization-save-btn"
        @click="saveVisualization"
      >
        {{ saveButtonText }}
      </gl-button>
      <gl-button
        category="secondary"
        data-testid="visualization-cancel-btn"
        @click="routeToDashboardList"
      >
        {{ __('Cancel') }}
      </gl-button>
    </section>
  </div>
</template>
