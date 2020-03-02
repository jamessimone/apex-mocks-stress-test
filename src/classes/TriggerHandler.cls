public virtual class TriggerHandler {

    protected TriggerHandler() {
        if(!Trigger.isExecuting && !Test.isRunningTest()) {
            throw new TriggerHandlerException('TriggerHandler used outside of triggers / testing');
        }
    }

    public void execute() {
        switch on Trigger.operationType {
            when BEFORE_INSERT {
                this.beforeInsert(Trigger.new);
            }
            when BEFORE_UPDATE {
                this.beforeUpdate(Trigger.new, Trigger.newMap, Trigger.old, Trigger.oldMap);
            }
            when BEFORE_DELETE {
                this.beforeDelete(Trigger.old, Trigger.oldMap);
            }
            when AFTER_INSERT {
                this.afterInsert(Trigger.new, Trigger.newMap);
            }
            when AFTER_UPDATE {
                this.afterUpdate(Trigger.new, Trigger.newMap, Trigger.old, Trigger.oldMap);
            }
            when AFTER_DELETE {
                this.afterDelete(Trigger.old, Trigger.oldMap);
            }
            when AFTER_UNDELETE {
                this.afterUndelete(Trigger.new, Trigger.newMap);
            }
        }
    }

    protected List<SObject> getUpdatedRecordsWithChangedField(SObjectField field) {
        return this.getUpdatedRecordsWithChangedFields(new List<SObjectField>{ field });
    }

    protected List<SObject> getUpdatedRecordsWithChangedFields(List<SObjectField> fields) {
        List<SObject> updatedRecords = new List<SObject>();

        for(SObject record : Trigger.new) {
            SObject oldRecord = Trigger.oldMap.get(record.Id);
            for(SObjectField field : fields) {
                if(record.get(field) != oldRecord.get(field)) {
                    updatedRecords.add(record);
                }
            }
        }
        return updatedRecords;
    }

    protected virtual void beforeInsert(List<SObject> newRecords) {}
    protected virtual void beforeUpdate(List<SObject> updatedRecords, Map<Id, SObject> updatedRecordsMap, List<SObject> oldRecords, Map<Id, SObject> oldRecordsMap) {}
    protected virtual void beforeDelete(List<SObject> deletedRecords, Map<Id, SObject> deletedRecordsMap) {}
    protected virtual void afterInsert(List<SObject> newRecords, Map<Id, SObject> newRecordsMap) {}
    protected virtual void afterUpdate(List<SObject> updatedRecords, Map<Id, SObject> updatedRecordsMap, List<SObject> oldRecords, Map<Id, SObject> oldRecordsMap) {}
    protected virtual void afterDelete(List<SObject> deletedRecords, Map<Id, SObject> deletedRecordsMap) {}
    protected virtual void afterUndelete(List<SObject> undeletedRecords, Map<Id, SObject> undeletedRecordsMap) {}

    private class TriggerHandlerException extends Exception {}
}