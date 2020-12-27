@isTest
private class RollupTests {
  @TestSetup
  static void setup() {
    insert new Account(Name = 'RollupTests');
  }

  private class DMLMock extends Rollup.DMLHelper {
    public List<SObject> Records { get; private set; }
    public override void doUpdate(List<SObject> recordsToUpdate) {
      this.Records = recordsToUpdate;
    }
  }

  /** Trigger tests */

  @isTest
  static void shouldNotRunForInvalidTriggerContext() {
    DMLMock mock = getMock(new List<Opportunity>{ new Opportunity(Amount = 50) });
    Rollup.triggerContext = TriggerOperation.BEFORE_INSERT;

    Test.startTest();
    Rollup.sumFromTrigger(Opportunity.Amount, Opportunity.AccountId, Account.Id, Account.AnnualRevenue, Account.SObjectType).runCalc();
    Test.stopTest();

    System.assertEquals(null, mock.Records, 'Records should not have been set or updated, this is a no-op');
  }

  @isTest
  static void shouldSumFromTriggerAfterInsert() {
    DMLMock mock = getMock(new List<Opportunity>{ new Opportunity(Amount = 25), new Opportunity(Amount = 25) });
    Rollup.triggerContext = TriggerOperation.AFTER_INSERT;

    Rollup rollup = Rollup.sumFromTrigger(Opportunity.Amount, Opportunity.AccountId, Account.Id, Account.AnnualRevenue, Account.SObjectType);

    System.assertEquals(null, mock.Records);

    Test.startTest();
    rollup.runCalc();
    Test.stopTest();

    System.assertEquals(1, mock.Records.size(), 'Records should have been populated SUM AFTER_INSERT');
    Account updatedAcc = (Account) mock.Records[0];
    System.assertEquals(50, updatedAcc.AnnualRevenue, 'SUM AFTER_INSERT should add the original opportunity amount');
  }

  @isTest
  static void shouldSumFromTriggerAfterUpdate() {
    Opportunity opp = new Opportunity(Id = TestingUtils.generateId(Opportunity.SObjectType), Amount = 50);
    DMLMock mock = getMock(new List<Opportunity>{ opp });
    Rollup.triggerContext = TriggerOperation.AFTER_UPDATE;

    Rollup.oldRecordsMap = new Map<Id, Opportunity>{ opp.Id => new Opportunity(Amount = 25) };

    Test.startTest();
    Rollup.sumFromTrigger(Opportunity.Amount, Opportunity.AccountId, Account.Id, Account.AnnualRevenue, Account.SObjectType).runCalc();
    Test.stopTest();

    System.assertEquals(1, mock.Records.size(), 'Records should have been populated SUM AFTER_UPDATE');
    Account updatedAcc = (Account) mock.Records[0];
    System.assertEquals(25, updatedAcc.AnnualRevenue, 'SUM AFTER_UPDATE should take the diff between the current amount and the pre-existing one');
  }

  @isTest
  static void shouldSumFromTriggerBeforeDelete() {
    DMLMock mock = getMock(new List<Opportunity>{ new Opportunity(Amount = 100) });
    Rollup.triggerContext = TriggerOperation.BEFORE_DELETE;

    Test.startTest();
    Rollup.sumFromTrigger(Opportunity.Amount, Opportunity.AccountId, Account.Id, Account.AnnualRevenue, Account.SObjectType).runCalc();
    Test.stopTest();

    System.assertEquals(1, mock.Records.size(), 'Records should have been populated SUM BEFORE_DELETE');
    Account updatedAcc = (Account) mock.Records[0];
    System.assertEquals(-100, updatedAcc.AnnualRevenue, 'SUM BEFORE_DELETE should subtract the current amount from the pre-existing one');
  }

  @isTest
  static void shouldCountDistinctFromTrigger() {
    DMLMock mock = getMock(new List<Opportunity>{ new Opportunity() });
    Rollup.triggerContext = TriggerOperation.AFTER_INSERT;

    Test.startTest();
    Rollup.countDistinctFromTrigger(Opportunity.AccountId, Account.Id, Account.AnnualRevenue, Account.SObjectType).runCalc();
    Test.stopTest();

    System.assertEquals(1, mock.Records.size(), 'Records should have been populated COUNT_DISTINCT AFTER_INSERT');
    Account updatedAcc = (Account) mock.Records[0];
    System.assertEquals(1, updatedAcc.AnnualRevenue, 'COUNT_DISTINCT AFTER_INSERT should simply add');
  }

  @isTest
  static void shouldCountFromTrigger() {
    DMLMock mock = getMock(new List<Opportunity>{ new Opportunity(Amount = 1) });
    Rollup.triggerContext = TriggerOperation.AFTER_INSERT;

    Test.startTest();
    Rollup.countFromTrigger(Opportunity.Amount, Opportunity.AccountId, Account.Id, Account.AnnualRevenue, Account.SObjectType).runCalc();
    Test.stopTest();

    System.assertEquals(1, mock.Records.size(), 'Records should have been populated COUNT AFTER_INSERT');
    Account updatedAcc = (Account) mock.Records[0];
    System.assertEquals(1, updatedAcc.AnnualRevenue, 'COUNT AFTER_INSERT should add when field is populated');
  }

  @isTest
  static void shouldRunSumFromTriggerBasedOnMetadata() {
    DMLMock mock = getMock(new List<Opportunity>{ new Opportunity(Amount = 100) });
    Rollup.rollupMetadata = new List<Rollup__mdt>{
      new Rollup__mdt(
        RollupFieldOnCalcItem__c = 'Amount',
        LookupObject__c = 'Account',
        LookupFieldOnCalcItem__c = 'AccountId',
        LookupFieldOnLookupObject__c = 'Id',
        RollupFieldOnLookupObject__c = 'AnnualRevenue',
        RollupType__c = 'SUM'
      )
    };
    Rollup.triggerContext = TriggerOperation.AFTER_INSERT;

    Test.startTest();
    Rollup.runFromTrigger();
    Test.stopTest();

    System.assertEquals(1, mock.Records.size(), 'Records should have been populated based on metadata AFTER_INSERT');
    Account updatedAcc = (Account) mock.Records[0];
    System.assertEquals(100, updatedAcc.AnnualRevenue, 'SUM AFTER_INSERT should add the original opportunity amount based on CMDT');
  }

  @isTest
  static void shouldRunMultipleOperationsWhenMoreMetadataIsPresent() {
    DMLMock mock = getMock(new List<Opportunity>{ new Opportunity(Amount = 100) });
    Rollup.rollupMetadata = new List<Rollup__mdt>{
      new Rollup__mdt(
        RollupFieldOnCalcItem__c = 'Amount',
        LookupObject__c = 'Account',
        LookupFieldOnCalcItem__c = 'AccountId',
        LookupFieldOnLookupObject__c = 'Id',
        RollupFieldOnLookupObject__c = 'AnnualRevenue',
        RollupType__c = 'COUNT'
      ),
      new Rollup__mdt(
        LookupObject__c = 'Account',
        LookupFieldOnCalcItem__c = 'AccountId',
        LookupFieldOnLookupObject__c = 'Id',
        RollupFieldOnLookupObject__c = 'NumberOfEmployees',
        RollupType__c = 'COUNT_DISTINCT'
      )
    };
    Rollup.triggerContext = TriggerOperation.AFTER_INSERT;

    Test.startTest();
    Rollup.runFromTrigger();
    Test.stopTest();

    System.assertEquals(1, mock.Records.size(), 'Records should have been populated based on metadata AFTER_INSERT');
    Account updatedAcc = (Account) mock.Records[0];
    System.assertEquals(1, updatedAcc.AnnualRevenue, 'COUNT AFTER_INSERT should count when the field is present on the calc item based on CMDT');
    System.assertEquals(1, updatedAcc.NumberOfEmployees, 'COUNT_DISTINCT AFTER_INSERT should count regardless of not pointing to a field based on CMDT');
  }

  @isTest
  static void shouldMaxNumbersSuccessfullyAfterInsert() {
    List<Opportunity> opps = new List<Opportunity>{
      new Opportunity(Amount = 100, Id = TestingUtils.generateId(Opportunity.SObjectType)),
      new Opportunity(Amount = 200, Id = TestingUtils.generateId(Opportunity.SObjectType))
    };
    DMLMock mock = getMock(opps);
    Rollup.triggerContext = TriggerOperation.AFTER_INSERT;

    Test.startTest();
    Rollup.maxFromTrigger(Opportunity.Amount, Opportunity.AccountId, Account.Id, Account.AnnualRevenue, Account.SObjectType).runCalc();
    Test.stopTest();

    System.assertEquals(1, mock.Records.size(), 'Records should have been populated MAX AFTER_INSERT');
    Account updatedAcc = (Account) mock.Records[0];
    System.assertEquals(200, updatedAcc.AnnualRevenue, 'MAX AFTER_INSERT should take the maximum opportunity amount');
  }

  @isTest
  static void shouldMaxNumbersSuccessfullyAfterUpdate() {
    List<Opportunity> opps = new List<Opportunity>{
      new Opportunity(Amount = 100, Id = TestingUtils.generateId(Opportunity.SObjectType)),
      new Opportunity(Amount = 200, Id = TestingUtils.generateId(Opportunity.SObjectType))
    };
    DMLMock mock = getMock(opps);
    Rollup.triggerContext = TriggerOperation.AFTER_UPDATE;
    Rollup.oldRecordsMap = new Map<Id, Opportunity>{ opps[0].Id => new Opportunity(Id = opps[0].Id), opps[1].Id => new Opportunity(Id = opps[1].Id) };

    Test.startTest();
    Rollup.maxFromTrigger(Opportunity.Amount, Opportunity.AccountId, Account.Id, Account.AnnualRevenue, Account.SObjectType).runCalc();
    Test.stopTest();

    System.assertEquals(1, mock.Records.size(), 'Records should have been populated MAX AFTER_UPDATE');
    Account updatedAcc = (Account) mock.Records[0];
    System.assertEquals(200, updatedAcc.AnnualRevenue, 'MAX AFTER_UPDATE should take the maximum opportunity amount');
  }

  @isTest
  static void shouldMaxNumbersSuccessfullyAfterUpdateWhenUpdatedItemIsNoLongerMax() {
    Account acc = [SELECT Id FROM Account];
    acc.AnnualRevenue = 250;
    update acc;

    Opportunity opp = new Opportunity(Amount = 250, AccountId = acc.Id, Name = 'testOpp', StageName = 'something', CloseDate = System.today());
    Opportunity secondOpp = new Opportunity(Amount = 175, AccountId = acc.Id, Name = 'testOppTwo', StageName = 'something', CloseDate = System.today());
    List<Opportunity> originalOpps = new List<Opportunity>{ opp, secondOpp };
    insert originalOpps;

    Opportunity updatedOpp = opp.clone(true, true);
    updatedOpp.Amount = 150;
    List<Opportunity> opps = new List<Opportunity>{ updatedOpp };
    Rollup.triggerRecords = opps;
    Rollup.oldRecordsMap = new Map<Id, Opportunity>(originalOpps);
    Rollup.shouldRun = true;
    DMLMock mock = new DMLMock();
    Rollup.DML = mock;
    Rollup.triggerContext = TriggerOperation.AFTER_UPDATE;

    Test.startTest();
    Rollup.maxFromTrigger(Opportunity.Amount, Opportunity.AccountId, Account.Id, Account.AnnualRevenue, Account.SObjectType).runCalc();
    Test.stopTest();

    System.assertEquals(1, mock.Records.size(), 'Records should have been populated MAX AFTER_UPDATE');
    Account updatedAcc = (Account) mock.Records[0];
    System.assertEquals(175, updatedAcc.AnnualRevenue, 'MAX AFTER_UPDATE should take the maximum opportunity amount');
  }

  @isTest
  static void shouldMaxNumbersSuccessfullyOnDeleteWhenDeletedItemIsNoLongerMax() {
    Account acc = [SELECT Id FROM Account];
    acc.AnnualRevenue = 250;
    update acc;

    Opportunity opp = new Opportunity(Amount = 250, AccountId = acc.Id, Name = 'testOpp', StageName = 'something', CloseDate = System.today());
    Opportunity secondOpp = new Opportunity(Amount = 175, AccountId = acc.Id, Name = 'testOppTwo', StageName = 'something', CloseDate = System.today());
    List<Opportunity> originalOpps = new List<Opportunity>{ opp, secondOpp };
    insert originalOpps;

    Rollup.triggerRecords = originalOpps;
    Rollup.oldRecordsMap = new Map<Id, Opportunity>(originalOpps);
    Rollup.shouldRun = true;
    DMLMock mock = new DMLMock();
    Rollup.DML = mock;
    Rollup.triggerContext = TriggerOperation.BEFORE_DELETE;

    Test.startTest();
    Rollup.maxFromTrigger(Opportunity.Amount, Opportunity.AccountId, Account.Id, Account.AnnualRevenue, Account.SObjectType).runCalc();
    Test.stopTest();

    System.assertEquals(1, mock.Records.size(), 'Records should have been populated MAX BEFORE_DELETE');
    Account updatedAcc = (Account) mock.Records[0];
    System.assertEquals(0, updatedAcc.AnnualRevenue, 'MAX BEFORE_DELETE should take the maximum opportunity amount');
  }

  // TODO: up till this point, we have been testing rollup functions using numeric types.
  // Now we test different field types for success: time, date, datetime, string, illegal arg

  /** Invocable tests */

  @isTest
  static void shouldBeInvokedSuccessfullyAfterInsertFromFlow() {
    List<Opportunity> opps = new List<Opportunity>{ new Opportunity(Amount = 1000) };
    DMLMock mock = getMock(opps);

    Test.startTest();
    List<Rollup.FlowOutput> flowOutputs = Rollup.performRollup(prepareFlowTest(opps, 'INSERT', 'SUM'));
    Test.stopTest();

    System.assertEquals(1, flowOutputs.size(), 'Flow ouputs were not provided');
    System.assertEquals('SUCCESS', flowOutputs[0].message);
    System.assertEquals(true, flowOutputs[0].isSuccess);

    System.assertEquals(1, mock.Records.size(), 'SUM AFTER_INSERT from flow did not update accounts');
    Account updatedAcc = (Account) mock.Records[0];
    System.assertEquals(1000, updatedAcc.AnnualRevenue, 'SUM AFTER_INSERT from flow should match input Amount');
  }

  @isTest
  static void shouldBeInvokedSuccessfullyAfterSaveFromFlow() {
    List<Opportunity> opps = new List<Opportunity>{ new Opportunity(Amount = 1000, Id = TestingUtils.generateId(Opportunity.SObjectType)) };
    DMLMock mock = getMock(opps);
    Rollup.oldRecordsMap = new Map<Id, Opportunity>{ opps[0].Id => new Opportunity(Id = opps[0].Id, Amount = 250) };

    Test.startTest();
    List<Rollup.FlowOutput> flowOutputs = Rollup.performRollup(prepareFlowTest(opps, 'UPDATE', 'SUM'));
    Test.stopTest();

    System.assertEquals(1, flowOutputs.size(), 'Flow ouputs were not provided');
    System.assertEquals('SUCCESS', flowOutputs[0].message);
    System.assertEquals(true, flowOutputs[0].isSuccess);

    System.assertEquals(1, mock.Records.size(), 'SUM AFTER_UPDATE from flow did not update accounts');
    Account updatedAcc = (Account) mock.Records[0];
    System.assertEquals(750, updatedAcc.AnnualRevenue, 'SUM AFTER_UPDATE from flow should match diff for Amount');
  }

  @isTest
  static void shouldBeInvokedSuccessfullyBeforeDeleteFromFlow() {
    List<Opportunity> opps = new List<Opportunity>{ new Opportunity(Amount = 1000) };
    DMLMock mock = getMock(opps);

    Test.startTest();
    List<Rollup.FlowOutput> flowOutputs = Rollup.performRollup(prepareFlowTest(opps, 'DELETE', 'SUM'));
    Test.stopTest();

    System.assertEquals(1, flowOutputs.size(), 'Flow ouputs were not provided');
    System.assertEquals('SUCCESS', flowOutputs[0].message);
    System.assertEquals(true, flowOutputs[0].isSuccess);

    System.assertEquals(1, mock.Records.size(), 'SUM BEFORE_DELETE from flow did not update accounts');
    Account updatedAcc = (Account) mock.Records[0];
    System.assertEquals(-1000, updatedAcc.AnnualRevenue, 'SUM BEFORE_DELETE from flow should subtract Amount from Account');
  }

  @isTest
  static void shouldOnlyIncludeObjectChangedFieldsWhenSuppliedFromFlow() {
    List<Opportunity> opps = new List<Opportunity>{
      new Opportunity(Amount = 1000, Name = 'Acme opp', Id = TestingUtils.generateId(Opportunity.SObjectType)),
      new Opportunity(Amount = 500, Name = 'Test name changed opp', Id = TestingUtils.generateId(Opportunity.SObjectType))
    };
    DMLMock mock = getMock(opps);

    Rollup.oldRecordsMap = new Map<Id, Opportunity>{
      opps[0].Id => new Opportunity(Id = opps[0].Id, Amount = 250, Name = opps[0].Name),
      opps[1].Id => new Opportunity(Id = opps[1].Id, Name = 'Name that does not match', Amount = 200)
    };

    List<Rollup.FlowInput> flowInputs = prepareFlowTest(opps, 'UPDATE', 'SUM');
    flowInputs[0].calcItemChangedFields = 'Name, StageName';

    Test.startTest();
    List<Rollup.FlowOutput> flowOutputs = Rollup.performRollup(flowInputs);
    Test.stopTest();

    System.assertEquals(1, flowOutputs.size(), 'Flow ouputs were not provided');
    System.assertEquals('SUCCESS', flowOutputs[0].message);
    System.assertEquals(true, flowOutputs[0].isSuccess);

    System.assertEquals(1, mock.Records.size(), 'SUM AFTER_UPDATE from flow did not update accounts');
    Account updatedAcc = (Account) mock.Records[0];
    System.assertEquals(
      300,
      updatedAcc.AnnualRevenue,
      'SUM AFTER_UPDATE from flow with changed fields should match diff for Amount based off of the Opp with Name changes'
    );
  }

  /** Batch test */

  @isTest
  static void shouldRunSuccessfullyAsBatch() {
    DMLMock mock = getMock(new List<Opportunity>{ new Opportunity(Amount = 1) });
    Rollup.triggerContext = TriggerOperation.AFTER_INSERT;
    Rollup.shouldRunAsBatch = true;

    Test.startTest();
    Rollup.countFromTrigger(Opportunity.Amount, Opportunity.AccountId, Account.Id, Account.AnnualRevenue, Account.SObjectType).runCalc();
    Test.stopTest();

    System.assertEquals(1, mock.Records.size(), 'Records should have been populated COUNT AFTER_INSERT');
    Account updatedAcc = (Account) mock.Records[0];
    System.assertEquals(1, updatedAcc.AnnualRevenue, 'COUNT AFTER_INSERT should add when field is populated');
    // validate that job ran as batch
    System.assertEquals('Completed', [SELECT Status FROM AsyncApexJob WHERE JobType = 'BatchApexWorker'].Status);
  }

  //** Helpers */

  private static DMLMock getMock(List<SObject> records) {
    Account acc = [SELECT Id FROM Account];
    for (SObject record : records) {
      record.put('AccountId', acc.Id);
    }

    Rollup.triggerRecords = records;
    Rollup.shouldRun = true;
    DMLMock mock = new DMLMock();
    Rollup.DML = mock;

    return mock;
  }

  private static List<Rollup.FlowInput> prepareFlowTest(List<SObject> records, String rollupContext, String rollupOperation) {
    Rollup.triggerRecords = null; // just to ensure this is coming from the correct place

    Rollup.FlowInput flowInput = new Rollup.FlowInput();
    flowInput.recordsToRollup = records;
    flowInput.lookupFieldOnCalcItem = 'AccountId';
    flowInput.lookupFieldOnOpObject = 'Id';
    flowInput.rollupContext = rollupContext;
    flowInput.rollupFieldOnCalcItem = 'Amount';
    flowInput.rollupFieldOnOpObject = 'AnnualRevenue';
    flowInput.rollupSObjectName = 'Account';
    flowInput.rollupOperation = rollupOperation;

    return new List<Rollup.FlowInput>{ flowInput };
  }
}
