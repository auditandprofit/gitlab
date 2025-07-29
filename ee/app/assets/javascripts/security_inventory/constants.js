import { s__ } from '~/locale';
import { CRITICAL, HIGH, MEDIUM, LOW } from 'ee/vulnerabilities/constants';

const DEPENDENCY_SCANNING_KEY = 'DEPENDENCY_SCANNING';
const SAST_KEY = 'SAST';
export const SAST_ADVANCED_KEY = 'SAST_ADVANCED';
const SECRET_DETECTION_KEY = 'SECRET_DETECTION';
export const SECRET_PUSH_PROTECTION_KEY = 'SECRET_PUSH_PROTECTION';
const CONTAINER_SCANNING_KEY = 'CONTAINER_SCANNING';
export const CONTAINER_SCANNING_FOR_REGISTRY_KEY = 'CONTAINER_SCANNING_FOR_REGISTRY';
const DAST_KEY = 'DAST';
const SAST_IAC_KEY = 'SAST_IAC';

export const SIDEBAR_WIDTH_INITIAL = 300;
export const SIDEBAR_WIDTH_MINIMUM = 200;
export const SIDEBAR_WIDTH_STORAGE_KEY = 'security_inventory_sidebar_width';
export const SIDEBAR_VISIBLE_STORAGE_KEY = 'security_inventory_sidebar_visible';
export const SIDEBAR_INDENTATION_INCREMENT = 20; // pixels
export const SIDEBAR_SEARCH_DEBOUNCE = 500; // milliseconds

const SAST_LABEL = s__('SecurityInventory|SAST');
const DAST_LABEL = s__('SecurityInventory|DAST');
const SAST_IAC_LABEL = s__('SecurityInventory|IaC');
const SECRET_DETECTION_LABEL = s__('SecurityInventory|SD');
const DEPENDENCY_SCANNING_LABEL = s__('SecurityInventory|DS');
const CONTAINER_SCANNING_LABEL = s__('SecurityInventory|CS');

export const SCANNER_TYPES = {
  [DEPENDENCY_SCANNING_KEY]: {
    textLabel: DEPENDENCY_SCANNING_LABEL,
    name: s__('SecurityInventory|Dependency scanning'),
  },
  [SAST_KEY]: {
    textLabel: SAST_LABEL,
    name: s__('SecurityInventory|Static application security testing (SAST)'),
  },
  [SAST_ADVANCED_KEY]: {
    textLabel: SAST_LABEL,
    name: s__('SecurityInventory|Static application security testing (SAST)'),
  },
  [SECRET_DETECTION_KEY]: {
    textLabel: SECRET_DETECTION_LABEL,
    name: s__('SecurityInventory|Secret detection'),
  },
  [SECRET_PUSH_PROTECTION_KEY]: {
    textLabel: SECRET_DETECTION_LABEL,
    name: s__('SecurityInventory|Secret push protection'),
  },
  [CONTAINER_SCANNING_KEY]: {
    textLabel: CONTAINER_SCANNING_LABEL,
    name: s__('SecurityInventory|Container scanning'),
  },
  [CONTAINER_SCANNING_FOR_REGISTRY_KEY]: {
    textLabel: CONTAINER_SCANNING_LABEL,
    name: s__('SecurityInventory|Container scanning'),
  },
  [DAST_KEY]: {
    textLabel: DAST_LABEL,
    name: s__('SecurityInventory|Dynamic application security testing (DAST)'),
  },
  [SAST_IAC_KEY]: {
    textLabel: SAST_IAC_LABEL,
    name: s__('SecurityInventory|Infrastructure as code scanning (IaC)'),
  },
};

export const SCANNER_POPOVER_GROUPS = {
  [DEPENDENCY_SCANNING_KEY]: ['DEPENDENCY_SCANNING'],
  [SAST_KEY]: ['SAST', 'SAST_ADVANCED'],
  [SECRET_DETECTION_KEY]: ['SECRET_DETECTION', 'SECRET_PUSH_PROTECTION'],
  [CONTAINER_SCANNING_KEY]: ['CONTAINER_SCANNING', 'CONTAINER_SCANNING_FOR_REGISTRY'],
  [DAST_KEY]: ['DAST'],
  [SAST_IAC_KEY]: ['SAST_IAC'],
};

export const SCANNER_POPOVER_LABELS = {
  [SAST_KEY]: s__('SecurityInventory|Basic SAST'),
  [SAST_ADVANCED_KEY]: s__('SecurityInventory|GitLab Advanced SAST'),
  [SECRET_DETECTION_KEY]: s__('SecurityInventory|Pipeline secret detection'),
  [SECRET_PUSH_PROTECTION_KEY]: s__('SecurityInventory|Secret push protection'),
  [CONTAINER_SCANNING_KEY]: s__('SecurityInventory|Container scanning (standard)'),
  [CONTAINER_SCANNING_FOR_REGISTRY_KEY]: s__('SecurityInventory|Container scanning for registry'),
};

export const SEVERITY_SEGMENTS = [CRITICAL, HIGH, MEDIUM, LOW];

export const SEVERITY_BACKGROUND_COLORS = {
  [CRITICAL]: 'gl-bg-red-800',
  [HIGH]: 'gl-bg-red-600',
  [MEDIUM]: 'gl-bg-orange-400',
  [LOW]: 'gl-bg-orange-300',
};

export const VULNERABILITY_REPORT_PATHS = {
  PROJECT: '/-/security/vulnerability_report',
  GROUP: '/-/security/vulnerabilities',
};

export const PROJECT_SECURITY_CONFIGURATION_PATH = '/-/security/configuration';
export const PROJECT_VULNERABILITY_REPORT_PATH = '/-/security/vulnerability_report';
export const GROUP_VULNERABILITY_REPORT_PATH = '/-/security/vulnerabilities';
export const PROJECT_PIPELINE_JOB_PATH = '/-/jobs';
