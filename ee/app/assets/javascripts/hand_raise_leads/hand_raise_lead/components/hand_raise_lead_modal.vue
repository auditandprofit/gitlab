<script>
import { GlFormGroup, GlFormInput, GlFormTextarea, GlModal } from '@gitlab/ui';
import * as SubscriptionsApi from 'ee/api/subscriptions_api';
import { createAlert, VARIANT_SUCCESS } from '~/alert';
import { sprintf } from '~/locale';
import Tracking from '~/tracking';
import CountryOrRegionSelector from 'ee/trials/components/country_or_region_selector.vue';
import {
  LEADS_COMPANY_NAME_LABEL,
  LEADS_FIRST_NAME_LABEL,
  LEADS_LAST_NAME_LABEL,
  LEADS_PHONE_NUMBER_LABEL,
} from 'ee/vue_shared/leads/constants';
import { BV_SHOW_MODAL } from '~/lib/utils/constants';
import {
  PQL_COMMENT_LABEL,
  PQL_HAND_RAISE_ACTION_ERROR,
  PQL_HAND_RAISE_ACTION_SUCCESS,
  PQL_HAND_RAISE_MODAL_TRACKING_LABEL,
  PQL_MODAL_CANCEL,
  PQL_MODAL_FOOTER_TEXT,
  PQL_MODAL_HEADER_TEXT,
  PQL_MODAL_ID,
  PQL_MODAL_PRIMARY,
  PQL_MODAL_TITLE,
  PQL_PHONE_DESCRIPTION,
} from '../constants';
import eventHub from '../event_hub';

export default {
  name: 'HandRaiseLeadModal',
  components: {
    GlFormGroup,
    GlFormInput,
    GlFormTextarea,
    GlModal,
    CountryOrRegionSelector,
  },
  mixins: [Tracking.mixin()],
  props: {
    user: {
      type: Object,
      required: true,
    },
    submitPath: {
      type: String,
      required: true,
    },
  },
  data() {
    return {
      firstName: this.user.firstName,
      lastName: this.user.lastName,
      companyName: this.user.companyName,
      phoneNumber: '',
      country: '',
      state: '',
      comment: '',
      stateRequired: false,
      ctaTracking: {},
      glmContent: '',
      productInteraction: '',
    };
  },
  computed: {
    modalHeaderText() {
      return sprintf(this.$options.i18n.modalHeaderText, {
        userName: this.user.userName,
      });
    },
    canSubmit() {
      return (
        this.firstName &&
        this.lastName &&
        this.companyName &&
        this.phoneNumber &&
        this.country &&
        (this.stateRequired ? this.state : true)
      );
    },
    actionPrimary() {
      return {
        text: this.$options.i18n.modalPrimary,
        attributes: {
          variant: 'confirm',
          disabled: !this.canSubmit,
          class: 'gl-w-full sm:gl-w-auto',
        },
      };
    },
    actionCancel() {
      return {
        text: this.$options.i18n.modalCancel,
        attributes: {
          class: 'gl-w-full sm:gl-w-auto',
        },
      };
    },
    // eslint-disable-next-line vue/no-unused-properties -- used by Tracking mixin for analytics tracking
    tracking() {
      return {
        label: PQL_HAND_RAISE_MODAL_TRACKING_LABEL,
        experiment: this.ctaTracking.experiment,
      };
    },
    formParams() {
      return {
        namespaceId: Number(this.user.namespaceId),
        firstName: this.firstName,
        lastName: this.lastName,
        companyName: this.companyName,
        phoneNumber: this.phoneNumber,
        country: this.country,
        state: this.stateRequired ? this.state : null,
        comment: this.comment,
        glmContent: this.glmContent,
        productInteraction: this.productInteraction,
      };
    },
  },
  mounted() {
    eventHub.$on('openModal', (options) => {
      this.openModal(options);
    });
  },
  methods: {
    openModal({ productInteraction, ctaTracking, glmContent }) {
      // The items being passed here are what can be unique about a particular
      // instance of this modal.
      this.productInteraction = productInteraction;
      this.ctaTracking = ctaTracking;
      this.glmContent = glmContent;

      this.$root.$emit(BV_SHOW_MODAL, this.$options.modalId);
      this.track('hand_raise_form_viewed');
    },
    resetForm() {
      this.firstName = '';
      this.lastName = '';
      this.companyName = '';
      this.phoneNumber = '';
      this.country = '';
      this.state = '';
      this.comment = '';
      this.stateRequired = false;
    },
    async submit() {
      await SubscriptionsApi.sendHandRaiseLead(this.submitPath, this.formParams)
        .then(() => {
          createAlert({
            message: this.$options.i18n.handRaiseActionSuccess,
            variant: VARIANT_SUCCESS,
          });
          this.resetForm();
          this.track('hand_raise_submit_form_succeeded');
        })
        .catch((error) => {
          createAlert({
            message: this.$options.i18n.handRaiseActionError,
            captureError: true,
            error,
          });
          this.track('hand_raise_submit_form_failed');
        });
    },
    onChange({ country, state, stateRequired }) {
      this.country = country;
      this.state = state;
      this.stateRequired = stateRequired;
    },
  },
  i18n: {
    firstNameLabel: LEADS_FIRST_NAME_LABEL,
    lastNameLabel: LEADS_LAST_NAME_LABEL,
    companyNameLabel: LEADS_COMPANY_NAME_LABEL,
    phoneNumberLabel: LEADS_PHONE_NUMBER_LABEL,
    phoneNumberDescription: PQL_PHONE_DESCRIPTION,
    commentLabel: PQL_COMMENT_LABEL,
    modalTitle: PQL_MODAL_TITLE,
    modalPrimary: PQL_MODAL_PRIMARY,
    modalCancel: PQL_MODAL_CANCEL,
    modalHeaderText: PQL_MODAL_HEADER_TEXT,
    modalFooterText: PQL_MODAL_FOOTER_TEXT,
    handRaiseActionError: PQL_HAND_RAISE_ACTION_ERROR,
    handRaiseActionSuccess: PQL_HAND_RAISE_ACTION_SUCCESS,
  },
  modalId: PQL_MODAL_ID,
};
</script>

<template>
  <gl-modal
    ref="modal"
    :modal-id="$options.modalId"
    data-testid="hand-raise-lead-modal"
    size="sm"
    :title="$options.i18n.modalTitle"
    :action-primary="actionPrimary"
    :action-cancel="actionCancel"
    @primary="submit"
    @cancel="track('hand_raise_form_canceled')"
  >
    {{ modalHeaderText }}
    <div class="combined gl-mt-5 gl-flex">
      <gl-form-group
        :label="$options.i18n.firstNameLabel"
        label-size="sm"
        label-for="first-name"
        class="mr-3 w-50"
      >
        <gl-form-input
          id="first-name"
          v-model="firstName"
          type="text"
          class="form-control"
          data-testid="first-name"
        />
      </gl-form-group>
      <gl-form-group
        :label="$options.i18n.lastNameLabel"
        label-size="sm"
        label-for="last-name"
        class="w-50"
      >
        <gl-form-input
          id="last-name"
          v-model="lastName"
          type="text"
          class="form-control"
          data-testid="last-name"
        />
      </gl-form-group>
    </div>
    <div class="combined gl-flex">
      <gl-form-group
        :label="$options.i18n.companyNameLabel"
        label-size="sm"
        label-for="company-name"
        class="mr-3 w-50"
      >
        <gl-form-input
          id="company-name"
          v-model="companyName"
          type="text"
          class="form-control"
          data-testid="company-name"
        />
      </gl-form-group>
    </div>
    <gl-form-group
      :label="$options.i18n.phoneNumberLabel"
      label-size="sm"
      :description="$options.i18n.phoneNumberDescription"
      label-for="phone-number"
    >
      <gl-form-input
        id="phone-number"
        v-model="phoneNumber"
        type="text"
        class="form-control"
        data-testid="phone-number"
      />
    </gl-form-group>
    <country-or-region-selector :country="country" :state="state" @change="onChange" />
    <gl-form-group :label="$options.i18n.commentLabel" label-size="sm" label-for="comment">
      <gl-form-textarea v-model="comment" no-resize />
    </gl-form-group>

    <p class="gl-text-subtle">
      {{ $options.i18n.modalFooterText }}
    </p>
  </gl-modal>
</template>
