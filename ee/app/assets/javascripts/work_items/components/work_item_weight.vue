<script>
import { GlButton, GlFormGroup, GlFormInput, GlTooltipDirective } from '@gitlab/ui';
import { isPositiveInteger } from '~/lib/utils/number_utils';
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import Tracking from '~/tracking';
import {
  I18N_WORK_ITEM_ERROR_UPDATING,
  NAME_TO_TEXT_LOWERCASE_MAP,
  TRACKING_CATEGORY_SHOW,
} from '~/work_items/constants';
import updateWorkItemMutation from '~/work_items/graphql/update_work_item.mutation.graphql';
import { newWorkItemId } from '~/work_items/utils';
import WorkItemSidebarWidget from '~/work_items/components/shared/work_item_sidebar_widget.vue';
import { sprintf } from '~/locale';

export default {
  directives: {
    GlTooltip: GlTooltipDirective,
  },
  components: {
    GlButton,
    GlFormGroup,
    GlFormInput,
    WorkItemSidebarWidget,
  },
  mixins: [Tracking.mixin()],
  inject: ['hasIssueWeightsFeature'],
  props: {
    canUpdate: {
      type: Boolean,
      required: false,
      default: false,
    },
    fullPath: {
      type: String,
      required: true,
    },
    widget: {
      type: Object,
      required: true,
    },
    workItemId: {
      type: String,
      required: true,
    },
    workItemType: {
      type: String,
      required: true,
    },
  },
  data() {
    return {
      localWeight: this.widget.weight,
      isUpdating: false,
    };
  },
  computed: {
    weight() {
      return this.widget.weight;
    },
    hasWeight() {
      return this.weight !== null;
    },
    showRemoveWeight() {
      return this.hasWeight && !this.isUpdating;
    },
    // eslint-disable-next-line vue/no-unused-properties
    tracking() {
      return {
        category: TRACKING_CATEGORY_SHOW,
        label: 'item_weight',
        property: `type_${this.workItemType}`,
      };
    },
    createFlow() {
      return this.workItemId === newWorkItemId(this.workItemType);
    },
    isWorkItemWidgetAvailable() {
      // `editable` means if it is available for that work item type (not related to user permission)
      return this.widget?.widgetDefinition?.editable;
    },
    displayWeightWidget() {
      return this.hasIssueWeightsFeature && this.isWorkItemWidgetAvailable;
    },
  },
  methods: {
    cancelEditing(stopEditing) {
      this.resetWeight();
      stopEditing();
    },
    clearWeight(stopEditing) {
      this.localWeight = '';
      stopEditing();
      this.updateWeight();
    },
    resetWeight() {
      this.localWeight = this.weight;
    },
    updateWeight() {
      if (!this.canUpdate) {
        return;
      }

      const newWeight = isPositiveInteger(this.localWeight) ? Number(this.localWeight) : null;

      if (this.weight === newWeight) {
        this.resetWeight();
        return;
      }

      this.isUpdating = true;

      this.track('updated_weight');

      if (this.createFlow) {
        this.$emit('updateWidgetDraft', {
          workItemType: this.workItemType,
          fullPath: this.fullPath,
          weight: newWeight,
        });
        this.isUpdating = false;
        return;
      }

      this.$apollo
        .mutate({
          mutation: updateWorkItemMutation,
          variables: {
            input: {
              id: this.workItemId,
              weightWidget: {
                weight: newWeight,
              },
            },
          },
        })
        .then(({ data }) => {
          if (data.workItemUpdate.errors.length) {
            throw new Error(data.workItemUpdate.errors.join('\n'));
          }
        })
        .catch((error) => {
          this.resetWeight();
          this.$emit(
            'error',
            sprintf(I18N_WORK_ITEM_ERROR_UPDATING, {
              workItemType: NAME_TO_TEXT_LOWERCASE_MAP[this.workItemType],
            }),
          );
          Sentry.captureException(error);
        })
        .finally(() => {
          this.isUpdating = false;
        });
    },
  },
};
</script>

<template>
  <work-item-sidebar-widget
    v-if="displayWeightWidget"
    :can-update="canUpdate"
    :is-updating="isUpdating"
    data-testid="work-item-weight"
    @stopEditing="updateWeight"
  >
    <template #title>
      {{ __('Weight') }}
    </template>
    <template #content>
      <template v-if="hasWeight">
        {{ weight }}
      </template>
      <span v-else class="gl-text-subtle">
        {{ __('None') }}
      </span>
    </template>
    <template #editing-content="{ stopEditing }">
      <div class="gl-relative gl-px-2">
        <gl-form-group :label="__('Weight')" label-for="weight-widget-input" label-sr-only>
          <gl-form-input
            id="weight-widget-input"
            v-model="localWeight"
            autofocus
            min="0"
            :placeholder="__('Enter a number')"
            type="number"
            @keydown.enter="stopEditing"
            @keydown.exact.esc.stop="cancelEditing(stopEditing)"
          />
        </gl-form-group>
        <gl-button
          v-if="showRemoveWeight"
          v-gl-tooltip
          class="gl-absolute gl-right-7 gl-top-2"
          category="tertiary"
          icon="clear"
          size="small"
          :title="__('Remove weight')"
          :aria-label="__('Remove weight')"
          data-testid="remove-weight"
          @click="clearWeight(stopEditing)"
        />
      </div>
    </template>
  </work-item-sidebar-widget>
</template>
