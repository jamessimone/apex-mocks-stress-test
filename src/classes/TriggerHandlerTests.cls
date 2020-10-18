@isTest
private class TriggerHandlerTests {
    // I normally put private classes at the bottom, but to prevent you from having to scroll ...
    private class TestTriggerHandler extends TriggerHandler {
        public TriggerOperation Method { get; private set;}

        @testVisible
        protected override void beforeInsert(List<SObject> newRecords) {
            this.Method = TriggerOperation.BEFORE_INSERT;
        }
        @testVisible
        protected override void beforeUpdate(Map<Id, SObject> updatedRecordsMap, Map<Id, SObject> oldRecordsMap) {
            this.Method = TriggerOperation.BEFORE_UPDATE;
        }
        @testVisible
        protected override void beforeDelete(Map<Id, SObject> deletedRecordsMap) {
            this.Method = TriggerOperation.BEFORE_DELETE;
        }
        @testVisible
        protected override void afterInsert(Map<Id, SObject> newRecordsMap) {
            this.Method = TriggerOperation.AFTER_INSERT;
        }
        @testVisible
        protected override void afterUpdate(Map<Id, SObject> updatedRecordsMap, Map<Id, SObject> oldRecordsMap) {
            this.Method = TriggerOperation.AFTER_UPDATE;
        }
        @testVisible
        protected override void afterDelete(Map<Id, SObject> deletedRecordsMap) {
            this.Method = TriggerOperation.AFTER_DELETE;
        }
        @testVisible
        protected override void afterUndelete(Map<Id, SObject> undeletedRecordsMap) {
            this.Method = TriggerOperation.AFTER_UNDELETE;
        }
    }

    @isTest
    static void it_should_perform_before_insert() {
        TestTriggerHandler testHandler = new TestTriggerHandler();
        TriggerHandler.triggerContext = TriggerOperation.BEFORE_INSERT;

        testHandler.execute();

        System.assertEquals(TriggerOperation.BEFORE_INSERT, testHandler.Method);
    }

    @isTest
    static void it_should_perform_before_update() {
        TestTriggerHandler testHandler = new TestTriggerHandler();
        TriggerHandler.triggerContext = TriggerOperation.BEFORE_UPDATE;

        testHandler.execute();

        System.assertEquals(TriggerOperation.BEFORE_UPDATE, testHandler.Method);
    }

    @isTest
    static void it_should_perform_before_delete() {
        TestTriggerHandler testHandler = new TestTriggerHandler();
        TriggerHandler.triggerContext = TriggerOperation.BEFORE_DELETE;

        testHandler.execute();

        System.assertEquals(TriggerOperation.BEFORE_DELETE, testHandler.Method);
    }

    @isTest
    static void it_should_perform_after_insert() {
        TestTriggerHandler testHandler = new TestTriggerHandler();
        TriggerHandler.triggerContext = TriggerOperation.AFTER_INSERT;

        testHandler.execute();

        System.assertEquals(TriggerOperation.AFTER_INSERT, testHandler.Method);
    }

    @isTest
    static void it_should_perform_after_update() {
        TestTriggerHandler testHandler = new TestTriggerHandler();
        TriggerHandler.triggerContext = TriggerOperation.AFTER_UPDATE;

        testHandler.execute();

        System.assertEquals(TriggerOperation.AFTER_UPDATE, testHandler.Method);
    }

    @isTest
    static void it_should_perform_after_delete() {
        TestTriggerHandler testHandler = new TestTriggerHandler();
        TriggerHandler.triggerContext = TriggerOperation.AFTER_DELETE;

        testHandler.execute();

        System.assertEquals(TriggerOperation.AFTER_DELETE, testHandler.Method);
    }

    @isTest
    static void it_should_perform_after_undelete() {
        TestTriggerHandler testHandler = new TestTriggerHandler();
        TriggerHandler.triggerContext = TriggerOperation.AFTER_UNDELETE;

        testHandler.execute();

        System.assertEquals(TriggerOperation.AFTER_UNDELETE, testHandler.Method);
    }
}