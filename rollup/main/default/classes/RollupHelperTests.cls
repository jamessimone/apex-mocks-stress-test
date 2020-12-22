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
  static void shouldDeferRollupsTillRunCalcCalledForNonBatch() {
    Account acc = [SELECT Id FROM Account];

    RollupHelper.triggerRecords = new List<Opportunity>{ new Opportunity(Amount = 50, AccountId = acc.Id) };
    RollupHelper.shouldRun = true;
    RollupHelper.triggerContext = TriggerOperation.AFTER_INSERT;
    DMLMock mock = new DMLMock();
    RollupHelper.DML = mock;

    RollupHelper rollup = RollupHelper.sumFromTrigger(
      Opportunity.Amount,
      Opportunity.AccountId,
      Account.Id,
      Account.AnnualRevenue,
      Account.SObjectType
    );

    System.assertEquals(null, mock.Records);

    Test.startTest();
    rollup.runCalc();
    Test.stopTest();

    System.assertEquals(1, mock.Records.size());
    Account updatedAcc = (Account) mock.Records[0];
    System.assertEquals(50, updatedAcc.AnnualRevenue);
  }
}
