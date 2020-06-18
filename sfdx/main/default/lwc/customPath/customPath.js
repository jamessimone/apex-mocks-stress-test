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
    fieldApiName: STATUS_FIELD,
    //this one dirty hack you would never expect ...
    //in all seriousness, I'm not certain what the "supported"
    //state is for passing extraneous values to @wire methods;
    //on the other hand, this is for sure the easiest way to
    //guarantee order of operations when it comes to wires
    status: '$_status'
  })
  leadStatuses({ data, error }) {
    const leadStatusCb = (data) => {
      data.values.forEach((status) => {
        if (status.label.indexOf(CLOSED) > -1) {
          this.closedStatuses.push({
            label: status.label,
            value: status.label
          });
          if (!this.currentClosedStatus) {
            this.currentClosedStatus = status.label;
          }
        } else {
          this.visibleStatuses.push(status.label);
        }
      });
      this.visibleStatuses.push(CLOSED);
    };
    this._handleWireCallback({ data, error, cb: leadStatusCb });
  }

  renderedCallback() {
    if (!this._hasRendered && this.hasData) {
      this._hasRendered = true;
      this.showAdvanceButton = true;
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

  //short circuit var
  _hasRendered = false;

  //private methods and getters
  get pathActionIconName() {
    return this.advanceButtonText === COMPLETED ? 'utility:check' : '';
  }

  hasData() {
    return this.lead.data && this.leadStatuses.data;
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
    if (error) console.error;
    else if (data) {
      cb(data);
    }
  };

  _toggleModal() {
    this.template.querySelector('c-modal').toggleModal();
  }

  _getLeadValueOrDefault(data, val) {
    return data ? data.fields[val].displayValue : '';
  }

  async _saveLeadAndToast() {
    let success = true;
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
    } catch (err) {
      error = err;
      success = false;
    }
    //not crazy about this ternary
    //but I'm even less crazy about the 6
    //extra lines that would be necessary for
    //a second object
    this.dispatchEvent(
      new ShowToastEvent({
        title: success ? 'Success!' : 'Record failed to save',
        variant: success ? 'success' : 'error',
        message: success
          ? 'Record successfully updated!'
          : `Record failed to save with message: ${JSON.stringify(error)}`
      })
    );
  }
}
