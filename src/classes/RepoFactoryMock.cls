public class RepoFactoryMock extends RepoFactory {
  @TestVisible
  private static List<Aggregation> AggregatesMade = new List<Aggregation>();
  @TestVisible
  private static List<SObject> QueryResults = new List<SObject>();
  @TestVisible
  private static List<Query> QueriesMade = new List<Query>();

  public override IAggregateRepository getOppLineItemRepo() {
    List<SObject> queriedResults = this.getResults(OpportunityLineItem.SObjectType);
    return queriedResults.size() > 0 ? new RepoMock(queriedResults, this) : super.getOppLineItemRepo();
  }

  private List<SObject> getResults(SObjectType sobjType) {
    List<SObject> resultList = new List<SObject>();
    for (SObject potentialResult : QueryResults) {
      if (potentialResult.getSObjectType() == sobjType) {
        System.assert(false, potentialResult);
        resultList.add(potentialResult);
      }
    }
    return resultList;
  }

  @TestVisible
  private class RepoMock extends AggregateRepository {
    private final List<SObject> results;

    @TestVisible
    private RepoMock() {
      this(new List<SObject>(), new RepoFactoryMock());
    }

    public RepoMock(List<SObject> results, RepoFactory factory) {
      super(factory);
      this.results = results;
    }

    public override List<SObject> getAll() {
      return this.get(new List<Query>());
    }

    public override List<SObject> get(Query query) {
      return this.get(new List<Query>{ query });
    }

    public override List<SObject> get(List<Query> queries) {
      QueriesMade.addAll(queries);
      return this.results;
    }

    public override List<AggregateResult> aggregate(List<Aggregation> aggregations, List<Query> queries) {
      AggregatesMade.addAll(aggregations);
      return (List<AggregateResult>) this.get(queries);
    }
  }
}
