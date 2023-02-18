@IsTest
private class ApexRollupTests {
  @TestSetup
  static void setup() {
    upsert new RollupSettings__c(IsEnabled__c = true);
  }

  @IsTest
  static void it_properly_calls_apex_rollup() {
    Opportunity opp = new Opportunity(StageName = 'One', CloseDate = System.today(), Name = 'Example integration');
    insert opp;
    Set<System.TriggerOperation> expectedOperations = new Set<System.TriggerOperation>{ System.TriggerOperation.AFTER_INSERT };

    Assert.areEqual(expectedOperations, Rollup.CACHED_APEX_OPERATIONS.get(Opportunity.SObjectType));

    opp.StageName = 'Updated';
    update opp;

    expectedOperations.add(System.TriggerOperation.AFTER_UPDATE);
    Assert.areEqual(expectedOperations, Rollup.CACHED_APEX_OPERATIONS.get(Opportunity.SObjectType));

    delete opp;

    expectedOperations.add(System.TriggerOperation.BEFORE_DELETE);
    Assert.areEqual(expectedOperations, Rollup.CACHED_APEX_OPERATIONS.get(Opportunity.SObjectType));
  }

  @IsTest
  static void it_concatenates_opp_names_to_account_field() {
    Account parent = new Account(Id = TestingUtils.generateId(Account.SObjectType));
    List<Opportunity> opps = new List<Opportunity>{
      new Opportunity(AccountId = parent.Id, Name = 'One'),
      new Opportunity(AccountId = parent.Id, Name = 'Two'),
      new Opportunity(AccountId = parent.Id, Name = 'Three')
    };

    runTest(parent, opps, null, System.TriggerOperation.AFTER_INSERT);

    Assert.areEqual('One, Three, Two', parent.Concat_All_Opp_Names__c);
  }

  @IsTest
  static void it_maxes_last_modified_date_properly() {
    Account parent = new Account(Id = TestingUtils.generateId(Account.SObjectType));
    Datetime expectedMax = System.now().addDays(10);
    List<Opportunity> opps = new List<Opportunity>{
      (Opportunity) setReadOnlyField(
        Opportunity.LastModifiedDate,
        new Opportunity(AccountId = parent.Id, Name = 'One'),
        expectedMax.addDays(-10)
      ),
      (Opportunity) setReadOnlyField(Opportunity.LastModifiedDate, new Opportunity(AccountId = parent.Id, Name = 'Two'), expectedMax),
      (Opportunity) setReadOnlyField(
        Opportunity.LastModifiedDate,
        new Opportunity(AccountId = parent.Id, Name = 'Three'),
        expectedMax.addDays(-2)
      )
    };

    runTest(parent, opps, null, System.TriggerOperation.AFTER_INSERT);

    Assert.areEqual(expectedMax, parent.Max_Opp_Last_Modified_Datetime__c);
  }

  @IsTest
  static void it_minimizes_created_date_properly() {
    Account parent = new Account(Id = TestingUtils.generateId(Account.SObjectType));
    Datetime expectedMin = System.now().addDays(10);
    List<Opportunity> opps = new List<Opportunity>{
      (Opportunity) setReadOnlyField(
        Opportunity.CreatedDate,
        new Opportunity(AccountId = parent.Id, Name = 'One'),
        expectedMin.addDays(10)
      ),
      (Opportunity) setReadOnlyField(Opportunity.CreatedDate, new Opportunity(AccountId = parent.Id, Name = 'Two'), expectedMin),
      (Opportunity) setReadOnlyField(
        Opportunity.CreatedDate,
        new Opportunity(AccountId = parent.Id, Name = 'Three'),
        expectedMin.addDays(2)
      )
    };

    runTest(parent, opps, null, System.TriggerOperation.AFTER_INSERT);

    Assert.areEqual(expectedMin, parent.Min_Opp_Created_Datetime__c);
  }

  @IsTest
  static void it_counts_opportunities_at_account_level() {
    Account parent = new Account(Id = TestingUtils.generateId(Account.SObjectType));
    List<Opportunity> opps = new List<Opportunity>{
      new Opportunity(AccountId = parent.Id, Name = 'One', StageName = 'Prospecting'),
      new Opportunity(AccountId = parent.Id, Name = 'Two', StageName = 'Prospecting'),
      new Opportunity(AccountId = parent.Id, Name = 'Three')
    };

    runTest(parent, opps, null, System.TriggerOperation.AFTER_INSERT);

    Assert.areEqual(2, parent.Count_Of_Opps__c);
  }

  @IsTest
  static void it_sums_opp_amount_to_account_level() {
    Account parent = new Account(Id = TestingUtils.generateId(Account.SObjectType));
    List<Opportunity> opps = new List<Opportunity>{
      new Opportunity(AccountId = parent.Id, Name = 'One', Amount = 50),
      new Opportunity(AccountId = parent.Id, Name = 'Two', Amount = 50),
      new Opportunity(AccountId = parent.Id, Name = 'Three')
    };

    runTest(parent, opps, null, System.TriggerOperation.AFTER_INSERT);

    Assert.areEqual(opps[0].Amount + opps[1].Amount, parent.Sum_Opp_Amount__c);
  }

  @IsTest
  static void it_flags_account_as_having_third_in_stage_name() {
    Account parent = new Account(Id = TestingUtils.generateId(Account.SObjectType));
    List<Opportunity> opps = new List<Opportunity>{
      new Opportunity(AccountId = parent.Id, Name = 'One', StageName = 'Needs Analysis'),
      new Opportunity(AccountId = parent.Id, Name = 'Two'),
      new Opportunity(AccountId = parent.Id, Name = 'Three')
    };

    runTest(parent, opps, null, System.TriggerOperation.AFTER_INSERT);

    Assert.areEqual(true, parent.Does_Opp_Name_Contain_Keyword__c);
  }

  @IsTest
  static void it_disables_flag_on_account_when_no_third_in_stage_name_on_update() {
    Account parent = new Account(Id = TestingUtils.generateId(Account.SObjectType), Does_Opp_Name_Contain_Keyword__c = true);
    List<Opportunity> opps = new List<Opportunity>{
      new Opportunity(Id = TestingUtils.generateId(Opportunity.SObjectType), AccountId = parent.Id, Name = 'One'),
      new Opportunity(AccountId = parent.Id, Name = 'Two'),
      new Opportunity(AccountId = parent.Id, Name = 'Three')
    };

    runTest(
      parent,
      opps,
      new Map<Id, SObject>{
        opps[0].Id => new Opportunity(AccountId = parent.Id, Name = 'One', StageName = 'Needs Analysis', Id = opps[0].Id)
      },
      System.TriggerOperation.AFTER_UPDATE
    );

    Assert.areEqual(false, parent.Does_Opp_Name_Contain_Keyword__c);
  }

  @IsTest
  static void it_enables_flag_on_account_when_third_in_stage_name_on_update() {
    Account parent = new Account(Id = TestingUtils.generateId(Account.SObjectType), Does_Opp_Name_Contain_Keyword__c = false);
    List<Opportunity> opps = new List<Opportunity>{
      new Opportunity(
        Id = TestingUtils.generateId(Opportunity.SObjectType),
        AccountId = parent.Id,
        Name = 'One',
        StageName = 'Needs Analysis'
      ),
      new Opportunity(AccountId = parent.Id, Name = 'Two'),
      new Opportunity(AccountId = parent.Id, Name = 'Three')
    };

    runTest(
      parent,
      opps,
      new Map<Id, SObject>{ opps[0].Id => new Opportunity(AccountId = parent.Id, Name = 'One', Id = opps[0].Id) },
      System.TriggerOperation.AFTER_UPDATE
    );

    Assert.areEqual(true, parent.Does_Opp_Name_Contain_Keyword__c);
  }

  @IsTest
  static void it_does_not_flag_account_as_having_third_in_stage_name_when_no_matches() {
    Account parent = new Account(Id = TestingUtils.generateId(Account.SObjectType));
    List<Opportunity> opps = new List<Opportunity>{
      new Opportunity(AccountId = parent.Id, Name = 'One'),
      new Opportunity(AccountId = parent.Id, Name = 'Two'),
      new Opportunity(AccountId = parent.Id, Name = 'Three')
    };

    runTest(parent, opps, null, System.TriggerOperation.AFTER_INSERT);

    Assert.areEqual(false, parent.Does_Opp_Name_Contain_Keyword__c);
  }

  private static void runTest(
    Account parent,
    List<Opportunity> opps,
    Map<Id, SObject> oldRecordsMap,
    System.TriggerOperation triggerOperation
  ) {
    TestingUtils.generateIds(opps);
    Rollup.shouldRun = true;
    Rollup.records = opps;
    RollupAsyncProcessor.stubParentRecords = new List<Account>{ parent };
    Rollup.specificControl = new RollupControl__mdt(
      IsRollupLoggingEnabled__c = true,
      ShouldRunAs__c = RollupMetaPicklists.ShouldRunAs.Synchronous
    );
    Rollup.apexContext = triggerOperation;

    Rollup.runFromTrigger();
  }

  private static SObject setReadOnlyField(Schema.SObjectField fieldToken, SObject record, Object value) {
    Map<String, Object> deserializedRecord = (Map<String, Object>) JSON.deserializeUntyped(JSON.serialize(record));
    deserializedRecord.put(fieldToken.getDescribe().getName(), value);
    return (SObject) JSON.deserialize(JSON.serialize(deserializedRecord), SObject.class);
  }
}
