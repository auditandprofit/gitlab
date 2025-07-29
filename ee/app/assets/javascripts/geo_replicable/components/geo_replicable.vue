<script>
import { GlKeysetPagination } from '@gitlab/ui';
// eslint-disable-next-line no-restricted-imports
import { mapState, mapActions } from 'vuex';
import { PREV, NEXT } from '../constants';
import GeoReplicableItem from './geo_replicable_item.vue';

export default {
  name: 'GeoReplicable',
  components: {
    GlKeysetPagination,
    GeoReplicableItem,
  },
  computed: {
    ...mapState(['replicableItems', 'paginationData']),
  },
  methods: {
    ...mapActions(['fetchReplicableItems']),
  },
  NEXT,
  PREV,
};
</script>

<template>
  <section>
    <geo-replicable-item
      v-for="item in replicableItems"
      :key="item.id"
      :registry-id="item.id"
      :model-record-id="item.modelRecordId"
      :sync-status="item.state"
      :verification-state="item.verificationState"
      :last-synced="item.lastSyncedAt"
      :last-verified="item.verifiedAt"
      :last-sync-failure="item.lastSyncFailure"
      :verification-failure="item.verificationFailure"
    />
    <div class="gl-mt-6 gl-flex gl-justify-center">
      <gl-keyset-pagination
        v-bind="paginationData"
        @next="fetchReplicableItems($options.NEXT)"
        @prev="fetchReplicableItems($options.PREV)"
      />
    </div>
  </section>
</template>
