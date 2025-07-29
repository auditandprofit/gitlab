<script>
import { GlForm, GlFormGroup, GlFormInput, GlFormTextarea, GlButton } from '@gitlab/ui';
import { __, s__ } from '~/locale';
import { isValidURL } from '~/lib/utils/url_utility';

export default {
  name: 'RegistryUpstreamForm',
  components: {
    GlForm,
    GlFormGroup,
    GlFormInput,
    GlFormTextarea,
    GlButton,
  },
  inject: {
    registryPath: {
      default: '',
    },
  },
  props: {
    loading: {
      type: Boolean,
      required: false,
      default: false,
    },
    upstream: {
      type: Object,
      required: false,
      default: () => ({}),
    },
    /**
     * Whether the upstream can be tested
     */
    canTestUpstream: {
      type: Boolean,
      required: false,
      default: false,
    },
  },
  i18n: {
    nameLabel: s__('VirtualRegistry|Name'),
    upstreamUrlLabel: s__('VirtualRegistry|Upstream URL'),
    descriptionLabel: s__('VirtualRegistry|Description (optional)'),
    usernameLabel: s__('VirtualRegistry|Username (optional)'),
    passwordLabel: s__('VirtualRegistry|Password (optional)'),
    passwordPlaceholder: s__('VirtualRegistry|Enter password'),
    cacheValidityHoursLabel: s__('VirtualRegistry|Caching period'),
    cacheValidityHoursHelpText: s__('VirtualRegistry|Time in hours'),
    createUpstreamButtonLabel: s__('VirtualRegistry|Create upstream'),
    testUpstreamButtonLabel: s__('VirtualRegistry|Test upstream'),
    invalidUrl: s__('VirtualRegistry|Please provide a valid URL.'),
    cancelButtonLabel: __('Cancel'),
  },
  /**
   * @event submit - Emitted when the form is submitted
   * @property {Object} form - The form data
   */
  /**
   * @event testUpstream - Emitted when the "Test upstream" button is clicked
   * @property {Object} form - The form data
   */
  /**
   * @event cancel - Emitted when the "Cancel" button is clicked
   */
  emits: ['submit', 'testUpstream', 'cancel'],
  data() {
    return {
      form: {
        name: this.upstream.name ? this.upstream.name : '',
        url: this.upstream.url ? this.upstream.url : '',
        description: this.upstream.description ? this.upstream.description : '',
        username: this.upstream.username ? this.upstream.username : '',
        password: '',
        cacheValidityHours: this.upstream.cacheValidityHours
          ? this.upstream.cacheValidityHours
          : 24,
      },
      showValidation: false,
    };
  },
  ids: {
    nameInputId: 'name-input',
    upstreamUrlInputId: 'upstream-url-input',
    descriptionInputId: 'description-input',
    usernameInputId: 'username-input',
    passwordInputId: 'password-input',
    cacheValidityHoursInputId: 'cache-validity-hours-input',
  },
  computed: {
    isValidURL() {
      return isValidURL(this.form.url);
    },
    isValidUrlState() {
      return this.showValidation ? this.isValidURL : true;
    },
    saveButtonText() {
      return this.upstream.id ? __('Save changes') : this.$options.i18n.createUpstreamButtonLabel;
    },
  },
  methods: {
    submit() {
      this.showValidation = true;

      if (this.isValidURL) {
        this.$emit('submit', this.form);
      }
    },
    testUpstream() {
      this.showValidation = true;

      if (this.isValidURL) {
        this.$emit('testUpstream', this.form);
      }
    },
    cancel() {
      this.$emit('cancel');
    },
  },
};
</script>
<template>
  <gl-form @submit.prevent="submit">
    <gl-form-group :label="$options.i18n.nameLabel" :label-for="$options.ids.nameInputId">
      <gl-form-input
        :id="$options.ids.nameInputId"
        v-model="form.name"
        data-testid="name-input"
        required
        autofocus
      />
    </gl-form-group>
    <gl-form-group
      :label="$options.i18n.upstreamUrlLabel"
      :label-for="$options.ids.upstreamUrlInputId"
      :invalid-feedback="$options.i18n.invalidUrl"
      :state="isValidUrlState"
    >
      <gl-form-input
        :id="$options.ids.upstreamUrlInputId"
        v-model="form.url"
        type="url"
        data-testid="upstream-url-input"
        required
      />
    </gl-form-group>
    <gl-form-group
      :label="$options.i18n.descriptionLabel"
      :label-for="$options.ids.descriptionInputId"
    >
      <gl-form-textarea
        :id="$options.ids.descriptionInputId"
        v-model="form.description"
        data-testid="description-input"
      />
    </gl-form-group>
    <gl-form-group :label="$options.i18n.usernameLabel" :label-for="$options.ids.usernameInputId">
      <gl-form-input
        :id="$options.ids.usernameInputId"
        v-model="form.username"
        data-testid="username-input"
      />
    </gl-form-group>
    <gl-form-group :label="$options.i18n.passwordLabel" :label-for="$options.ids.passwordInputId">
      <gl-form-input
        :id="$options.ids.passwordInputId"
        v-model="form.password"
        data-testid="password-input"
        type="password"
      />
    </gl-form-group>
    <gl-form-group
      :label="$options.i18n.cacheValidityHoursLabel"
      :label-for="$options.ids.cacheValidityHoursInputId"
      :label-description="$options.i18n.cacheValidityHoursHelpText"
    >
      <gl-form-input
        :id="$options.ids.cacheValidityHoursInputId"
        v-model="form.cacheValidityHours"
        data-testid="cache-validity-hours-input"
        class="gl-max-w-15"
        type="number"
        number
        :min="0"
      />
    </gl-form-group>
    <div class="gl-flex gl-gap-3">
      <gl-button
        data-testid="submit-button"
        class="js-no-auto-disable"
        variant="confirm"
        category="primary"
        type="submit"
        :loading="loading"
      >
        {{ saveButtonText }}
      </gl-button>
      <gl-button
        :href="registryPath"
        data-testid="cancel-button"
        category="secondary"
        @click="cancel"
      >
        {{ $options.i18n.cancelButtonLabel }}
      </gl-button>
      <gl-button
        v-if="canTestUpstream"
        data-testid="test-upstream-button"
        variant="confirm"
        category="tertiary"
        @click="testUpstream"
      >
        {{ $options.i18n.testUpstreamButtonLabel }}
      </gl-button>
    </div>
  </gl-form>
</template>
