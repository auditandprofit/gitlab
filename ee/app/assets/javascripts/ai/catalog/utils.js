import { formValidators } from '@gitlab/ui/dist/utils';
import { s__, sprintf } from '~/locale';

export const createFieldValidators = ({ requiredLabel, maxLength } = {}) => {
  const validators = [];

  if (requiredLabel !== undefined) {
    validators.push(formValidators.required(requiredLabel));
  }

  if (maxLength !== undefined) {
    validators.push(
      formValidators.factory(
        sprintf(
          s__('AICatalog|Input cannot exceed %{value} characters. Please shorten your input.'),
          {
            value: maxLength,
          },
        ),
        (value) => (value?.length || 0) <= maxLength,
      ),
    );
  }

  return validators;
};
