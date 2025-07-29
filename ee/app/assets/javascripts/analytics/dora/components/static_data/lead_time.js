import { helpPagePath } from '~/helpers/help_page_helper';
import { s__ } from '~/locale';
import { humanizeTimeInterval } from '~/lib/utils/datetime_utility';

export * from './shared';

export const CHART_TITLE = s__('DORA4Metrics|Lead time for changes');

export const areaChartOptions = {
  grid: { containLabel: true },
  xAxis: {
    name: s__('DORA4Metrics|Date'),
    type: 'category',
  },
  yAxis: {
    name: s__('DORA4Metrics|Time from merge to deploy'),
    nameGap: 65,
    type: 'value',
    minInterval: 1,
    axisLabel: {
      formatter(seconds) {
        return humanizeTimeInterval(seconds, { abbreviated: true });
      },
    },
  },
};

export const chartDescriptionText = s__(
  'DORA4Metrics|The chart displays the median time between a merge request being merged and deployed to production environment(s) that are based on the %{linkStart}deployment_tier%{linkEnd} value.',
);

export const chartDocumentationHref = helpPagePath('user/analytics/ci_cd_analytics', {
  anchor: 'view-cicd-analytics',
});
