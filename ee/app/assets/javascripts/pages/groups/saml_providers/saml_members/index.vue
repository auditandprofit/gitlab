<!-- eslint-disable vue/multi-word-component-names -->
<script>
import { GlSkeletonLoader, GlTable, GlAvatar } from '@gitlab/ui';
// eslint-disable-next-line no-restricted-imports
import { mapState, mapActions } from 'vuex';
import { __, s__ } from '~/locale';
import TablePagination from '~/vue_shared/components/pagination/table_pagination.vue';

export default {
  components: {
    GlSkeletonLoader,
    GlTable,
    GlAvatar,
    TablePagination,
  },
  computed: {
    ...mapState(['isInitialLoadInProgress', 'members', 'pageInfo']),
  },
  fields: [
    {
      key: 'name',
      label: __('User'),
    },
    {
      key: 'identity',
      label: s__('GroupSAML|Identifier'),
    },
    {
      key: 'scim_identity',
      label: s__('GroupSAML|SCIM Identifier'),
    },
  ],
  mounted() {
    this.fetchPage();
  },
  methods: {
    ...mapActions(['fetchPage']),
    change(nextPage) {
      this.fetchPage(nextPage);
    },
  },
};
</script>
<template>
  <div class="gl-mt-3">
    <gl-skeleton-loader v-if="isInitialLoadInProgress" />
    <gl-table v-else :items="members" :fields="$options.fields">
      <template #cell(name)="{ item }">
        <span class="gl-flex">
          <gl-avatar :src="item.avatar_url" :size="48" />
          <div class="ml-2">
            <div class="font-weight-bold">
              <a
                class="js-user-link"
                :href="item.web_url"
                :data-user-id="item.id"
                :data-username="item.username"
              >
                {{ item.name }}
              </a>
            </div>
            <div class="gl-text-default">@{{ item.username }}</div>
          </div>
        </span>
      </template>
      <template #cell(identity)="{ value }">
        <span class="font-weight-bold">{{ value }}</span>
      </template>
      <template #cell(scim_identity)="{ value }">
        <span class="font-weight-bold">{{ value }}</span>
      </template>
    </gl-table>
    <table-pagination :page-info="pageInfo" :change="change" />
  </div>
</template>
