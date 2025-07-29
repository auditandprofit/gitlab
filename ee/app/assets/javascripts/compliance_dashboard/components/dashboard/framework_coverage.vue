<script>
import { GlButton, GlEmptyState } from '@gitlab/ui';
import { GlChart } from '@gitlab/ui/dist/charts';

import { GL_LIGHT } from '~/constants';
import { s__, sprintf } from '~/locale';
import { getIdFromGraphQLId } from '~/graphql_shared/utils';
import { sanitize } from '~/lib/dompurify';
import glAbilitiesMixin from '~/vue_shared/mixins/gl_abilities_mixin';
import { ROUTE_NEW_FRAMEWORK, ROUTE_PROJECTS, i18n } from '../../constants';
import { getColors } from './utils/chart';

const generateFrameworkChartId = (framework) => `framework_${getIdFromGraphQLId(framework.id)}`;

export default {
  components: {
    GlButton,
    GlChart,
    GlEmptyState,
  },
  mixins: [glAbilitiesMixin()],
  props: {
    summary: {
      type: Object,
      required: true,
    },
    isTopLevelGroup: {
      type: Boolean,
      required: true,
    },
    colorScheme: {
      type: String,
      required: false,
      default: GL_LIGHT,
    },
  },
  computed: {
    canAdminComplianceFramework() {
      return this.glAbilities.adminComplianceFramework;
    },
    chartConfig() {
      const yAxisTitles = this.summary.details
        .map(({ framework }) => `{${generateFrameworkChartId(framework)}|${framework.name}}`)
        .reverse();

      const TOOLTIP_OPTIONS = {
        padding: 0,
        borderWidth: 0,
      };
      const { textColor, blueDataColor, orangeDataColor, ticksColor } = getColors(this.colorScheme);

      const yAxisLabels = Object.fromEntries(
        this.summary.details.map(({ framework }) => [
          generateFrameworkChartId(framework),
          {
            backgroundColor: framework.color,
            color: 'white',
            padding: [2, 8],
            borderRadius: 999,
            fontSize: 12,
            fontWeight: 400,
          },
        ]),
      );

      const percents = this.summary.details
        .map(({ coveredCount }) => Math.floor((coveredCount / this.summary.totalProjects) * 100))
        .reverse();

      const totalCoveredPercent = Math.floor(
        (this.summary.coveredCount / this.summary.totalProjects) * 100,
      );

      return {
        grid: {
          left: 0,
          right: 20,
          top: 50,
          bottom: 0,
          containLabel: true,
        },

        tooltip: {
          ...TOOLTIP_OPTIONS,
          trigger: 'item',
          formatter: (params) => this.getTooltip(params.dataIndex),
        },

        xAxis: {
          type: 'value',
          min: 0,
          max: 100,
          interval: 10,
          axisLabel: {
            // eslint-disable-next-line @gitlab/require-i18n-strings
            formatter: '{value}%',
            fontWeight: 'bold',
          },
          splitLine: {
            show: true,
            lineStyle: {
              color: ticksColor,
              width: 2,
            },
          },
          axisLine: {
            show: false,
          },
          axisTick: {
            show: false,
          },
        },

        yAxis: {
          type: 'category',
          triggerEvent: true,
          tooltip: {
            ...TOOLTIP_OPTIONS,
            show: true,
            formatter: (params) => this.getTooltip(params.tickIndex),
          },
          // eslint-disable-next-line @gitlab/require-i18n-strings
          data: [...yAxisTitles, `{all|${s__('ComplianceReport|All frameworks')}}`],
          axisLine: {
            show: false,
          },
          axisTick: {
            show: false,
          },
          axisLabel: {
            rich: {
              ...yAxisLabels,
              all: {
                color: textColor,
                fontSize: 12,
                fontWeight: 'bold',
              },
            },
          },
        },

        series: [
          {
            name: s__('ComplianceReport|Projects covered by frameworks'),
            type: 'bar',
            stack: 'total',
            data: [...percents.map((value) => ({ value })), { value: totalCoveredPercent }],
            itemStyle: {
              color: blueDataColor,
              borderColor: '#00000000',
              borderWidth: 10,
            },
            barWidth: '80%',
          },
          {
            name: s__('ComplianceReport|Projects not covered by frameworks'),
            type: 'bar',
            stack: 'total',
            data: [
              ...percents.map((value) => ({ value: 100 - value })),
              { value: 100 - totalCoveredPercent },
            ],
            itemStyle: {
              color: orangeDataColor,
              borderColor: '#00000000',
              borderWidth: 10,
            },
          },
        ],

        legend: {
          data: [
            s__('ComplianceReport|Projects covered by frameworks'),
            s__('ComplianceReport|Projects not covered by frameworks'),
          ],
          top: 0,
          left: 0,
          orient: 'vertical',
          itemWidth: 14,
          itemHeight: 14,
          itemGap: 8,
          textStyle: {
            fontSize: 12,
            color: textColor,
            fontWeight: 'bold',
          },
        },
      };
    },
  },
  methods: {
    handleChartClick() {
      this.$router.push({ name: ROUTE_PROJECTS });
    },
    getTooltip(dataIndex) {
      // Data is inverted in chart representation
      const index = this.summary.details.length - 1 - dataIndex;

      if (index === -1) {
        return this.getAllFrameworksTooltip();
      }
      return this.getTooltipForFramework(this.summary.details[index]);
    },
    getAllFrameworksTooltip() {
      const coveragePercent = Math.round(
        (this.summary.coveredCount / this.summary.totalProjects) * 100,
      );
      const uncoveredCount = this.summary.totalProjects - this.summary.coveredCount;

      return `<div class="gl-text-default gl-text-sm gl-bg-default gl-p-3">
        <h4 class="gl-font-bold gl-text-sm gl-m-0 gl-mb-2">${sprintf(
          s__('ComplianceReport|%{percent}%% coverage'),
          {
            percent: coveragePercent,
          },
        )}</h4>
        <ul class="gl-list-none gl-m-0 gl-p-0">
          <li>${sprintf(s__('ComplianceReport|%{count} projects have at least one framework'), {
            count: this.summary.coveredCount,
          })}</li>
          <li>${sprintf(s__('ComplianceReport|%{count} projects have no framework at all'), {
            count: uncoveredCount,
          })}</li>
        </ul>
        <p class="gl-font-bold gl-mt-2 gl-mb-0">${s__('ComplianceReport|Click to check all projects')}</p>
      </div>`;
    },
    getTooltipForFramework(details) {
      const { coveredCount } = details;
      const uncoveredCount = this.summary.totalProjects - coveredCount;
      const coveragePercent = Math.round((coveredCount / this.summary.totalProjects) * 100);
      const sanitizedFrameworkName = sanitize(details.framework.name, { ALLOWED_TAGS: [] });

      return `<div class="gl-text-default gl-text-sm gl-bg-default gl-p-3">
        <h4 class="gl-font-bold gl-text-sm gl-m-0 gl-mb-2">${sprintf(
          s__('ComplianceReport|%{percent}%% coverage for %{framework}'),
          {
            percent: coveragePercent,
            framework: sanitizedFrameworkName,
          },
        )}</h4>
        <ul class="gl-list-none gl-m-0 gl-p-0">
          <li>${sprintf(s__('ComplianceReport|%{count} projects have framework: %{framework}'), {
            count: coveredCount,
            framework: sanitizedFrameworkName,
          })}</li>
          <li>${sprintf(s__('ComplianceReport|%{count} projects are not covered by %{framework}'), {
            count: uncoveredCount,
            framework: sanitizedFrameworkName,
          })}</li>
        </ul>
        <p class="gl-font-bold gl-mt-2 gl-mb-0">${s__('ComplianceReport|Click to check all projects')}</p>
      </div>`;
    },
    newFramework() {
      this.$router.push({ name: ROUTE_NEW_FRAMEWORK });
    },
  },
  i18n,
};
</script>
<template>
  <gl-chart
    v-if="summary.details.length"
    ref="glChart"
    height="auto"
    :options="chartConfig"
    @chartItemClicked="handleChartClick"
  />
  <gl-empty-state
    v-else
    :title="s__('ComplianceReport|There are no compliance frameworks.')"
    :description="s__('ComplianceReport|Start by adding a compliance framework to your group.')"
    class="gl-m-0 gl-pt-3"
  >
    <template #actions>
      <gl-button
        v-if="canAdminComplianceFramework && isTopLevelGroup"
        category="primary"
        variant="confirm"
        @click="newFramework"
      >
        {{ $options.i18n.newFramework }}
      </gl-button>
    </template>
  </gl-empty-state>
</template>
