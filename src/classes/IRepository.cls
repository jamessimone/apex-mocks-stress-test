public interface IRepository {
    List<SObject> get(Query query);
    List<SObject> get(List<Query> queries);
}