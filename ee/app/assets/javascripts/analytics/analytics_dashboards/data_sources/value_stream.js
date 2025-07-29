import { s__, sprintf } from '~/locale';
import { convertObjectPropsToCamelCase } from '~/lib/utils/common_utils';

const I18N_VSD_DORA_METRICS_PANEL_TITLE = s__('DORA4Metrics|Metrics comparison for %{name}');

const generatePanelTitle = ({ namespace: { name } }) => {
  return sprintf(I18N_VSD_DORA_METRICS_PANEL_TITLE, { name });
};

export default async function fetch({ title, namespace, query, queryOverrides = {} }) {
  return convertObjectPropsToCamelCase(
    {
      namespace,
      title: title || generatePanelTitle({ namespace }),
      ...query,
      ...queryOverrides,
    },
    { deep: true },
  );
}
