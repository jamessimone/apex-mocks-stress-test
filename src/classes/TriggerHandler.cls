public virtual class TriggerHandler {
    @testVisible
    private static TriggerOperation triggerContext;

    protected TriggerHandler() {
        if (!Trigger.isExecuting && !Test.isRunningTest()) {
            throw new TriggerHandlerException('TriggerHandler used outside of triggers / testing');
        }
    }

    public void execute() {
        TriggerOperation context = triggerContext != null ? triggerContext : Trigger.operationType;
        switch on context {
            when BEFORE_INSERT {
                this.beforeInsert(Trigger.new);
            }
            when BEFORE_UPDATE {
                this.beforeUpdate(Trigger.newMap, Trigger.oldMap);
            }
            when BEFORE_DELETE {
                this.beforeDelete(Trigger.oldMap);
            }
            when AFTER_INSERT {
                this.afterInsert(Trigger.newMap);
            }
            when AFTER_UPDATE {
                this.afterUpdate(Trigger.newMap, Trigger.oldMap);
            }
            when AFTER_DELETE {
                this.afterDelete(Trigger.oldMap);
            }
            when AFTER_UNDELETE {
                this.afterUndelete(Trigger.newMap);
            }
        }
        this.andFinally();
    }

    /** Remember - record Ids are not available beforeInsert! */
    protected virtual void beforeInsert(List<SObject> newRecords) {
    }
    protected virtual void beforeUpdate(Map<Id, SObject> updatedRecordsMap, Map<Id, SObject> oldRecordsMap) {
    }
    protected virtual void beforeDelete(Map<Id, SObject> deletedRecordsMap) {
    }
    protected virtual void afterInsert(Map<Id, SObject> newRecordsMap) {
    }
    protected virtual void afterUpdate(Map<Id, SObject> updatedRecordsMap, Map<Id, SObject> oldRecordsMap) {
    }
    protected virtual void afterDelete(Map<Id, SObject> deletedRecordsMap) {
    }
    protected virtual void afterUndelete(Map<Id, SObject> undeletedRecordsMap) {
    }
    /** `andFinally` is called on every inovcation, regardless of Trigger context */
    protected virtual void andFinally() {
    }

    private class TriggerHandlerException extends Exception {
    }
}
