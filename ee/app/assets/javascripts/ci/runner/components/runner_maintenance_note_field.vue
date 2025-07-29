<script>
import { GlFormGroup, GlFormTextarea } from '@gitlab/ui';
import glFeatureFlagMixin from '~/vue_shared/mixins/gl_feature_flags_mixin';

export default {
  components: {
    GlFormGroup,
    GlFormTextarea,
  },
  mixins: [glFeatureFlagMixin()],
  inheritAttrs: false,
  computed: {
    hasFeature() {
      const { runnerMaintenanceNote, runnerMaintenanceNoteForNamespace } = this.glFeatures;
      return runnerMaintenanceNote || runnerMaintenanceNoteForNamespace;
    },
    shouldRender() {
      return this.hasFeature;
    },
  },
};
</script>
<template>
  <gl-form-group
    v-if="shouldRender"
    data-testid="runner-field-maintenance-note"
    :label="s__('Runners|Maintenance note')"
    label-for="runner-maintenance-note"
    :description="
      s__(
        'Runners|Add notes such as the runner owner or what it should be used for. Users with runner update permissions see this note.',
      )
    "
  >
    <gl-form-textarea
      id="runner-maintenance-note"
      :no-resize="false"
      name="maintenance-note"
      v-bind="$attrs"
      v-on="$listeners"
    />
  </gl-form-group>
</template>
