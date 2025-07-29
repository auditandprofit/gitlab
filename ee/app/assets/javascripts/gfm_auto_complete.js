import $ from 'jquery';
import { DEFAULT_DEBOUNCE_AND_THROTTLE_MS } from '~/lib/utils/constants';
import '~/lib/utils/jquery_at_who';
import GfmAutoComplete, { showAndHideHelper, escape, setupSubcommands } from '~/gfm_auto_complete';
import { s__ } from '~/locale';
import { MERGE_REQUEST_NOTEABLE_TYPE } from '~/notes/constants';

/**
 * This is added to keep the export parity with the CE counterpart.
 *
 * Some modules import `defaultAutocompleteConfig` or `membersBeforeSave`
 * which will be undefined if not exported from here in EE.
 */
export {
  escape,
  defaultAutocompleteConfig,
  membersBeforeSave,
  highlighter,
  CONTACT_STATE_ACTIVE,
  CONTACTS_ADD_COMMAND,
  CONTACTS_REMOVE_COMMAND,
} from '~/gfm_auto_complete';

const EPICS_ALIAS = 'epics';
const ITERATIONS_ALIAS = 'iterations';
const VULNERABILITIES_ALIAS = 'vulnerabilities';

export const Q_ISSUE_SUB_COMMANDS = {
  dev: {
    header: s__('AmazonQ|dev'),
    description: s__('AmazonQ|Create a merge request to incorporate Amazon Q suggestions'),
  },
  transform: {
    header: s__('AmazonQ|transform'),
    description: s__('AmazonQ|Upgrade Java Maven application to Java 17'),
  },
};

export const Q_MERGE_REQUEST_SUB_COMMANDS = {
  dev: {
    header: s__('AmazonQ|dev'),
    description: s__('AmazonQ|Apply changes to this merge request based on the comments'),
  },
  review: {
    header: s__('AmazonQ|review'),
    description: s__('AmazonQ|Review merge request for code quality and security issues'),
  },
  test: {
    header: s__('AmazonQ|test'),
    description: s__('AmazonQ|Create unit tests for this merge request'),
  },
};

export const Q_MERGE_REQUEST_DIFF_SUB_COMMANDS = {
  ...Q_MERGE_REQUEST_SUB_COMMANDS,
  test: {
    header: s__('AmazonQ|test'),
    description: s__(
      'AmazonQ|Create unit tests for selected lines of code in Java or Python files',
    ),
  },
};

const getQSubCommands = ($input) => {
  if ($input.data('noteableType') === MERGE_REQUEST_NOTEABLE_TYPE) {
    const canSuggest = $input.data('canSuggest');
    if (canSuggest) {
      return Q_MERGE_REQUEST_DIFF_SUB_COMMANDS;
    }
    return Q_MERGE_REQUEST_SUB_COMMANDS;
  }

  return Q_ISSUE_SUB_COMMANDS;
};

GfmAutoComplete.Iterations = {
  templateFunction({ id, title }) {
    return `<li><small>*iteration:${id}</small> ${escape(title)}</li>`;
  },
};

class GfmAutoCompleteEE extends GfmAutoComplete {
  setupAtWho($input) {
    if (this.enableMap.epics) {
      this.setupAutoCompleteEpics($input, this.getDefaultCallbacks());
    }

    if (this.enableMap.iterations) {
      this.setupAutoCompleteIterations($input, this.getDefaultCallbacks());
    }

    if (this.enableMap.vulnerabilities) {
      this.setupAutoCompleteVulnerabilities($input, this.getDefaultCallbacks());
    }

    super.setupAtWho($input);
  }

  loadSubcommands($input, data) {
    if (data.some((c) => c.name === 'q')) {
      setupSubcommands($input, 'q', getQSubCommands($input));
    }

    super.loadSubcommands($input, data);
  }

  // eslint-disable-next-line class-methods-use-this
  setupAutoCompleteEpics = ($input, defaultCallbacks) => {
    $input.atwho({
      at: '&',
      alias: EPICS_ALIAS,
      searchKey: 'search',
      displayTpl(value) {
        let tmpl = GfmAutoComplete.Loading.template;
        if (value.title != null) {
          tmpl = GfmAutoComplete.Issues.templateFunction(value);
        }
        return tmpl;
      },
      data: GfmAutoComplete.defaultLoadingData,
      insertTpl: GfmAutoComplete.Issues.insertTemplateFunction,
      skipSpecialCharacterTest: true,
      callbacks: {
        ...defaultCallbacks,
        beforeSave(merges) {
          return $.map(merges, (m) => {
            if (m.title == null) {
              return m;
            }
            return {
              id: m.iid,
              reference: m.reference,
              title: m.title,
              search: `${m.iid} ${m.title}`,
            };
          });
        },
      },
    });
    showAndHideHelper($input, EPICS_ALIAS);
  };

  // eslint-disable-next-line class-methods-use-this
  setupAutoCompleteIterations = ($input, defaultCallbacks) => {
    $input.atwho({
      at: '*iteration:',
      alias: ITERATIONS_ALIAS,
      searchKey: 'search',
      displayTpl(value) {
        let tmpl = GfmAutoComplete.Loading.template;
        if (value.id != null) {
          tmpl = GfmAutoComplete.Iterations.templateFunction(value);
        }
        return tmpl;
      },
      data: GfmAutoComplete.defaultLoadingData,
      // eslint-disable-next-line no-template-curly-in-string
      insertTpl: '${atwho-at}${id}',
      skipSpecialCharacterTest: true,
      callbacks: {
        ...defaultCallbacks,
        beforeSave(merges) {
          return $.map(merges, (m) => {
            if (m.id == null) {
              return m;
            }

            return {
              id: m.id,
              title: m.title,
              search: `${m.id} ${m.title}`,
            };
          });
        },
      },
    });
    showAndHideHelper($input, ITERATIONS_ALIAS);
  };

  // eslint-disable-next-line class-methods-use-this
  setupAutoCompleteVulnerabilities = ($input, defaultCallbacks) => {
    $input.atwho({
      at: '[vulnerability:',
      suffix: ']',
      alias: VULNERABILITIES_ALIAS,
      delay: DEFAULT_DEBOUNCE_AND_THROTTLE_MS,
      searchKey: 'search',
      displayTpl(value) {
        let tmpl = GfmAutoComplete.Loading.template;
        if (value.title != null) {
          tmpl = GfmAutoComplete.Issues.templateFunction(value);
        }
        return tmpl;
      },
      data: GfmAutoComplete.defaultLoadingData,
      insertTpl: GfmAutoComplete.Issues.insertTemplateFunction,
      skipSpecialCharacterTest: true,
      callbacks: {
        ...defaultCallbacks,
        beforeSave(merges) {
          return merges.map((m) => {
            if (m.title == null) {
              return m;
            }
            return {
              id: m.id,
              title: m.title,
              reference: m.reference,
              search: `${m.id} ${m.title}`,
            };
          });
        },
      },
    });
    showAndHideHelper($input, VULNERABILITIES_ALIAS);
  };
}

export default GfmAutoCompleteEE;
