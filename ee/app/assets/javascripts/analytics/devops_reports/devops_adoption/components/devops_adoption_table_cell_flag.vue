<script>
import { GlTooltipDirective, GlIcon } from '@gitlab/ui';
import { __, sprintf } from '~/locale';
import { I18N_CELL_FLAG_TRUE_TEXT, I18N_CELL_FLAG_FALSE_TEXT } from '../constants';

export default {
  name: 'DevopsAdoptionTableCellFlag',
  components: {
    GlIcon,
  },
  directives: {
    GlTooltip: GlTooltipDirective,
  },
  props: {
    enabled: {
      type: Boolean,
      required: true,
    },
    withText: {
      type: Boolean,
      required: false,
      default: false,
    },
    name: {
      type: String,
      required: true,
    },
  },
  computed: {
    tooltipText() {
      return this.enabled ? I18N_CELL_FLAG_TRUE_TEXT : I18N_CELL_FLAG_FALSE_TEXT;
    },
    iconAltText() {
      if (this.enabled) return sprintf(__('%{name} checked'), { name: this.name });
      return sprintf(__('%{name} not checked'), { name: this.name });
    },
  },
};
</script>
<template>
  <div>
    <div v-if="enabled" class="gl-flex gl-justify-end sm:gl-justify-start">
      <gl-icon
        name="status_success_solid"
        variant="success"
        :class="{ 'gl-mr-3': withText }"
        :alt="iconAltText"
      />
      <div v-if="withText">{{ __('Adopted') }}</div>
    </div>
    <div v-if="!enabled" class="gl-flex gl-justify-end sm:gl-justify-start">
      <gl-icon
        name="issue-open-m"
        :class="{ 'gl-mr-3': withText }"
        variant="subtle"
        :alt="iconAltText"
      />
      <div v-if="withText">{{ __('Not adopted') }}</div>
    </div>
  </div>
</template>
