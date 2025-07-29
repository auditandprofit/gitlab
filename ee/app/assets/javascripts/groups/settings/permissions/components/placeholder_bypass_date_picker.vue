<script>
import { GlDatepicker, GlFormGroup } from '@gitlab/ui';

export default {
  name: 'PlaceholderBypassDatePicker',
  components: {
    GlDatepicker,
    GlFormGroup,
  },
  props: {
    minDate: {
      type: Date,
      required: true,
    },
    currentExpiryDate: {
      type: String,
      required: false,
      default: '',
    },
    inputName: {
      type: String,
      required: true,
    },
    disabled: {
      type: Boolean,
      required: false,
      default: true,
    },
  },
  data() {
    return {
      selectedDate: this.currentExpiryDate ? new Date(this.currentExpiryDate) : null,
    };
  },
};
</script>

<template>
  <div class="gl-mt-4">
    <gl-form-group :label="__('Expiry date')" :label-for="inputName">
      <gl-datepicker
        :id="inputName"
        v-model="selectedDate"
        :min-date="minDate"
        :input-name="inputName"
        show-clear-button
        data-testid="placeholder-bypass-expiry-date-field"
        :disabled="disabled"
      />
    </gl-form-group>
  </div>
</template>
