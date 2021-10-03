public interface IAggregateRepository extends IRepository {
  void groupBy(Schema.SObjectField fieldToken);
  void groupBy(String fieldName);

  // always a fun one
  Integer count();
  Integer count(Query query);
  Integer count(List<Query> queries);
  // with support for sum, count, count distinct, average, max, min
  List<AggregateResult> aggregate(Aggregation aggregation);
  List<AggregateResult> aggregate(Aggregation aggregation, Query query);
  List<AggregateResult> aggregate(Aggregation aggregation, List<Query> queries);
  List<AggregateResult> aggregate(List<Aggregation> aggregations);
  List<AggregateResult> aggregate(List<Aggregation> aggregations, Query query);
  List<AggregateResult> aggregate(List<Aggregation> aggregations, List<Query> queries);
}