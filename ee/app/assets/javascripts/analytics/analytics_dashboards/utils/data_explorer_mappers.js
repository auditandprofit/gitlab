import {
  MEASURE,
  DIMENSION,
  TIME_DIMENSION,
  CUSTOM_EVENT_NAME,
  CUSTOM_EVENT_NAME_MEMBER,
  CUBE_OPERATOR_EQUALS,
} from '../constants';

/**
 * Given a timeDimension CubeJS query property, map it to a string value which can be used by gl-filtered-search
 *
 * gl-filtered-search internally expects values to always be strings (for value equality checks), however the Cube property
 * is an object containing both a granularity and dimension property. So JSON stringify/parse on the way in/out of the filtered search
 */
export function mapTimeDimensionQueryToValue(queryProperty) {
  return JSON.stringify(queryProperty);
}
function mapTimeDimensionValueToQuery(value) {
  return JSON.parse(value);
}

function getValidTokenValues(tokenValues, availableTokens, tokenType) {
  const validOptions = availableTokens.find((token) => token.type === tokenType)?.options;
  const selectedTokens = tokenValues.filter((token) => token.type === tokenType);

  const validSelectedTokens = selectedTokens.filter((token) =>
    validOptions.some((option) => option.value === token.value.data),
  );

  return validSelectedTokens.map((token) => token.value.data);
}

function createToken(type, value) {
  return {
    type,
    value: {
      data: value,
      operator: '=',
    },
  };
}

function getFilterTokenValues(tokenValues) {
  const filters = [];

  const customEventNames = tokenValues
    .filter((token) => token.type === CUSTOM_EVENT_NAME)
    .map((token) => token.value.data);

  if (customEventNames.length > 0) {
    filters.push({
      member: CUSTOM_EVENT_NAME_MEMBER,
      operator: CUBE_OPERATOR_EQUALS,
      values: customEventNames,
    });
  }

  return filters;
}

export function mapQueryToTokenValues(query) {
  const values = [];

  if (query?.measures?.length > 0) {
    values.push(...query.measures.map((m) => createToken(MEASURE, m)));
  }

  if (query?.dimensions?.length > 0) {
    values.push(...query.dimensions.map((d) => createToken(DIMENSION, d)));
  }

  if (query?.timeDimensions?.length > 0) {
    values.push(
      ...query.timeDimensions.map((td) =>
        createToken(TIME_DIMENSION, mapTimeDimensionQueryToValue(td)),
      ),
    );
  }

  if (query?.filters?.length > 0) {
    const customEventNames = query.filters
      .filter((f) => f.member === CUSTOM_EVENT_NAME_MEMBER)
      .flatMap((f) => f.values);

    values.push(...customEventNames.map((e) => createToken(CUSTOM_EVENT_NAME, e)));
  }

  return values;
}

export function mapTokenValuesToQuery(tokenValues, availableTokens) {
  const measures = getValidTokenValues(tokenValues, availableTokens, MEASURE);
  const dimensions = getValidTokenValues(tokenValues, availableTokens, DIMENSION);
  const timeDimensions = getValidTokenValues(tokenValues, availableTokens, TIME_DIMENSION).map(
    mapTimeDimensionValueToQuery,
  );
  // Filters are free text so we don't match against availableTokens
  const filters = getFilterTokenValues(tokenValues);

  return {
    ...(measures.length > 0 && { measures }),
    ...(dimensions.length > 0 && { dimensions }),
    ...(timeDimensions.length > 0 && { timeDimensions }),
    ...(filters.length > 0 && { filters }),
  };
}
