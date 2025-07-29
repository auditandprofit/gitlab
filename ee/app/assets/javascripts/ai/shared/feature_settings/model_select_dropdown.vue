<script>
import { GlBadge, GlButton, GlCollapsibleListbox, GlExperimentBadge, GlIcon } from '@gitlab/ui';
import { s__ } from '~/locale';
import { SELF_HOSTED_ROUTE_NAMES } from 'ee/ai/duo_self_hosted/constants';
import { RELEASE_STATES } from './constants';

export default {
  name: 'ModelSelectDropdown',
  components: {
    GlBadge,
    GlButton,
    GlCollapsibleListbox,
    GlExperimentBadge,
    GlIcon,
  },
  props: {
    selectedOption: {
      type: Object,
      required: false,
      default: null,
    },
    items: {
      type: Array,
      required: true,
    },
    placeholderDropdownText: {
      type: String,
      required: false,
      default: '',
    },
    isFeatureSettingDropdown: {
      type: Boolean,
      required: false,
      default: false,
    },
    isLoading: {
      type: Boolean,
      required: false,
      default: false,
    },
  },
  SELF_HOSTED_ROUTE_NAMES,
  computed: {
    selected() {
      return this.selectedOption?.value || '';
    },
    dropdownToggleText() {
      return this.selectedOption?.text || this.placeholderDropdownText;
    },
    headerText() {
      return this.isFeatureSettingDropdown ? s__('AdminAIPoweredFeatures|Compatible models') : null;
    },
  },
  methods: {
    isBetaModel(model) {
      return model?.releaseState === RELEASE_STATES.BETA;
    },
    isDefaultModel(model) {
      return model?.value === '';
    },
    onSelect(option) {
      this.$emit('select', option);
    },
  },
};
</script>
<template>
  <gl-collapsible-listbox
    :selected="selected"
    data-testid="model-dropdown-selector"
    :items="items"
    :header-text="headerText"
    :loading="isLoading"
    category="primary"
    block
    @select="onSelect"
  >
    <template #toggle>
      <gl-button
        :loading="isLoading"
        :text="dropdownToggleText"
        :aria-label="dropdownToggleText"
        block
      >
        <template #emoji>
          <div data-testid="dropdown-toggle-text" class="gl-flex gl-w-full gl-justify-between">
            <div class="gl-align-items gl-flex gl-overflow-hidden">
              <gl-badge
                v-if="isDefaultModel(selectedOption)"
                data-testid="default-model-selected-badge"
                class="!gl-ml-0 gl-mr-3"
                variant="info"
                icon="tanuki"
                icon-size="sm"
              />
              <gl-experiment-badge
                v-if="isBetaModel(selectedOption)"
                data-testid="beta-model-selected-badge"
                class="!gl-ml-0 gl-mr-3"
                type="beta"
              />
              <span class="gl-overflow-hidden gl-text-ellipsis">{{ dropdownToggleText }}</span>
            </div>
            <div>
              <gl-icon name="chevron-down" />
            </div>
          </div>
        </template>
      </gl-button>
    </template>

    <template #list-item="{ item }">
      <div class="gl-flex gl-items-center gl-justify-between">
        {{ item.text }}
        <gl-badge
          v-if="isDefaultModel(item)"
          data-testid="default-model-dropdown-badge"
          variant="info"
          icon="tanuki"
        />
        <gl-badge
          v-if="isBetaModel(item)"
          data-testid="beta-model-dropdown-badge"
          variant="neutral"
        >
          {{ __('Beta') }}
        </gl-badge>
      </div>
    </template>

    <template v-if="isFeatureSettingDropdown" #footer>
      <div class="gl-border-t-1 gl-border-t-dropdown !gl-p-2 gl-border-t-solid">
        <gl-button
          data-testid="add-self-hosted-model-button"
          category="tertiary"
          :to="{ name: $options.SELF_HOSTED_ROUTE_NAMES.NEW }"
        >
          {{ s__('AdminAIPoweredFeatures|Add self-hosted model') }}
        </gl-button>
      </div>
    </template>
  </gl-collapsible-listbox>
</template>
