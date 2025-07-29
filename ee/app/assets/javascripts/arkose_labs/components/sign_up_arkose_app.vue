<script>
import { uniqueId } from 'lodash';
import { logError } from '~/lib/logger';
import { createAlert } from '~/alert';
import DomElementListener from '~/vue_shared/components/dom_element_listener.vue';
import { initArkoseLabsChallenge } from '../init_arkose_labs';
import {
  VERIFICATION_LOADING_MESSAGE,
  VERIFICATION_REQUIRED_MESSAGE,
  VERIFICATION_TOKEN_INPUT_NAME,
  CHALLENGE_CONTAINER_CLASS,
} from '../constants';

export default {
  name: 'SignUpArkoseApp',
  components: {
    DomElementListener,
  },
  props: {
    formSelector: {
      type: String,
      required: true,
    },
    publicKey: {
      type: String,
      required: true,
    },
    domain: {
      type: String,
      required: true,
    },
    dataExchangePayload: {
      type: String,
      required: false,
      default: undefined,
    },
    isLWRExperimentCandidate: {
      type: Boolean,
      required: false,
      default: false,
    },
  },
  data() {
    return {
      arkoseLabsIframeShown: false,
      arkoseLabsContainerClass: uniqueId(CHALLENGE_CONTAINER_CLASS),
      arkoseToken: '',
      errorAlert: null,
      arkoseChallengeBypassed: false,
    };
  },
  async mounted() {
    try {
      await initArkoseLabsChallenge({
        publicKey: this.publicKey,
        domain: this.domain,
        dataExchangePayload: this.dataExchangePayload,
        config: {
          selector: `.${this.arkoseLabsContainerClass}`,
          onShown: this.onArkoseLabsIframeShown,
          onCompleted: this.passArkoseLabsChallenge,
          onError: this.bypassArkoseOnFailure,
          styleTheme: this.isLWRExperimentCandidate ? 'dark' : null,
        },
      });
    } catch (error) {
      this.bypassArkoseOnFailure(error);
    }
  },
  methods: {
    showVerificationError() {
      let message = VERIFICATION_LOADING_MESSAGE;

      if (this.arkoseLabsIframeShown) {
        message = VERIFICATION_REQUIRED_MESSAGE;
      }

      this.errorAlert = createAlert({ message });
      window.scrollTo({ top: 0 });
    },
    onArkoseLabsIframeShown() {
      this.arkoseLabsIframeShown = true;
    },
    passArkoseLabsChallenge(response) {
      this.arkoseToken = response.token;
    },
    bypassArkoseOnFailure(error) {
      logError('ArkoseLabs initialization error', error);

      this.arkoseChallengeBypassed = true;
    },
    onSubmit(e) {
      this.errorAlert?.dismiss();

      if (this.arkoseChallengeBypassed) {
        return;
      }

      if (!this.arkoseToken) {
        this.showVerificationError();

        e.preventDefault();
        e.stopPropagation();
      }
    },
  },
  VERIFICATION_LOADING_MESSAGE,
  VERIFICATION_REQUIRED_MESSAGE,
  VERIFICATION_TOKEN_INPUT_NAME,
};
</script>

<template>
  <div>
    <dom-element-listener :selector="formSelector" @submit="onSubmit" />
    <input
      v-model="arkoseToken"
      :name="$options.VERIFICATION_TOKEN_INPUT_NAME"
      type="hidden"
      data-testid="arkose-labs-token-input"
    />
    <div
      v-show="arkoseLabsIframeShown"
      class="gl-flex gl-justify-center"
      :class="arkoseLabsContainerClass"
      data-testid="arkose-labs-challenge"
    ></div>
  </div>
</template>
