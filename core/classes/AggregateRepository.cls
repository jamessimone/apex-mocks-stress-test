public inherited sharing class AggregateRepository extends Repository implements IAggregateRepository {
  private final Set<String> aggregatedFieldNames;
  private final Set<String> groupedByFieldNames;
  private List<Aggregation> aggregations;
  public AggregateRepository(Schema.SObjectType repoType, List<Schema.SObjectField> queryFields, RepoFactory repoFactory) {
    super(repoType, queryFields, repoFactory);
    this.aggregatedFieldNames = new Set<String>();
    this.groupedByFieldNames = new Set<String>();
  }

  public void groupBy(Schema.SObjectField fieldToken) {
    this.groupBy(fieldToken.getDescribe().getName());
  }
  public void groupBy(String fieldName) {
    this.groupedByFieldNames.add(fieldName);
  }

  public Integer count() {
    return this.count(new List<Query>());
  }
  public Integer count(Query query) {
    return this.count(new List<Query>{ query });
  }
  public Integer count(List<Query> queries) {
    return null;
  }

  public List<AggregateResult> aggregate(Aggregation aggregation) {
    return this.aggregate(new List<Aggregation>{ aggregation}, new List<Query>());
  }
  public List<AggregateResult> aggregate(Aggregation aggregation, Query query) {
    return this.aggregate(new List<Aggregation>{ aggregation}, new List<Query>{ query });
  }
  public List<AggregateResult> aggregate(Aggregation aggregation, List<Query> queries) {
    return this.aggregate(new List<Aggregation>{ aggregation}, queries);
  }
  public List<AggregateResult> aggregate(List<Aggregation> aggregations) {
    return this.aggregate(aggregations, new List<Query>());
  }
  public List<AggregateResult> aggregate(List<Aggregation> aggregations, Query query) {
    return this.aggregate(aggregations, new List<Query>{ query });
  }
  public List<AggregateResult> aggregate(List<Aggregation> aggregations, List<Query> queries) {
    this.aggregations = aggregations;
    // TODO - add group by clauses
    return (List<AggregateResult>) this.get(queries);
  }

  protected override Set<String> addSelectFields() {
    Set<String> baseFields = super.addSelectFields();
    for (Aggregation agg : aggregations) {
      baseFields.add(agg.toString());
      baseFields.remove(agg.getFieldName());
    }
    return baseFields;
  }
}