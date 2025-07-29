import { sprintf, s__, n__ } from '~/locale';
import { convertToGraphQLId } from '~/graphql_shared/utils';
import { TYPENAME_PROJECT } from '~/graphql_shared/constants';

/**
 * Convert branch exceptions to readable string
 * @param exception {String|Object} { name: string, full_path: string}
 */
const humanizedBranchException = (exception) => {
  if (!exception) return '';

  if (typeof exception === 'string') {
    return sprintf(s__('SecurityOrchestration|%{branchName}'), {
      branchName: exception,
    });
  }

  return sprintf(
    s__('SecurityOrchestration|%{branchName} (in %{codeStart}%{fullPath}%{codeEnd})'),
    {
      branchName: exception.name,
      fullPath: exception.full_path,
    },
  );
};

/**
 *
 * @param exceptions {Array}
 * @returns {Array} formatted readable exceptions
 */
export const humanizedBranchExceptions = (exceptions) => {
  if (!exceptions) return [];

  const filteredExceptions = exceptions.filter(Boolean);

  if (filteredExceptions.length === 0) return [];

  return filteredExceptions.map(humanizedBranchException);
};

/**
 * build initial sentence for branch exceptions
 * @param exceptions
 * @returns {String}
 */
export const buildBranchExceptionsString = (exceptions) => {
  if (!exceptions || !exceptions.length) return '';

  return n__(' except branch:', ' except branches:', exceptions.length);
};

/**
 * Convert single short id format to full GraphqlQl id
 * @param type GraphQl type name
 * @param id Short Number or String id
 * @returns {*}
 */
export const mapShortIdToFullGraphQlFormat = (type = TYPENAME_PROJECT, id = '') =>
  convertToGraphQLId(type, id);

/**
 * Convert array of short id format to full GraphqlQl id
 * @param type GraphQl type name
 * @param ids Short Number or String ids
 * @returns {*[]}
 */
export const mapShortIdsToFullGraphQlFormat = (type, ids = []) =>
  ids?.map((id) => mapShortIdToFullGraphQlFormat(type, id)) || [];
