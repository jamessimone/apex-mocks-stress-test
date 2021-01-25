@isTest
private class DataProcessorTests {
  @TestSetup
  static void setup() {
    insert new Account(Name = ACCOUNT_NAME);
  }

  @isTest
  static void it_should_run_as_queueable_for_small_record_sizes() {
    runTest();
    System.assertEquals('Completed', [SELECT Status FROM AsyncApexJob WHERE JobType = 'Queueable'].Status);
    //ensure batch didn't also run
    System.assertEquals(0, [SELECT Id FROM AsyncApexJob WHERE JobType = 'BatchApexWorker'].size());
  }

  @isTest
  static void it_should_run_as_batchable_when_instructed_to() {
    batchable = true;
    runTest();
    System.assertEquals('Completed', [SELECT Status FROM AsyncApexJob WHERE JobType = 'BatchApexWorker'].Status);
    //ensure queueable didn't also run
    System.assertEquals(0, [SELECT Id FROM AsyncApexJob WHERE JobType = 'Queueable'].size());
  }

  static void runTest() {
    Test.startTest();
    new TestAccountProcessor(Factory.getFactory()).process();
    Test.stopTest();

    Account updatedAccount = [SELECT Name FROM Account];
    System.assertEquals(ACCOUNT_NAME + ' TestAccountProcessor', updatedAccount.Name);
    System.assertEquals(true, finished);
  }

  static Boolean batchable = false;
  static Boolean finished = false;
  static String ACCOUNT_NAME = 'Hi';

  private class TestAccountProcessor extends DataProcessor {
    private final IRepository accountRepo;
    public TestAccountProcessor(Factory factory) {
      super(factory);
      this.accountRepo = factory.RepoFactory.getAccountRepo();
    }

    protected override QueryWrapper getWrapper() {
      return this.accountRepo.getWrapper(
        new Query(Account.Name, Query.Operator.EQUALS, ACCOUNT_NAME)
      );
    }

    protected override void execute(List<SObject> records) {
      List<Account> accounts = (List<Account>) records;
      for(Account acc : accounts) {
        acc.Name = acc.Name + ' TestAccountProcessor';
      }
      this.accountRepo.doUpdate(accounts);
    }

    protected override void finish() {
      finished = true;
    }

    protected override Boolean isBatchable() {
      return !batchable ? super.isBatchable() : batchable;
    }
  }
}