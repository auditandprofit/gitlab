import { __ } from '~/locale';

export function getVisualizationOptions(visualizationType, hasTimeDimension, measureSubType) {
  switch (visualizationType) {
    case 'LineChart':
      return {
        xAxis: {
          name: __('Time'),
          type: 'time',
        },
        yAxis: {
          name: __('Counts'),
          type: 'value',
        },
      };
    case 'ColumnChart':
      return {
        xAxis: hasTimeDimension
          ? { name: __('Time'), type: 'time' }
          : {
              name: __('Dimension'),
              type: 'category',
            },
        yAxis: {
          name: __('Counts'),
          type: 'value',
        },
      };
    case 'SingleStat':
      if (measureSubType === 'returningUserPercentage') {
        return {
          unit: '%',
        };
      }

      return {};
    default:
      return {};
  }
}
