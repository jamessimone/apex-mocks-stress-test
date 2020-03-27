public interface IRepository extends ICrud {
    QueryWrapper getWrapper(Query query);
    QueryWrapper getWrapper(List<Query> queries);
    List<SObject> get(Query query);
    List<SObject> get(List<Query> queries);
}