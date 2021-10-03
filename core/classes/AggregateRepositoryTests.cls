@IsTest
private class AggregateRepositoryTests {
  @IsTest
  static void shouldAggregateSum() {
    Account parent = new Account(Name = AggregateRepositoryTests.class.getName());
    Account secondParent = new Account(Name = 'Second parent');
    insert new List<Account>{ parent, secondParent };

    Opportunity opp = new Opportunity(
      Name = 'opp',
      Amount = 1,
      AccountId = parent.Id,
      StageName = 'sum',
      CloseDate = System.today()
    );
    Opportunity secondOpp = new Opportunity(
      Name = 'opp2',
      Amount = 1,
      AccountId = secondParent.Id,
      StageName = 'sum',
      CloseDate = System.today()
    );
    Opportunity anotherSecondParentMatch = new Opportunity(
      Name = 'opp3',
      Amount = 1,
      AccountId = secondParent.Id,
      StageName = 'sum',
      CloseDate = System.today()
    );
    insert new List<Opportunity>{ opp, secondOpp, anotherSecondParentMatch };

    Aggregation sum = Aggregation.sum(Opportunity.Amount, 'oppSum');
    IAggregateRepository repo = new AggregateRepository(
      Opportunity.SObjectType,
      new List<SObjectField>{ Opportunity.AccountId, Opportunity.Id, Opportunity.Amount },
      new RepoFactory()
    );
    repo.groupBy(Opportunity.AccountId);
    List<AggregateResult> results = repo.aggregate(sum);

    System.assertEquals(2, results?.size());
    for (AggregateResult res : results) {
      if (res.get('AccountId') == parent.Id) {
        System.assertEquals(2, res.get(sum.getAlias()));
      } else {
        System.assertEquals(1, res.get(sum.getAlias()));
      }
    }
  }
}