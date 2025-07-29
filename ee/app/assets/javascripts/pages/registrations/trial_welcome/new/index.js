import { initSimpleApp } from '~/helpers/init_simple_app_helper';
import apolloProvider from 'ee/subscriptions/graphql/graphql';
import CreateTrialWelcomeForm from 'ee/trials/components/create_trial_welcome_form.vue';

initSimpleApp('#js-create-trial-welcome-form', CreateTrialWelcomeForm, {
  withApolloProvider: apolloProvider,
});
