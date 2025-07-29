<script>
import { GlIcon, GlLabel, GlTooltipDirective } from '@gitlab/ui';
import { __ } from '~/locale';
import { localeDateFormat } from '~/lib/utils/datetime_utility';
import { convertEnvironmentScope } from '~/ci/common/private/ci_environments_dropdown';
import { SCOPED_LABEL_COLOR } from '../../constants';

export default {
  name: 'SecretDetails',
  components: {
    GlIcon,
    GlLabel,
  },
  directives: {
    GlTooltip: GlTooltipDirective,
  },
  props: {
    fullPath: {
      type: String,
      required: false,
      default: null,
    },
    secret: {
      type: Object,
      required: true,
    },
  },
  computed: {
    createdAtText() {
      return localeDateFormat.asDate.format(new Date(this.secret.createdAt));
    },
    descriptionText() {
      return this.secret.description || __('None');
    },
    environmentLabelText() {
      const { environment } = this.secret;
      const environmentText = convertEnvironmentScope(environment).toLowerCase();
      return `${__('env')}::${environmentText}`;
    },
  },
  SCOPED_LABEL_COLOR,
};
</script>
<template>
  <div class="gl-mt-4">
    <div class="gl-flex">
      <b class="gl-basis-1/4">{{ __('Description') }}</b>
      <p
        :class="{ 'gl-text-subtle': !secret.description }"
        data-testid="secret-details-description"
      >
        {{ descriptionText }}
      </p>
    </div>
    <div class="gl-mb-4 gl-flex">
      <b class="gl-basis-1/4">{{ __('Environments') }}</b>
      <gl-label
        :title="environmentLabelText"
        :background-color="$options.SCOPED_LABEL_COLOR"
        data-testid="secret-details-environments"
        scoped
      />
    </div>
    <div class="gl-mb-4 gl-flex">
      <b class="gl-basis-1/4">{{ __('Branches') }}</b>
      <code data-testid="secret-details-branches">
        <gl-icon name="branch" :size="12" class="gl-mr-1" />
        {{ secret.branch }}
      </code>
    </div>
  </div>
</template>
