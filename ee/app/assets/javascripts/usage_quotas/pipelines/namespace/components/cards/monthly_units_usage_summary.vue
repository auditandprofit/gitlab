<script>
import { localeDateFormat, newDate } from '~/lib/utils/datetime_utility';
import { sprintf, s__, __ } from '~/locale';
import StatisticsCard from 'ee/usage_quotas/components/statistics_card.vue';
import { helpPagePath } from '~/helpers/help_page_helper';

export default {
  name: 'MonthlyUnitsUsageSummary',
  components: { StatisticsCard },
  props: {
    monthlyUnitsUsed: {
      type: Number,
      required: true,
    },
    monthlyUnitsLimit: {
      type: [Number, String],
      required: true,
    },
    monthlyUnitsUsedPercentage: {
      type: Number,
      required: true,
    },
    lastResetDate: {
      type: String,
      required: true,
    },
    anyProjectEnabled: {
      type: Boolean,
      required: true,
    },
    displayMinutesAvailableData: {
      type: Boolean,
      required: true,
    },
  },
  computed: {
    monthlyUsageTitle() {
      return sprintf(s__('UsageQuota|Compute usage since %{usageSince}'), {
        usageSince: localeDateFormat.asDate.format(newDate(this.lastResetDate)),
      });
    },
    percentageUsed() {
      if (this.displayMinutesAvailableData) {
        return Number(this.monthlyUnitsUsedPercentage);
      }

      return null;
    },
  },
  UNITS: __('units'),
  HELP_PAGE_LINK: helpPagePath('ci/pipelines/compute_minutes'),
  CI_MINUTES_HELP_LINK_LABEL: __('Instance runners help link'),
};
</script>

<template>
  <statistics-card
    :usage-value="monthlyUnitsUsed"
    :usage-unit="anyProjectEnabled ? null : $options.UNITS"
    :total-value="monthlyUnitsLimit"
    :total-unit="anyProjectEnabled ? $options.UNITS : null"
    :description="monthlyUsageTitle"
    :percentage="percentageUsed"
    :help-link="$options.HELP_PAGE_LINK"
    :help-label="$options.CI_MINUTES_HELP_LINK_LABEL"
    summary-data-testid="plan-compute-minutes"
  />
</template>
