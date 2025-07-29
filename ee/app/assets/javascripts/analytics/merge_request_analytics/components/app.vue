<script>
import DateRange from '~/analytics/shared/components/daterange.vue';
import { dateFormats } from '~/analytics/shared/constants';
import dateFormat from '~/lib/dateformat';
import UrlSync from '~/vue_shared/components/url_sync.vue';
import PageHeading from '~/vue_shared/components/page_heading.vue';
import { DEFAULT_NUMBER_OF_DAYS } from '../constants';
import FilterBar from './filter_bar.vue';
import ThroughputChart from './throughput_chart.vue';
import ThroughputTableProvider from './throughput_table_provider.vue';

export default {
  name: 'MergeRequestAnalyticsApp',
  components: {
    PageHeading,
    DateRange,
    FilterBar,
    ThroughputChart,
    ThroughputTableProvider,
    UrlSync,
  },
  props: {
    startDate: {
      type: Date,
      required: true,
    },
    endDate: {
      type: Date,
      required: true,
    },
  },
  computed: {
    query() {
      return {
        start_date: dateFormat(this.startDate, dateFormats.isoDate),
        end_date: dateFormat(this.endDate, dateFormats.isoDate),
      };
    },
  },
  methods: {
    setDateRange({ startDate, endDate }) {
      // eslint-disable-next-line vue/no-mutating-props
      this.startDate = startDate;
      // eslint-disable-next-line vue/no-mutating-props
      this.endDate = endDate;
    },
  },
  dateRangeLimit: DEFAULT_NUMBER_OF_DAYS,
};
</script>
<template>
  <div class="merge-request-analytics-wrapper">
    <page-heading :heading="__('Merge request analytics')" />
    <div
      class="gl-flex gl-flex-col gl-justify-between gl-gap-4 gl-border-b-1 gl-border-t-1 gl-border-b-default gl-border-t-default gl-bg-subtle gl-p-5 gl-border-b-solid gl-border-t-solid lg:gl-flex-row"
    >
      <filter-bar class="gl-grow" />
      <date-range
        :start-date="startDate"
        :end-date="endDate"
        :max-date-range="$options.dateRangeLimit"
        class="lg:gl-mx-3"
        @change="setDateRange"
      />
    </div>
    <throughput-chart :start-date="startDate" :end-date="endDate" />
    <throughput-table-provider :start-date="startDate" :end-date="endDate" class="gl-mt-6" />
    <url-sync :query="query" />
  </div>
</template>
