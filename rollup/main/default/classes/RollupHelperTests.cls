@isTest
private class RollupHelperTests {
  @TestSetup
  static void setup() {
    insert new Account(Name = 'RollupHelperTests');
  }

  private class DMLMock extends RollupHelper.DMLHelper {
    public List<SObject> Records { get; private set; }
    public override void doUpdate(List<SObject> recordsToUpdate) {
      this.Records = recordsToUpdate;
    }
  }

  @isTest
  static void shouldSumFromTriggerAfterInsert() {
    DMLMock mock = getMock(new List<Opportunity>{ new Opportunity(Amount = 50) });
    RollupHelper.triggerContext = TriggerOperation.AFTER_INSERT;

    RollupHelper rollup = RollupHelper.sumFromTrigger(Opportunity.Amount, Opportunity.AccountId, Account.Id, Account.AnnualRevenue, Account.SObjectType);

    System.assertEquals(null, mock.Records);

    Test.startTest();
    rollup.runCalc();
    Test.stopTest();

    System.assertEquals(1, mock.Records.size());
    Account updatedAcc = (Account) mock.Records[0];
    System.assertEquals(50, updatedAcc.AnnualRevenue);
  }

  @isTest
  static void shouldSumFromTriggerAfterUpdate() {
    Opportunity opp = new Opportunity(Id = TestingUtils.generateId(Opportunity.SObjectType), Amount = 50);
    DMLMock mock = getMock(new List<Opportunity>{ opp });

    RollupHelper.oldRecordsMap = new Map<Id, Opportunity>{ opp.Id => new Opportunity(Amount = 25) };
    RollupHelper.triggerContext = TriggerOperation.AFTER_UPDATE;

    Test.startTest();
    RollupHelper.sumFromTrigger(Opportunity.Amount, Opportunity.AccountId, Account.Id, Account.AnnualRevenue, Account.SObjectType).runCalc();
    Test.stopTest();

    System.assertEquals(1, mock.Records.size());
    Account updatedAcc = (Account) mock.Records[0];
    System.assertEquals(25, updatedAcc.AnnualRevenue);
  }

  private static DMLMock getMock(List<SObject> records) {
    Account acc = [SELECT Id FROM Account];
    for (SObject record : records) {
      record.put('AccountId', acc.Id);
    }

    RollupHelper.triggerRecords = records;
    RollupHelper.shouldRun = true;
    DMLMock mock = new DMLMock();
    RollupHelper.DML = mock;

    return mock;
  }
}
