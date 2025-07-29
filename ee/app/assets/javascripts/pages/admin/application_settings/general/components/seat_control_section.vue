<script>
import { GlFormGroup, GlFormRadio, GlFormRadioGroup, GlFormInput, GlSprintf } from '@gitlab/ui';
import HelpPageLink from '~/vue_shared/components/help_page_link/help_page_link.vue';
import glLicensedFeaturesMixin from '~/vue_shared/mixins/gl_licensed_feature_mixin';
import { SEAT_CONTROL } from 'ee/pages/admin/application_settings/general/constants';
import BeforeSubmitUserCapOverLicensedUsersModal from 'ee_component/pages/admin/application_settings/general/components/before_submit_user_cap_over_licensed_users_modal.vue';
import SeatControlMemberPromotionManagement from 'ee_component/pages/admin/application_settings/general/components/seat_control_member_promotion_management.vue';

export default {
  name: 'SeatControlsSection',
  components: {
    BeforeSubmitUserCapOverLicensedUsersModal,
    GlFormGroup,
    GlFormRadio,
    GlFormRadioGroup,
    GlFormInput,
    GlSprintf,
    HelpPageLink,
    SeatControlMemberPromotionManagement,
  },
  mixins: [glLicensedFeaturesMixin()],
  provide() {
    return {
      beforeSubmitHookContexts: {
        [this.userCapOverLicensedUsersModalId]: {
          shouldPreventSubmit: () => this.shouldShowUserCapModal,
        },
      },
    };
  },
  inject: [
    'licensedUserCount',
    'newUserSignupsCap',
    'pendingUserCount',
    'promotionManagementAvailable',
    'seatControl',
  ],
  data() {
    return {
      newUserCapValue: this.newUserSignupsCap,
      newSeatControlSettings: parseInt(this.seatControl, 10),
    };
  },
  computed: {
    hasChangedFromUserCapToOpenAccess() {
      if (!this.isOpenAccessEnabled) return false;
      return this.initialSeatControlSettings === SEAT_CONTROL.USER_CAP;
    },
    hasUserCapBeenIncreased() {
      if (!this.isUserCapEnabled) return false;
      if (this.hasUserCapChangedFromUnlimitedToLimited) return false;
      if (this.hasUserCapChangedFromLimitedToUnlimited) return true;

      const oldValueAsInteger = parseInt(this.initialUserCapValue, 10);
      const newValueAsInteger = this.parsedNewUserCapValue;

      return newValueAsInteger > oldValueAsInteger;
    },
    hasUserCapChangedFromLimitedToUnlimited() {
      return !this.isInitialUserCapUnlimited && this.isNewUserCapUnlimited;
    },
    hasUserCapChangedFromUnlimitedToLimited() {
      return this.isInitialUserCapUnlimited && !this.isNewUserCapUnlimited;
    },
    initialUserCapValue() {
      return this.newUserSignupsCap;
    },
    isBlockOveragesEnabled() {
      return this.newSeatControlSettings === SEAT_CONTROL.BLOCK_OVERAGES;
    },
    isNewUserCapUnlimited() {
      // The current value of User Cap is unlimited if no value is provided in the field
      return this.newUserCapValue === '';
    },
    isInitialUserCapUnlimited() {
      // The previous/initial value of User Cap is unlimited if it was empty
      return this.initialUserCapValue === '';
    },
    isOpenAccessEnabled() {
      return this.newSeatControlSettings === SEAT_CONTROL.OFF;
    },
    isUserCapEnabled() {
      return this.newSeatControlSettings === SEAT_CONTROL.USER_CAP;
    },
    isUserCapOverLicensedUsers() {
      return this.parsedNewUserCapValue > this.parsedLicensedUserCount;
    },
    parsedNewUserCapValue() {
      return parseInt(this.newUserCapValue, 10);
    },
    parsedLicensedUserCount() {
      return parseInt(this.licensedUserCount, 10);
    },
    initialSeatControlSettings() {
      return parseInt(this.seatControl, 10);
    },
    userCapOverLicensedUsersModalId() {
      return 'before-submit-user-cap-over-licensed-users-modal';
    },
    shouldShowSeatControlSection() {
      return Boolean(this.glLicensedFeatures.seatControl);
    },
    shouldShowUserCapModal() {
      if (this.pendingUserCount > 0) return false;
      if (!this.licensedUserCount) return false;
      if (!this.parsedNewUserCapValue) return false;
      return this.isUserCapOverLicensedUsers;
    },
    shouldVerifyUsersAutoApproval() {
      if (this.isBlockOveragesEnabled) return false;
      if (this.hasChangedFromUserCapToOpenAccess) return true;
      return this.hasUserCapBeenIncreased;
    },
  },
  methods: {
    handleSeatControlSettingsChange(newSeatControlSettings) {
      this.newSeatControlSettings = parseInt(newSeatControlSettings, 10);
      this.newUserCapValue = this.isUserCapEnabled ? this.newUserCapValue : '';
      this.$emit('checkUsersAutoApproval', this.shouldVerifyUsersAutoApproval);
    },
    handleUserCapChange(newUserCapValue) {
      this.newUserCapValue = newUserCapValue;
      this.$emit('checkUsersAutoApproval', this.shouldVerifyUsersAutoApproval);
    },
  },
  SEAT_CONTROL,
};
</script>

<template>
  <div v-if="shouldShowSeatControlSection">
    <gl-form-group :label="s__('ApplicationSettings|Seat control')">
      <gl-form-radio-group
        :checked="initialSeatControlSettings"
        name="application_setting[seat_control]"
        @change="handleSeatControlSettingsChange"
      >
        <gl-form-radio
          :value="$options.SEAT_CONTROL.BLOCK_OVERAGES"
          data-testid="seat-control-restricted-access"
        >
          {{ s__('ApplicationSettings|Restricted access') }}
          <template #help>{{
            s__(
              'ApplicationSettings|Prevent the billable user count from exceeding the number of seats in the license.',
            )
          }}</template>
        </gl-form-radio>

        <gl-form-radio :value="$options.SEAT_CONTROL.USER_CAP" data-testid="seat-control-user-cap">
          {{ s__('ApplicationSettings|Controlled access') }}
          <template #help
            >{{
              s__(
                'ApplicationSettings|Administrator approval required for new users. Set a user cap for the maximum number of users who can be added without administrator approval.',
              )
            }}
          </template>
        </gl-form-radio>

        <div class="gl-ml-6 gl-mt-3">
          <gl-form-group
            id="user-cap-input-group"
            data-testid="user-cap-group"
            :label="__('Set user cap')"
            label-for="user-cap-input"
            label-sr-only
          >
            <gl-form-input
              id="user-cap-input"
              v-model="newUserCapValue"
              type="text"
              name="application_setting[new_user_signups_cap]"
              data-testid="user-cap-input"
              :disabled="!isUserCapEnabled"
              @input="handleUserCapChange"
            />
            <input
              type="hidden"
              name="application_setting[new_user_signups_cap]"
              data-testid="user-cap-input-hidden"
              :disabled="isUserCapEnabled"
              :value="newUserCapValue"
            />
            <small class="form-text text-muted">
              {{
                s__(
                  'ApplicationSettings|Users added beyond this limit require administrator approval. Leave blank for unlimited.',
                )
              }}
              <gl-sprintf
                v-if="licensedUserCount"
                :message="
                  s__(
                    'ApplicationSettings|A user cap that exceeds the current licensed user count (%{licensedUserCount}) may result in %{linkStart}seat overages%{linkEnd}.',
                  )
                "
                ><template #licensedUserCount>{{ licensedUserCount }}</template>
                <template #link="{ content }">
                  <help-page-link
                    href="subscriptions/quarterly_reconciliation"
                    anchor="quarterly-reconciliation-versus-annual-true-ups"
                    >{{ content }}</help-page-link
                  >
                </template>
              </gl-sprintf>
            </small>
          </gl-form-group>
        </div>

        <gl-form-radio :value="$options.SEAT_CONTROL.OFF" data-testid="seat-control-open-access">
          {{ s__('ApplicationSettings|Open access') }}
          <template #help
            >{{ s__('ApplicationSettings|Administrator approval not required for new users.') }}
          </template>
        </gl-form-radio>
      </gl-form-radio-group>
    </gl-form-group>

    <gl-form-group
      v-if="promotionManagementAvailable"
      :label="s__('ApplicationSettings|Role Promotions')"
    >
      <seat-control-member-promotion-management />
    </gl-form-group>

    <before-submit-user-cap-over-licensed-users-modal
      :id="userCapOverLicensedUsersModalId"
      :licensed-user-count="parsedLicensedUserCount"
      :user-cap="parsedNewUserCapValue"
      @primary="$emit('submit')"
    />
  </div>
</template>
