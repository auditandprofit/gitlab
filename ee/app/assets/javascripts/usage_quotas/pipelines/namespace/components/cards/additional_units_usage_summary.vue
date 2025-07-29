<script>
import { __ } from '~/locale';
import StatisticsCard from 'ee/usage_quotas/components/statistics_card.vue';
import { helpPagePath } from '~/helpers/help_page_helper';

export default {
  name: 'AdditionalUnitsUsageSummary',
  components: { StatisticsCard },
  props: {
    additionalUnitsUsed: {
      type: Number,
      required: true,
    },
    additionalUnitsLimit: {
      type: [Number, String],
      required: true,
    },
    additionalUnitsUsedPercentage: {
      type: Number,
      required: true,
    },
  },
  UNITS: __('units'),
  ADDITIONAL_UNITS: __('Additional units'),
  HELP_PAGE_LINK: helpPagePath('subscriptions/gitlab_com/compute_minutes'),
};
</script>

<template>
  <statistics-card
    :usage-value="additionalUnitsUsed"
    :total-value="additionalUnitsLimit"
    :total-unit="$options.UNITS"
    :description="$options.ADDITIONAL_UNITS"
    :percentage="additionalUnitsUsedPercentage"
    :help-link="$options.HELP_PAGE_LINK"
    :help-label="$options.ADDITIONAL_UNITS"
    summary-data-testid="additional-compute-minutes"
  />
</template>
