@isTest
private class RollupTests {
  @TestSetup
  static void setup() {
    insert new Account(Name = 'RollupTests');
  }

  private class DMLMock extends Rollup.DMLHelper {
    public List<SObject> Records = new List<SObject>();
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
  static void shouldBatchTwoOperations() {
    DMLMock mock = getMock(new List<Opportunity>{ new Opportunity(Amount = 100) });
    Rollup.triggerContext = TriggerOperation.AFTER_INSERT;

    Test.startTest();
    Rollup.batch(
      Rollup.countDistinctFromTrigger(Opportunity.AccountId, Account.Id, Account.NumberOfEmployees, Account.SObjectType),
      Rollup.sumFromTrigger(Opportunity.Amount, Opportunity.AccountId, Account.Id, Account.AnnualRevenue, Account.SObjectType)
    );
    Test.stopTest();

    System.assertEquals(1, mock.Records.size(), 'Records should have been populated batch AFTER_INSERT');
    Account updatedAcc = (Account) mock.Records[0];
    System.assertEquals(100, updatedAcc.AnnualRevenue, 'SUM AFTER_INSERT should count when the field is present on the calc item batched');
    System.assertEquals(
      1,
      updatedAcc.NumberOfEmployees,
      'COUNT_DISTINCT AFTER_INSERT should count regardless of not pointing to a field based on the batch operation'
    );
  }

  @isTest
  static void shouldBatchThreeOperations() {
    DMLMock mock = getMock(new List<Opportunity>{ new Opportunity(Amount = 100, Name = 'My test name') });
    Rollup.triggerContext = TriggerOperation.AFTER_INSERT;

    Test.startTest();
    Rollup.batch(
      Rollup.countDistinctFromTrigger(Opportunity.AccountId, Account.Id, Account.NumberOfEmployees, Account.SObjectType),
      Rollup.sumFromTrigger(Opportunity.Amount, Opportunity.AccountId, Account.Id, Account.AnnualRevenue, Account.SObjectType),
      Rollup.concatFromTrigger(Opportunity.Name, Opportunity.AccountId, Account.Id, Account.AccountNumber, Account.SObjectType)
    );
    Test.stopTest();

    System.assertEquals(1, mock.Records.size(), 'Records should have been populated batch AFTER_INSERT');
    Account updatedAcc = (Account) mock.Records[0];
    System.assertEquals(100, updatedAcc.AnnualRevenue, 'SUM AFTER_INSERT should count when the field is present on the calc item batched');
    System.assertEquals(
      1,
      updatedAcc.NumberOfEmployees,
      'COUNT_DISTINCT AFTER_INSERT should count regardless of not pointing to a field based on the batch operation'
    );
    System.assertEquals('My test name', updatedAcc.AccountNumber);
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

    Opportunity opp = new Opportunity(Amount = acc.AnnualRevenue, AccountId = acc.Id, Name = 'testOpp', StageName = 'something', CloseDate = System.today());
    Opportunity secondOpp = new Opportunity(Amount = 175, AccountId = acc.Id, Name = 'testOppTwo', StageName = 'something', CloseDate = System.today());
    List<Opportunity> originalOpps = new List<Opportunity>{ opp, secondOpp };
    insert originalOpps;

    Opportunity updatedOpp = opp.clone(true, true);
    updatedOpp.Amount = 150;
    List<Opportunity> opps = new List<Opportunity>{ updatedOpp };
    Rollup.records = opps;
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
    System.assertEquals(secondOpp.Amount, updatedAcc.AnnualRevenue, 'MAX AFTER_UPDATE should take the maximum opportunity amount');
  }

  @isTest
  static void shouldTakeIntoAccountInMemorySObjectsWhenUpdatedItemIsNoLongerMax() {
    Account acc = [SELECT Id FROM Account];
    acc.AnnualRevenue = 250;
    update acc;

    Opportunity opp = new Opportunity(Amount = acc.AnnualRevenue, AccountId = acc.Id, Name = 'testOpp', StageName = 'something', CloseDate = System.today());
    Opportunity secondOpp = new Opportunity(Amount = 175, AccountId = acc.Id, Name = 'testOppTwo', StageName = 'something', CloseDate = System.today());
    List<Opportunity> originalOpps = new List<Opportunity>{ opp, secondOpp };
    insert originalOpps;

    Opportunity updatedOpp = opp.clone(true, true);
    updatedOpp.Amount = 150;
    Opportunity updatedSecondOpp = secondOpp.clone(true, true);
    updatedSecondOpp.Amount = secondOpp.Amount + 30; // the amount is really unimportant; that it doesn't match what's in the database is
    List<Opportunity> opps = new List<Opportunity>{ updatedOpp, updatedSecondOpp };
    Rollup.records = opps;
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
    System.assertEquals(updatedSecondOpp.Amount, updatedAcc.AnnualRevenue, 'MAX AFTER_UPDATE should take the maximum opportunity amount');
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

    Rollup.records = originalOpps;
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

  @isTest
  static void shouldMinNumbersSuccessfullyAfterInsert() {
    List<Opportunity> opps = new List<Opportunity>{
      new Opportunity(Amount = 100, Id = TestingUtils.generateId(Opportunity.SObjectType)),
      new Opportunity(Amount = 200, Id = TestingUtils.generateId(Opportunity.SObjectType))
    };
    DMLMock mock = getMock(opps);
    Rollup.triggerContext = TriggerOperation.AFTER_INSERT;

    Test.startTest();
    Rollup.minFromTrigger(Opportunity.Amount, Opportunity.AccountId, Account.Id, Account.AnnualRevenue, Account.SObjectType).runCalc();
    Test.stopTest();

    System.assertEquals(1, mock.Records.size(), 'Records should have been populated MIN AFTER_INSERT');
    Account updatedAcc = (Account) mock.Records[0];
    System.assertEquals(100, updatedAcc.AnnualRevenue, 'MIN AFTER_INSERT should take the minimum opportunity amount');
  }

  @isTest
  static void shouldMinNumbersSuccessfullyAfterUpdate() {
    List<Opportunity> opps = new List<Opportunity>{
      new Opportunity(Amount = 100, Id = TestingUtils.generateId(Opportunity.SObjectType)),
      new Opportunity(Amount = 200, Id = TestingUtils.generateId(Opportunity.SObjectType))
    };
    DMLMock mock = getMock(opps);
    Rollup.triggerContext = TriggerOperation.AFTER_UPDATE;
    Rollup.oldRecordsMap = new Map<Id, Opportunity>{ opps[0].Id => new Opportunity(Id = opps[0].Id), opps[1].Id => new Opportunity(Id = opps[1].Id) };

    Test.startTest();
    Rollup.minFromTrigger(Opportunity.Amount, Opportunity.AccountId, Account.Id, Account.AnnualRevenue, Account.SObjectType).runCalc();
    Test.stopTest();

    System.assertEquals(1, mock.Records.size(), 'Records should have been populated MIN AFTER_UPDATE');
    Account updatedAcc = (Account) mock.Records[0];
    System.assertEquals(100, updatedAcc.AnnualRevenue, 'MIN AFTER_UPDATE should take the minimum opportunity amount');
  }

  @isTest
  static void shouldMinNumbersSuccessfullyAfterUpdateWhenUpdatedItemIsNoLongerMin() {
    Account acc = [SELECT Id FROM Account];
    acc.AnnualRevenue = 150;
    update acc;

    Opportunity opp = new Opportunity(Amount = 150, AccountId = acc.Id, Name = 'testOpp', StageName = 'something', CloseDate = System.today());
    Opportunity secondOpp = new Opportunity(Amount = 175, AccountId = acc.Id, Name = 'testOppTwo', StageName = 'something', CloseDate = System.today());
    List<Opportunity> originalOpps = new List<Opportunity>{ opp, secondOpp };
    insert originalOpps;

    Opportunity updatedOpp = opp.clone(true, true);
    updatedOpp.Amount = 200;
    List<Opportunity> opps = new List<Opportunity>{ updatedOpp };
    Rollup.records = opps;
    Rollup.oldRecordsMap = new Map<Id, Opportunity>(originalOpps);
    Rollup.shouldRun = true;
    DMLMock mock = new DMLMock();
    Rollup.DML = mock;
    Rollup.triggerContext = TriggerOperation.AFTER_UPDATE;

    Test.startTest();
    Rollup.minFromTrigger(Opportunity.Amount, Opportunity.AccountId, Account.Id, Account.AnnualRevenue, Account.SObjectType).runCalc();
    Test.stopTest();

    System.assertEquals(1, mock.Records.size(), 'Records should have been populated MIN AFTER_UPDATE');
    Account updatedAcc = (Account) mock.Records[0];
    System.assertEquals(175, updatedAcc.AnnualRevenue, 'MIN AFTER_UPDATE should take the minimum opportunity amount');
  }

  @isTest
  static void shouldTakeIntoAccountInMemorySObjectsWhenUpdatedItemIsNoLongerMin() {
    Account acc = [SELECT Id FROM Account];
    acc.AnnualRevenue = 150;
    update acc;

    Opportunity opp = new Opportunity(Amount = acc.AnnualRevenue, AccountId = acc.Id, Name = 'testOpp', StageName = 'something', CloseDate = System.today());
    Opportunity secondOpp = new Opportunity(Amount = 175, AccountId = acc.Id, Name = 'testOppTwo', StageName = 'something', CloseDate = System.today());
    List<Opportunity> originalOpps = new List<Opportunity>{ opp, secondOpp };
    insert originalOpps;

    Opportunity updatedOpp = opp.clone(true, true);
    updatedOpp.Amount = 150;
    Opportunity updatedSecondOpp = secondOpp.clone(true, true);
    updatedSecondOpp.Amount = secondOpp.Amount - 30; // the amount is really unimportant; that it doesn't match what's in the database is
    List<Opportunity> opps = new List<Opportunity>{ updatedOpp, updatedSecondOpp };
    Rollup.records = opps;
    Rollup.oldRecordsMap = new Map<Id, Opportunity>(originalOpps);
    Rollup.shouldRun = true;
    DMLMock mock = new DMLMock();
    Rollup.DML = mock;
    Rollup.triggerContext = TriggerOperation.AFTER_UPDATE;

    Test.startTest();
    Rollup.minFromTrigger(Opportunity.Amount, Opportunity.AccountId, Account.Id, Account.AnnualRevenue, Account.SObjectType).runCalc();
    Test.stopTest();

    System.assertEquals(1, mock.Records.size(), 'Records should have been populated MIN AFTER_UPDATE');
    Account updatedAcc = (Account) mock.Records[0];
    System.assertEquals(updatedSecondOpp.Amount, updatedAcc.AnnualRevenue, 'MIN AFTER_UPDATE should take the min opportunity amount');
  }

  @isTest
  static void shouldMinNumbersSuccessfullyOnDeleteWhenDeletedItemIsNoLongerMax() {
    Account acc = [SELECT Id FROM Account];
    acc.AnnualRevenue = 150;
    update acc;

    Opportunity opp = new Opportunity(Amount = 150, AccountId = acc.Id, Name = 'testOpp', StageName = 'something', CloseDate = System.today());
    Opportunity secondOpp = new Opportunity(Amount = 175, AccountId = acc.Id, Name = 'testOppTwo', StageName = 'something', CloseDate = System.today());
    List<Opportunity> originalOpps = new List<Opportunity>{ opp, secondOpp };
    insert originalOpps;

    Rollup.records = new List<Opportunity>{ opp };
    Rollup.oldRecordsMap = new Map<Id, SObject>(Rollup.records);
    Rollup.shouldRun = true;
    DMLMock mock = new DMLMock();
    Rollup.DML = mock;
    Rollup.triggerContext = TriggerOperation.BEFORE_DELETE;

    Test.startTest();
    Rollup.minFromTrigger(Opportunity.Amount, Opportunity.AccountId, Account.Id, Account.AnnualRevenue, Account.SObjectType).runCalc();
    Test.stopTest();

    System.assertEquals(1, mock.Records.size(), 'Records should have been populated MIN BEFORE_DELETE');
    Account updatedAcc = (Account) mock.Records[0];
    System.assertEquals(175, updatedAcc.AnnualRevenue, 'MIN BEFORE_DELETE should take the minimum opportunity amount');
  }

  @isTest
  static void shouldConcatOnUpdate() {
    // AFTER_INSERT test is handled in the "shouldBatchThreeOperations" method
    Account acc = [SELECT Id, AccountNumber FROM Account];
    acc.AccountNumber = 'first test string';
    update acc;

    Opportunity opp = new Opportunity(AccountId = acc.Id, Name = 'second test string', Id = TestingUtils.generateId(Opportunity.SObjectType));
    Opportunity oldOpp = opp.clone(true, true);
    oldOpp.Name = acc.AccountNumber;

    DMLMock mock = getMock(new List<Opportunity>{ opp });
    Rollup.oldRecordsMap = new Map<Id, SObject>{ oldOpp.Id => oldOpp };
    Rollup.triggerContext = TriggerOperation.AFTER_UPDATE;

    Test.startTest();
    Rollup.concatFromTrigger(Opportunity.Name, Opportunity.AccountId, Account.Id, Account.AccountNumber, Account.SObjectType).runCalc();
    Test.stopTest();

    System.assertEquals(1, mock.Records.size(), 'Records should have been populated CONCAT AFTER_UPDATE');
    Account updatedAcc = (Account) mock.Records[0];
    System.assertEquals(opp.Name, updatedAcc.AccountNumber, 'CONCAT AFTER_UPDATE should replace the old string value with the new');
  }

  @isTest
  static void shouldConcatOnDelete() {
    Account acc = [SELECT Id, AccountNumber FROM Account];
    acc.AccountNumber = 'beginning test string something';
    update acc;

    Opportunity opp = new Opportunity(AccountId = acc.Id, Name = 'test string');
    DMLMock mock = getMock(new List<Opportunity>{ opp });
    Rollup.triggerContext = TriggerOperation.BEFORE_DELETE;

    Test.startTest();
    Rollup.concatFromTrigger(Opportunity.Name, Opportunity.AccountId, Account.Id, Account.AccountNumber, Account.SObjectType).runCalc();
    Test.stopTest();

    System.assertEquals(1, mock.Records.size(), 'Records should have been populated CONCAT BEFORE_DELETE');
    Account updatedAcc = (Account) mock.Records[0];
    System.assertEquals('beginning something', updatedAcc.AccountNumber, 'CONCAT BEFORE_DELETE should replace the outgoing string value with empty string');
  }

  @isTest
  static void shouldAverageOnInsert() {
    // average is a special case; even on insert, we have to also check for pre-existing records existing
    Account acc = [SELECT Id, AnnualRevenue FROM Account];
    acc.AnnualRevenue = 150000;
    update acc;

    Opportunity testOpp = new Opportunity(Amount = 100, Name = 'Pre-existing', StageName = 'random', CloseDate = System.today(), AccountId = acc.Id);
    insert testOpp;

    List<Opportunity> opps = new List<Opportunity>{
      new Opportunity(Amount = 200000, Id = TestingUtils.generateId(Opportunity.SObjectType)),
      new Opportunity(Amount = 200000, Id = TestingUtils.generateId(Opportunity.SObjectType))
    };
    DMLMock mock = getMock(opps);
    Rollup.triggerContext = TriggerOperation.AFTER_INSERT;

    Test.startTest();
    Rollup.averageFromTrigger(Opportunity.Amount, Opportunity.AccountId, Account.Id, Account.AnnualRevenue, Account.SObjectType).runCalc();
    Test.stopTest();

    System.assertEquals(1, mock.Records.size(), 'Records should have been populated AVERAGE AFTER_INSERT');
    Account updatedAcc = (Account) mock.Records[0];
    System.assertEquals(
      (testOpp.Amount + opps[0].Amount + opps[1].Amount) / 3,
      updatedAcc.AnnualRevenue,
      'AVERAGE AFTER_INSERT should take into account all values'
    );
  }

  @isTest
  static void shouldAverageOnUpdate() {
    Account acc = [SELECT Id FROM Account];

    Opportunity testOpp = new Opportunity(Amount = 100, Name = 'Pre-existing', StageName = 'random', CloseDate = System.today(), AccountId = acc.Id);
    insert testOpp;

    List<Opportunity> opps = new List<Opportunity>{
      new Opportunity(Amount = 200000, Id = TestingUtils.generateId(Opportunity.SObjectType)),
      new Opportunity(Amount = 200000, Id = TestingUtils.generateId(Opportunity.SObjectType))
    };
    DMLMock mock = getMock(opps);
    Rollup.triggerContext = TriggerOperation.AFTER_UPDATE;
    Rollup.oldRecordsMap = new Map<Id, Opportunity>{
      opps[0].Id => new Opportunity(Amount = 100000, Id = opps[0].Id),
      opps[1].Id => new Opportunity(Amount = 100000, Id = opps[1].Id)
    };

    Test.startTest();
    Rollup.averageFromTrigger(Opportunity.Amount, Opportunity.AccountId, Account.Id, Account.AnnualRevenue, Account.SObjectType).runCalc();
    Test.stopTest();

    System.assertEquals(1, mock.Records.size(), 'Records should have been populated AVERAGE AFTER_UPDATE');
    Account updatedAcc = (Account) mock.Records[0];
    System.assertEquals(
      (testOpp.Amount + opps[0].Amount + opps[1].Amount) / 3,
      updatedAcc.AnnualRevenue,
      'AVERAGE AFTER_UPDATE should take into account all values, including those from memory'
    );
  }

  @isTest
  static void shouldAverageOnDelete() {
    Account acc = [SELECT Id FROM Account];

    Opportunity testOpp = new Opportunity(Amount = 100, Name = 'Pre-existing', StageName = 'random', CloseDate = System.today(), AccountId = acc.Id);
    insert testOpp;

    List<Opportunity> opps = new List<Opportunity>{
      new Opportunity(Amount = 200000, Id = TestingUtils.generateId(Opportunity.SObjectType)),
      new Opportunity(Amount = 200000, Id = TestingUtils.generateId(Opportunity.SObjectType))
    };
    DMLMock mock = getMock(opps);
    Rollup.triggerContext = TriggerOperation.BEFORE_DELETE;
    Rollup.oldRecordsMap = new Map<Id, Opportunity>{
      opps[0].Id => new Opportunity(Amount = 100000, Id = opps[0].Id),
      opps[1].Id => new Opportunity(Amount = 100000, Id = opps[1].Id)
    };

    Test.startTest();
    Rollup.averageFromTrigger(Opportunity.Amount, Opportunity.AccountId, Account.Id, Account.AnnualRevenue, Account.SObjectType).runCalc();
    Test.stopTest();

    System.assertEquals(1, mock.Records.size(), 'Records should have been populated AVERAGE BEFORE_DELETE');
    Account updatedAcc = (Account) mock.Records[0];
    System.assertEquals(testOpp.Amount, updatedAcc.AnnualRevenue, 'AVERAGE BEFORE_DELETE should take into account only non-deleted values');
  }

  // Now we test different field types for success: time, date, datetime, illegal arg

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

  @isTest
  static void shouldReportSuccessWhenFlowPassesNoRecords() {
    List<Opportunity> opps = new List<Opportunity>();
    Rollup.shouldRun = true;
    Rollup.records = opps;

    Test.startTest();
    List<Rollup.FlowOutput> flowOutputs = Rollup.performRollup(prepareFlowTest(opps, 'INSERT', 'SUM'));
    Test.stopTest();

    System.assertEquals(1, flowOutputs.size(), 'Flow ouputs were not provided');
    System.assertEquals(true, flowOutputs[0].isSuccess);
  }

  @isTest
  static void shouldReportFailureWhenExceptionIsThrown() {
    List<OpportunityHistory> history = new List<OpportunityHistory>{ new OpportunityHistory() };
    Rollup.shouldRun = true;
    Rollup.records = history;

    Test.startTest();
    // prepareFlowTest sets us up for a failure with a field that doesn't exist on OpportunityHistory
    List<Rollup.FlowOutput> flowOutputs = Rollup.performRollup(prepareFlowTest(history, 'INSERT', 'SUM'));
    Test.stopTest();

    System.assertEquals(1, flowOutputs.size(), 'Flow ouputs were not provided');
    System.assertEquals(false, flowOutputs[0].isSuccess);
  }

  @isTest
  static void shouldReturnEmptyIfFlowIsNotRunning() {
    Test.startTest();
    List<Rollup.FlowOutput> flowOutputs = Rollup.performRollup(prepareFlowTest(new List<SObject>(), 'INSERT', 'SUM'));
    Test.stopTest();

    System.assertEquals(0, flowOutputs.size());
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

    Rollup.records = records;
    Rollup.shouldRun = true;
    DMLMock mock = new DMLMock();
    Rollup.DML = mock;

    return mock;
  }

  private static List<Rollup.FlowInput> prepareFlowTest(List<SObject> records, String rollupContext, String rollupOperation) {
    Rollup.records = null; // just to ensure this is coming from the correct place

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
