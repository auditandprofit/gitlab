import Vue from 'vue';
import VueRouter from 'vue-router';
import { __, s__ } from '~/locale';
import { DETAILS_ROUTE_NAME, EDIT_ROUTE_NAME, INDEX_ROUTE_NAME, NEW_ROUTE_NAME } from './constants';
import SecretDetailsWrapper from './components/secret_details/secret_details_wrapper.vue';
import SecretFormWrapper from './components/secret_form/secret_form_wrapper.vue';
import SecretsTable from './components/secrets_table/secrets_table.vue';

Vue.use(VueRouter);

export default (base, props) => {
  const { fullPath, entity } = props;

  const router = new VueRouter({
    base,
    routes: [
      {
        name: INDEX_ROUTE_NAME,
        path: '/',
        component: SecretsTable,
        props: () => {
          return { fullPath };
        },
        meta: {
          getBreadcrumbText: () => s__('Secrets|Secrets'),
          isRoot: true,
        },
      },
      {
        name: NEW_ROUTE_NAME,
        path: '/new',
        component: SecretFormWrapper,
        props: () => {
          return { entity, fullPath };
        },
        meta: {
          getBreadcrumbText: () => s__('Secrets|New secret'),
        },
      },
      {
        name: DETAILS_ROUTE_NAME,
        path: '/:secretName/details',
        component: SecretDetailsWrapper,
        props: ({ params: { secretName }, name }) => {
          return { fullPath, secretName, routeName: name };
        },
        meta: {
          getBreadcrumbText: ({ id }) => id,
          isDetails: true,
        },
      },
      {
        name: EDIT_ROUTE_NAME,
        path: '/:secretName/edit',
        component: SecretFormWrapper,
        props: ({ params: { secretName } }) => {
          return {
            entity,
            fullPath,
            isEditing: true,
            secretName,
          };
        },
        meta: {
          getBreadcrumbText: () => __('Edit'),
        },
      },
      {
        path: '/:id',
        redirect: '/:id/details',
      },
      {
        path: '*',
        redirect: '/',
      },
    ],
  });

  return router;
};
