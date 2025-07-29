<script>
import { GlButton, GlIcon, GlTruncate, GlCollapsibleListbox, GlLink } from '@gitlab/ui';
import { debounce } from 'lodash';
import { n__, s__, sprintf } from '~/locale';
import axios from '~/lib/utils/axios_utils';
import { DEFAULT_DEBOUNCE_AND_THROTTLE_MS } from '~/lib/utils/constants';
import glFeatureFlagMixin from '~/vue_shared/mixins/gl_feature_flags_mixin';
import { filterPathBySearchTerm } from '../store/utils';
import { SEARCH_MIN_THRESHOLD } from './constants';

const mapItemToListboxFormat = (item, index) => ({
  ...item,
  value: index,
  text: item.location.path,
});

export default {
  name: 'DependencyLocationCount',
  components: {
    GlButton,
    GlIcon,
    GlTruncate,
    GlCollapsibleListbox,
    GlLink,
  },
  mixins: [glFeatureFlagMixin()],
  inject: ['locationsEndpoint'],
  props: {
    locationCount: {
      type: Number,
      required: true,
    },
    componentId: {
      type: Number,
      required: true,
    },
  },
  data() {
    return {
      loading: true,
      locations: [],
      searchTerm: '',
    };
  },
  computed: {
    locationText() {
      return sprintf(
        n__(
          'Dependencies|%{locationCount} location',
          'Dependencies|%{locationCount} locations',
          this.locationCount,
        ),
        {
          locationCount: this.locationCount,
        },
      );
    },
    availableLocations() {
      return filterPathBySearchTerm(this.locations, this.searchTerm);
    },
    searchEnabled() {
      return this.loading || this.locationCount > SEARCH_MIN_THRESHOLD;
    },
    hasAnyDependencyPaths() {
      return this.locations.some((item) => item.has_dependency_paths);
    },
  },
  i18n: {
    unknownPath: s__('Dependencies|Unknown path'),
    dependencyPathButtonText: s__('Dependencies|View dependency paths'),
  },
  created() {
    this.search = debounce((searchTerm) => {
      this.searchTerm = searchTerm;
      this.fetchData();
    }, DEFAULT_DEBOUNCE_AND_THROTTLE_MS);
  },
  methods: {
    onHide() {
      this.searchTerm = '';
    },
    onShown() {
      this.search();
    },
    hasLocationPath(item) {
      return item.location.blob_path && item.location.path;
    },
    isTopLevelDependency(item) {
      return item.location.top_level;
    },
    async fetchData() {
      this.loading = true;

      const {
        data: { locations },
      } = await axios.get(this.locationsEndpoint, {
        params: {
          search: this.searchTerm,
          component_id: this.componentId,
        },
      });
      this.loading = false;
      this.locations = locations.map(mapItemToListboxFormat);
    },
    async onDependencyPathClick() {
      this.$emit('click-dependency-path', this.locations);
    },
  },
};
</script>

<template>
  <gl-collapsible-listbox
    :header-text="locationText"
    :items="availableLocations"
    :searching="loading"
    :searchable="searchEnabled"
    @hidden="onHide"
    @search="search"
    @shown="onShown"
  >
    <template #toggle>
      <gl-button variant="link" category="tertiary" icon="doc-text" data-testid="toggle-text">
        <span class="md:gl-hidden">{{ locationCount }}</span>
        <span class="gl-hidden md:gl-inline-flex">{{ locationText }}</span>
      </gl-button>
    </template>
    <template #list-item="{ item }">
      <div v-if="item">
        <div class="gl-text-blue-500 md:gl-whitespace-nowrap">
          <gl-link
            v-if="hasLocationPath(item)"
            :href="item.location.blob_path"
            class="hover:gl-no-underline"
          >
            <gl-icon name="doc-text" class="gl-absolute" />
            <gl-truncate position="start" :text="item.location.path" with-tooltip class="gl-pl-6" />
          </gl-link>
          <div v-else class="gl-text-subtle" data-testid="unknown-path">
            <gl-icon name="error" class="gl-absolute" />
            <gl-truncate
              position="start"
              :text="$options.i18n.unknownPath"
              with-tooltip
              class="gl-pl-6"
            />
          </div>
        </div>
        <div v-if="isTopLevelDependency(item)" class="gl-pl-6 gl-text-subtle">
          {{ s__('Dependencies|(top level)') }}
        </div>
        <gl-truncate :text="item.project.name" class="gl-mt-2 gl-pl-6 gl-text-subtle" />
      </div>
    </template>
    <template v-if="glFeatures.dependencyPaths && hasAnyDependencyPaths" #footer>
      <div
        class="gl-flex gl-flex-col gl-border-t-1 gl-border-t-dropdown-divider !gl-p-2 !gl-pt-0 gl-border-t-solid"
      >
        <gl-button
          category="tertiary"
          block
          class="!gl-mt-2 !gl-justify-center"
          data-testid="dependency-path-button"
          icon="file-tree"
          @click="onDependencyPathClick"
        >
          {{ $options.i18n.dependencyPathButtonText }}
        </gl-button>
      </div>
    </template>
  </gl-collapsible-listbox>
</template>
