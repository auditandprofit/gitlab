import { s__ } from '~/locale';
import { humanize } from '~/lib/utils/text_utility';

export const formatAgentDefinition = (agentDefinition) => {
  return humanize(agentDefinition || s__('DuoAgentsPlatform|Agent session'));
};

export const formatAgentFlowName = (agentDefinition, id) => {
  return `${formatAgentDefinition(agentDefinition)} #${id}`;
};

export const formatAgentStatus = (status) => {
  return status ? humanize(status.toLowerCase()) : s__('DuoAgentsPlatform|Unknown');
};
