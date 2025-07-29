import { OPERATORS_OR, OPERATORS_IS } from '~/vue_shared/components/filtered_search_bar/constants';
import StatusToken from './status_token.vue';
import ActivityToken from './activity_token.vue';
import SeverityToken from './severity_token.vue';
import ToolToken from './tool_token.vue';
import ReportTypeToken from './report_type_token.vue';
import ImageToken from './image_token.vue';
import ClusterToken from './cluster_token.vue';
import ProjectToken from './project_token.vue';
import IdentifierToken from './identifier_token.vue';
import ScannerToken from './scanner_token.vue';
import ReachabilityToken from './reachability_token.vue';

export const STATUS_TOKEN_DEFINITION = {
  type: 'state',
  title: StatusToken.i18n.statusLabel,
  multiSelect: true,
  unique: true,
  token: StatusToken,
  operators: OPERATORS_OR,
};

export const ACTIVITY_TOKEN_DEFINITION = {
  type: 'activity',
  title: ActivityToken.i18n.label,
  multiSelect: true,
  unique: true,
  token: ActivityToken,
  operators: OPERATORS_OR,
};

export const SEVERITY_TOKEN_DEFINITION = {
  type: 'severity',
  title: SeverityToken.i18n.label,
  multiSelect: true,
  unique: true,
  token: SeverityToken,
  operators: OPERATORS_OR,
};

export const TOOL_VENDOR_TOKEN_DEFINITION = {
  type: 'scanner',
  title: ToolToken.i18n.label,
  multiSelect: true,
  unique: true,
  token: ToolToken,
  operators: OPERATORS_OR,
};

export const REPORT_TYPE_VENDOR_TOKEN_DEFINITION = {
  type: 'reportType',
  title: ReportTypeToken.i18n.label,
  multiSelect: true,
  unique: true,
  token: ReportTypeToken,
  operators: OPERATORS_OR,
};

export const SCANNER_TOKEN_DEFINITION = {
  type: 'scanner',
  title: ScannerToken.i18n.label,
  multiSelect: true,
  unique: true,
  token: ScannerToken,
  operators: OPERATORS_OR,
};

export const IMAGE_TOKEN_DEFINITION = {
  type: 'image',
  title: ImageToken.i18n.label,
  multiSelect: true,
  unique: true,
  token: ImageToken,
  operators: OPERATORS_OR,
};

export const CLUSTER_TOKEN_DEFINITION = {
  type: 'cluster',
  title: ClusterToken.i18n.label,
  multiSelect: true,
  unique: true,
  token: ClusterToken,
  operators: OPERATORS_OR,
};

export const PROJECT_TOKEN_DEFINITION = {
  type: 'projectId',
  title: ProjectToken.i18n.label,
  multiSelect: true,
  unique: true,
  token: ProjectToken,
  operators: OPERATORS_OR,
};

export const IDENTIFIER_TOKEN_DEFINITION = {
  type: 'identifier',
  title: IdentifierToken.i18n.label,
  multiSelect: false,
  unique: true,
  token: IdentifierToken,
  operators: OPERATORS_IS,
};

export const REACHABILITY_TOKEN_DEFINITION = {
  type: 'reachability',
  title: ReachabilityToken.i18n.label,
  multiSelect: false,
  unique: true,
  token: ReachabilityToken,
  operators: OPERATORS_IS,
};
