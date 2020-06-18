import { api, LightningElement, track, wire } from 'lwc';
import { getObjectInfo } from 'lightning/uiObjectInfoApi';
import { getPicklistValues } from 'lightning/uiObjectInfoApi';
import { getRecord, updateRecord } from 'lightning/uiRecordApi';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

import LEAD_OBJECT from '@salesforce/schema/Lead';
import CUSTOM_DATE_FIELD from '@salesforce/schema/Lead.CustomDate__c';
import STATUS_FIELD from '@salesforce/schema/Lead.Status';

const COMPLETED = 'Mark Status as Complete';
const CLOSED = 'Closed';
const SPECIAL_STATUS = 'Closed - Special Date';

export default class CustomPath extends LightningElement {
  //start off with all @track methods and dependencies
  //plus lifecycle methods
  @api recordId;
  @wire(getObjectInfo, { objectApiName: LEAD_OBJECT })
  objectInfo;

  @wire(getRecord, {
    recordId: '$recordId',
    fields: [CUSTOM_DATE_FIELD, STATUS_FIELD]
  })
  lead({ data, error }) {
    const leadCb = (data) => {
      this._status = this._getLeadValueOrDefault(
        data,
        STATUS_FIELD.fieldApiName
      );
      this._storedStatus = this._status;
      this._dateValue = this._getLeadValueOrDefault(
        data,
        CUSTOM_DATE_FIELD.fieldApiName
      );
    };
    this._handleWireCallback({ data, error, cb: leadCb });
  }

  @wire(getPicklistValues, {
    recordTypeId: '$objectInfo.data.defaultRecordTypeId',
    fieldApiName: STATUS_FIELD
  })
  leadStatuses({ data, error }) {
    const leadStatusCb = (data) => {
      const statusSet = new Set();
      //initial iteration to build unique list
      data.values.forEach((picklistStatus) => {
        if (!picklistStatus.label.includes(CLOSED)) {
          statusSet.add(picklistStatus.label);
        }
      });
      statusSet.add('Closed');
      this._statuses = Array.from(statusSet);

      //now build the visible/closed statuses
      data.values.forEach((status, index) => {
        if (status.label.indexOf(CLOSED) > -1) {
          this.closedStatuses.push({
            label: status.label,
            value: status.label
          });
          if (!this.currentClosedStatus) {
            //promote the first closed value to the component
            //so that the combobox can show a sensible default
            this.currentClosedStatus = status.label;
          }
        } else {
          this.visibleStatuses.push(
            this._getPathItemFromStatus(status.label, index)
          );
        }
      });
      this.visibleStatuses.push(
        this._getPathItemFromStatus(CLOSED, this.visibleStatuses.length)
      );
    };
    this._handleWireCallback({ data, error, cb: leadStatusCb });
  }

  renderedCallback() {
    if (!this._hasRendered && this.hasData()) {
      this._hasRendered = true;
      this.showAdvanceButton = true;

      //on the first render, we have to manually set the aria/current values
      const current =
        this.visibleStatuses.find(
          (status) => status.label === this._status
        )[0] || {};
      current.class += ' slds-is-current';
      current.ariaSelected = true;
    }
  }

  /* private fields for tracking*/
  @track showAdvanceButton = false;
  @track advanceButtonText = COMPLETED;
  @track _storedStatus;
  @track _status;
  @track _dateValue;
  @track visibleStatuses = [];
  @track closedStatuses = [];
  @track showClosedOptions = false;
  @track currentClosedStatus;

  //truly private fields
  _hasRendered = false;
  _statuses;

  //private methods and getters
  get pathActionIconName() {
    return this.advanceButtonText === COMPLETED ? 'utility:check' : '';
  }

  hasData() {
    //classic
    return !!(this.lead.data && this.leadStatuses.data);
  }

  modalSaveHandler = async (event) => {
    event.stopPropagation();
    event.preventDefault();
    this._toggleModal();
    await this._saveLeadAndToast();
  };

  handleStatusClick(event) {
    event.stopPropagation();
    //update the stored status, but don't update the record
    //till the save button is clicked
    const updatedStatusName = event.target.textContent;
    this.advanceButtonText =
      updatedStatusName === this._status ? COMPLETED : 'Mark As Current Status';
    this._storedStatus = updatedStatusName;

    if (this._status !== this._storedStatus) {
      this._updateVisibleStatuses();
    }

    if (this._storedStatus === CLOSED) {
      this.advanceButtonText = 'Select Closed Status';
      this._storedStatus = this.currentClosedStatus;
      this.showClosedOptions = true;
      this._toggleModal();
    }
  }

  handleClosedStatusChange(event) {
    const newClosedStatus = event.target.value;
    this.currentClosedStatus = newClosedStatus;
    this._storedStatus = newClosedStatus;
    this.customCloseDateSelected = this._storedStatus === SPECIAL_STATUS;
  }

  async handleAdvanceButtonClick(event) {
    event.stopPropagation();

    if (this._status === this._storedStatus) {
      const nextStatusIndex = this.visibleStatuses.indexOf(this._status) + 1;
      this._storedStatus = this.visibleStatuses[nextStatusIndex];
      if (nextStatusIndex === this.visibleStatuses.length - 1) {
        //the last status should always be "Closed"
        //and the modal should be popped
        this._toggleModal();
      } else {
        await this._saveLeadAndToast();
      }
    } else if (this._storedStatus === CLOSED) {
      //curses! they closed the modal
      //let's re-open it
      this._toggleModal();
    } else {
      await this._saveLeadAndToast();
    }
  }

  //truly private methods, only called from within this file
  _handleWireCallback = ({ data, error, cb }) => {
    if (error) console.error(error);
    else if (data) {
      cb(data);
    }
  };

  _getPathItemFromStatus(status, index) {
    const ariaSelected = !!this._storedStatus
      ? this._storedStatus.includes(status)
      : false;
    const isCurrent = !!this._status ? this._status.includes(status) : false;
    const classList = ['slds-path__item'];
    if (ariaSelected) {
      classList.push('slds-is-active');
    } else {
      const placeInStatuses = this._statuses.findIndex((aStatus) =>
        aStatus.includes(status)
      );
      const indexShifter = status === CLOSED ? 0 : 1;
      const styledProgress =
        !ariaSelected && index - indexShifter < placeInStatuses
          ? 'slds-is-complete'
          : 'slds-is-incomplete';
      classList.push(styledProgress);
    }
    if (isCurrent) {
      classList.push('slds-is-current');
    }
    return {
      ariaSelected: false,
      class: classList.join(' '),
      label: status
    };
  }

  _toggleModal() {
    this.template.querySelector('c-modal').toggleModal();
  }

  _getLeadValueOrDefault(data, val) {
    return data ? data.fields[val].displayValue : '';
  }

  async _saveLeadAndToast() {
    let error;
    try {
      this._status = this._storedStatus;
      const recordToUpdate = {
        fields: {
          Id: this.recordId,
          Status: this._status
        }
      };
      if (this._dateValue) {
        recordToUpdate.CustomDate__c = this._dateValue;
      }
      await updateRecord(recordToUpdate);
      this._updateVisibleStatuses();
    } catch (err) {
      error = err;
    }
    //not crazy about this ternary
    //but I'm even less crazy about the 6
    //extra lines that would be necessary for
    //a second object
    this.dispatchEvent(
      new ShowToastEvent({
        title: !error ? 'Success!' : 'Record failed to save',
        variant: !error ? 'success' : 'error',
        message: !error
          ? 'Record successfully updated!'
          : `Record failed to save with message: ${JSON.stringify(error)}`
      })
    );
    //in reality, LDS errors are a lot uglier and should be handled gracefully
    //I recommend the `reduceErrors` utils function from @tsalb/lwc-utils:
    //https://github.com/tsalb/lwc-utils/blob/master/force-app/main/default/lwc/utils/utils.js
  }

  _updateVisibleStatuses() {
    //update the shown statuses based on the selection
    const newStatuses = [];
    for (let index = 0; index < this.visibleStatuses.length; index++) {
      const status = this.visibleStatuses[index];
      const pathItem = this._getPathItemFromStatus(status.label, index);
      if (
        this._status !== this._storedStatus &&
        pathItem.label === this._status
      ) {
        pathItem.class = pathItem.class
          .replace('slds-is-complete', '')
          .replace('  ', ' ');
      }
      newStatuses.push(pathItem);
    }
    this.visibleStatuses = newStatuses;
  }
}
