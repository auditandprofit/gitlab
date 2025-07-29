import Vue from 'vue';
import { isEqual } from 'lodash';
import { __, s__ } from '~/locale';
import ConfirmModal from 'ee/groups/settings/permissions/components/confirm_modal.vue';

const confirmModalWrapperClassName = 'js-general-permissions-confirm-modal-wrapper';

const showConfirmModal = () => {
  const confirmModalWrapper = document.querySelector(`.${confirmModalWrapperClassName}`);
  const confirmModalElement = document.createElement('div');

  confirmModalWrapper.append(confirmModalElement);

  new Vue({
    render(createElement) {
      return createElement(ConfirmModal, {
        props: {
          modalOptions: {
            modalId: 'confirm-general-permissions-changes',
            title: s__('ApplicationSettings|Approve users in the pending approval status?'),
            text: s__(
              'ApplicationSettings|By making this change, you will automatically approve all users who are pending approval.',
            ),
            actionPrimary: {
              text: s__('ApplicationSettings|Approve users'),
            },
            actionCancel: {
              text: __('Cancel'),
            },
          },
        },
      });
    },
  }).$mount(confirmModalElement);
};

const shouldShowConfirmModal = ({
  seatControlTransition,
  newUserSignupsCapOriginalValue,
  newUserSignupsCapNewValue,
  groupPermissionsForm,
}) => {
  const hasModalBeenConfirmed = groupPermissionsForm.dataset.modalConfirmed === 'true';
  const hasUserCapChangedToOff = isEqual(seatControlTransition, ['user_cap', 'off']);

  if (hasModalBeenConfirmed) {
    return false;
  }

  if (hasUserCapChangedToOff) {
    return true;
  }

  const isUserCapSelected = isEqual(seatControlTransition, ['user_cap', 'user_cap']);

  return (
    isUserCapSelected &&
    gon.features.saasUserCapsAutoApprovePendingUsersOnCapIncrease &&
    parseInt(newUserSignupsCapNewValue, 10) > parseInt(newUserSignupsCapOriginalValue, 10)
  );
};

const seatControlTransition = () => {
  const inputs = Array.from(document.querySelectorAll('#js-seat-control input[type=radio]'));

  if (inputs.length === 0) {
    return [];
  }

  const originalInput = inputs.find((input) => input.defaultChecked);
  const currentInput = inputs.find((input) => input.checked);

  return [originalInput.value, currentInput.value];
};

const onGroupPermissionsFormSubmit = (event) => {
  const newUserSignupsCapInput = document.querySelector('#group_new_user_signups_cap');
  if (!newUserSignupsCapInput) {
    return;
  }
  const { dirtySubmitOriginalValue: newUserSignupsCapOriginalValue } =
    newUserSignupsCapInput.dataset;

  if (
    shouldShowConfirmModal({
      seatControlTransition: seatControlTransition(),
      newUserSignupsCapOriginalValue,
      newUserSignupsCapNewValue: newUserSignupsCapInput.value,
      groupPermissionsForm: event.target,
    })
  ) {
    event.preventDefault();
    event.stopImmediatePropagation();
    showConfirmModal();
  }
};

export const initGroupPermissionsFormSubmit = () => {
  const groupPermissionsForm = document.querySelector('.js-general-permissions-form');
  if (!groupPermissionsForm) {
    return;
  }
  const confirmModalWrapper = document.createElement('div');

  confirmModalWrapper.className = confirmModalWrapperClassName;
  groupPermissionsForm.append(confirmModalWrapper);

  groupPermissionsForm.addEventListener('submit', onGroupPermissionsFormSubmit);
};

export const initSetUserCapRadio = () => {
  const section = document.querySelector('#js-seat-control');

  if (!section) {
    return;
  }

  const allRelatedRadioButtons = section.querySelectorAll('input[type="radio"]');
  const userCapRadioButton = section.querySelector('input[type="radio"][value="user_cap"]');
  const numberInput = section.querySelector('input[name="group[new_user_signups_cap]"]');
  const fieldError = section.querySelector('.gl-field-error');

  let savedInputValue = numberInput.value;

  const handleEvent = () => {
    if (userCapRadioButton.checked) {
      numberInput.disabled = false;
      numberInput.value = savedInputValue;
    } else {
      numberInput.disabled = true;
      savedInputValue = numberInput.value;
      numberInput.value = '';
      numberInput.classList.remove('gl-field-error-outline');
      fieldError.classList.add('hidden');
    }
  };

  allRelatedRadioButtons.forEach((radioButton) => {
    radioButton.addEventListener('change', handleEvent);
  });

  handleEvent();
};
