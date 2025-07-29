<script>
import {
  GlButton,
  GlDisclosureDropdown,
  GlDisclosureDropdownItem,
  GlTooltipDirective,
} from '@gitlab/ui';
// eslint-disable-next-line no-restricted-imports
import { mapActions, mapState } from 'vuex';
import { s__ } from '~/locale';
import {
  EXPORT_FORMAT_CSV,
  EXPORT_FORMAT_DEPENDENCY_LIST,
  EXPORT_FORMAT_JSON_ARRAY,
  EXPORT_FORMAT_CYCLONEDX_1_6_JSON,
  NAMESPACE_GROUP,
  NAMESPACE_ORGANIZATION,
  NAMESPACE_PROJECT,
} from '../constants';

const availableForContainers = (supportedContainers) => {
  return (component) => supportedContainers.includes(component.container);
};

const exportFormats = [
  {
    type: EXPORT_FORMAT_DEPENDENCY_LIST,
    buttonText: s__('Dependencies|Export as JSON'),
    testid: 'dependency-list-item',
    available: availableForContainers([NAMESPACE_PROJECT]),
  },
  {
    type: EXPORT_FORMAT_JSON_ARRAY,
    buttonText: s__('Dependencies|Export as JSON'),
    testid: 'json-array-item',
    available: availableForContainers([NAMESPACE_GROUP]),
  },
  {
    type: EXPORT_FORMAT_CSV,
    buttonText: s__('Dependencies|Export as CSV'),
    testid: 'csv-item',
    available: availableForContainers([NAMESPACE_PROJECT, NAMESPACE_GROUP, NAMESPACE_ORGANIZATION]),
  },
  {
    type: EXPORT_FORMAT_CYCLONEDX_1_6_JSON,
    buttonText: s__('Dependencies|Export as CycloneDX (JSON)'),
    testid: 'cyclonedx-1-6-item',
    available: availableForContainers([NAMESPACE_PROJECT]),
  },
];

export default {
  name: 'DependencyExportDropdown',
  components: {
    GlButton,
    GlDisclosureDropdown,
    GlDisclosureDropdownItem,
  },
  directives: {
    GlTooltip: GlTooltipDirective,
  },
  props: {
    // Used in availability check.
    // eslint-disable-next-line vue/no-unused-properties
    container: {
      type: String,
      required: true,
    },
  },
  computed: {
    ...mapState(['fetchingInProgress']),
    availableFormats() {
      return exportFormats.filter((format) => format.available(this));
    },
    multipleFormats() {
      return this.availableFormats.length > 1;
    },
    singleFormat() {
      return this.availableFormats[0];
    },
    exportButtonIcon() {
      return this.fetchingInProgress ? '' : 'export';
    },
  },
  methods: {
    ...mapActions({
      createExport(dispatch, type) {
        return dispatch('fetchExport', { export_type: type });
      },
    }),
  },
};
</script>

<template>
  <gl-disclosure-dropdown
    v-if="multipleFormats"
    :icon="exportButtonIcon"
    :loading="fetchingInProgress"
    :toggle-text="__('Export')"
    data-testid="export-disclosure"
  >
    <gl-disclosure-dropdown-item
      v-for="format in availableFormats"
      :key="format.type"
      :data-testid="format.testid"
      @action="createExport(format.type)"
    >
      <template #list-item>
        {{ format.buttonText }}
      </template>
    </gl-disclosure-dropdown-item>
  </gl-disclosure-dropdown>

  <gl-button
    v-else
    v-gl-tooltip.hover
    :title="singleFormat.buttonText"
    class="gl-mt-3 md:gl-mt-0"
    :icon="exportButtonIcon"
    :loading="fetchingInProgress"
    @click="createExport(singleFormat.type)"
  >
    {{ __('Export') }}
  </gl-button>
</template>
