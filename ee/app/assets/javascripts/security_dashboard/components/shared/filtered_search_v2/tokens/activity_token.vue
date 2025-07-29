<script>
import {
  GlBadge,
  GlFilteredSearchToken,
  GlDropdownDivider,
  GlDropdownSectionHeader,
} from '@gitlab/ui';
import { without } from 'lodash';
import { s__ } from '~/locale';
import { getSelectedOptionsText } from '~/lib/utils/listbox_helpers';
import glAbilitiesMixin from '~/vue_shared/mixins/gl_abilities_mixin';
import glFeatureFlagsMixin from '~/vue_shared/mixins/gl_feature_flags_mixin';
import { ALL_ID as ALL_ACTIVITY_VALUE } from '../../filters/constants';
import { ITEMS as ACTIVITY_FILTER_ITEMS } from '../../filters/activity_filter.vue';
import SearchSuggestion from '../components/search_suggestion.vue';

const ITEMS = {
  ...ACTIVITY_FILTER_ITEMS,
  AI_RESOLUTION_AVAILABLE: {
    value: 'AI_RESOLUTION_AVAILABLE',
    text: s__('SecurityReports|Vulnerability Resolution available'),
  },
  AI_RESOLUTION_UNAVAILABLE: {
    value: 'AI_RESOLUTION_UNAVAILABLE',
    text: s__('SecurityReports|Vulnerability Resolution unavailable'),
  },
};

export const GROUPS = [
  {
    text: '',
    options: [
      {
        value: ALL_ACTIVITY_VALUE,
        text: s__('SecurityReports|All activity'),
      },
    ],
  },
  {
    text: s__('SecurityReports|Detection'),
    options: [ITEMS.STILL_DETECTED, ITEMS.NO_LONGER_DETECTED],
    icon: 'check-circle-dashed',
    variant: 'info',
  },
  {
    text: s__('SecurityReports|Issue'),
    options: [ITEMS.HAS_ISSUE, ITEMS.DOES_NOT_HAVE_ISSUE],
    icon: 'issues',
  },
  {
    text: s__('SecurityReports|Merge Request'),
    options: [ITEMS.HAS_MERGE_REQUEST, ITEMS.DOES_NOT_HAVE_MERGE_REQUEST],
    icon: 'merge-request',
  },
  {
    text: s__('SecurityReports|Solution available'),
    options: [ITEMS.HAS_SOLUTION, ITEMS.DOES_NOT_HAVE_SOLUTION],
    icon: 'bulb',
  },
];

const setSelectedStatus = (keyWhenTrue, keyWhenFalse, selectedActivities = []) => {
  // The variables can be true, false, or unset, so we need to use if/else-if here instead
  // of if/else.
  if (selectedActivities.includes(ITEMS[keyWhenTrue].value)) return true;
  if (selectedActivities.includes(ITEMS[keyWhenFalse].value)) return false;
  return undefined;
};

export default {
  defaultValues: [ITEMS.STILL_DETECTED.value],
  transformFilters: (filters) => {
    const showAiResolutionFilter = gon?.abilities?.resolveVulnerabilityWithAi;

    return {
      hasResolution: setSelectedStatus('NO_LONGER_DETECTED', 'STILL_DETECTED', filters),
      hasIssues: setSelectedStatus('HAS_ISSUE', 'DOES_NOT_HAVE_ISSUE', filters),
      hasMergeRequest: setSelectedStatus(
        'HAS_MERGE_REQUEST',
        'DOES_NOT_HAVE_MERGE_REQUEST',
        filters,
      ),
      hasRemediations: setSelectedStatus('HAS_SOLUTION', 'DOES_NOT_HAVE_SOLUTION', filters),
      ...(showAiResolutionFilter
        ? {
            hasAiResolution: setSelectedStatus(
              'AI_RESOLUTION_AVAILABLE',
              'AI_RESOLUTION_UNAVAILABLE',
            ),
          }
        : {}),
    };
  },
  components: {
    GlBadge,
    GlFilteredSearchToken,
    GlDropdownDivider,
    GlDropdownSectionHeader,
    SearchSuggestion,
  },
  mixins: [glAbilitiesMixin(), glFeatureFlagsMixin()],
  props: {
    config: {
      type: Object,
      required: true,
    },
    // contains the token, with the selected operand (e.g.: '=') and the data (comma separated, e.g.: 'MIT, GNU')
    value: {
      type: Object,
      required: true,
    },
    active: {
      type: Boolean,
      required: true,
    },
  },
  data() {
    // Default values are set on page load by parent component, when there is no query parameter.
    // Subsequent token mounts should use the ALL value because clearing tokens should reset to
    // ALL value and not default values.
    const defaultSelected = this.value.data || [ALL_ACTIVITY_VALUE];

    return {
      selectedActivities: defaultSelected,
    };
  },
  computed: {
    tokenValue() {
      return {
        ...this.value,
        // when the token is active (dropdown is open), we set the value to null to prevent an UX issue
        // in which only the last selected item is being displayed.
        // more information: https://gitlab.com/gitlab-org/gitlab-services/design.gitlab.com/-/issues/2467
        data: this.active ? null : this.selectedActivities,
      };
    },
    toggleText() {
      return getSelectedOptionsText({
        options: Object.values(ITEMS),
        selected: this.selectedActivities,
        placeholder: this.$options.i18n.allItemsText,
        maxOptionsShown: 2,
      });
    },
    showAiResolutionFilter() {
      return this.glAbilities.resolveVulnerabilityWithAi;
    },
    activityTokenGroups() {
      return [
        ...GROUPS,
        ...(this.showAiResolutionFilter
          ? [
              {
                text: s__('SecurityReports|GitLab Duo (AI)'),
                options: [ITEMS.AI_RESOLUTION_AVAILABLE, ITEMS.AI_RESOLUTION_UNAVAILABLE],
                icon: 'tanuki-ai',
                variant: 'info',
              },
            ]
          : []),
      ];
    },
  },
  methods: {
    resetSelected() {
      this.selectedActivities = [];
    },
    getGroupFromItem(value) {
      return this.activityTokenGroups.find((group) =>
        group.options.map((option) => option.value).includes(value),
      );
    },
    toggleSelected(selectedValue) {
      const allActivitiesSelected = selectedValue === ALL_ACTIVITY_VALUE;

      if (allActivitiesSelected) {
        this.selectedActivities = [ALL_ACTIVITY_VALUE];
        return;
      }

      const withoutSelectedValue = without(this.selectedActivities, selectedValue);
      const isSelecting = !this.selectedActivities.includes(selectedValue);
      // If a new item is selected, clear other selected items from the same group, clear all option and select the new item.
      if (isSelecting) {
        const group = this.getGroupFromItem(selectedValue);
        const groupItemValues = group.options.map((option) => option.value);
        this.selectedActivities = without(
          this.selectedActivities,
          ...groupItemValues,
          ALL_ACTIVITY_VALUE,
        ).concat(selectedValue);
      }
      // Otherwise, check whether selectedActivities would be empty and set based on that.
      else if (withoutSelectedValue.length === 0) {
        this.selectedActivities = [ALL_ACTIVITY_VALUE];
      } else {
        this.selectedActivities = withoutSelectedValue;
      }
    },

    isActivitySelected(name) {
      return this.selectedActivities.includes(name);
    },
  },
  i18n: {
    label: s__('SecurityReports|Activity'),
    allItemsText: s__('SecurityReports|All activity'),
  },
};
</script>

<template>
  <gl-filtered-search-token
    :config="config"
    v-bind="{ ...$props, ...$attrs }"
    :multi-select-values="selectedActivities"
    :value="tokenValue"
    v-on="$listeners"
    @select="toggleSelected"
    @destroy="resetSelected"
  >
    <template #view>
      <span data-testid="activity-token-placeholder">{{ toggleText }}</span>
    </template>
    <template #suggestions>
      <template v-for="(group, index) in activityTokenGroups">
        <gl-dropdown-section-header v-if="group.text" :key="group.text">
          <div
            v-if="group.icon"
            class="gl-flex gl-items-center gl-justify-center"
            :data-testid="`header-${group.text}`"
          >
            <div class="gl-grow">{{ group.text }}</div>
            <gl-badge :icon="group.icon" :variant="group.variant" />
          </div>
        </gl-dropdown-section-header>
        <search-suggestion
          v-for="activity in group.options"
          :key="activity.value"
          :text="activity.text"
          :value="activity.value"
          :selected="isActivitySelected(activity.value)"
          :data-testid="`suggestion-${activity.value}`"
        />
        <gl-dropdown-divider
          v-if="index < activityTokenGroups.length - 1"
          :key="`${group.text}-divider`"
        />
      </template>
    </template>
  </gl-filtered-search-token>
</template>
