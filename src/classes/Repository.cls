public class Repository extends Crud implements IRepository {
    private final Schema.SObjectType repoType;
    private final List<Schema.SObjectField> queryFields;

    private Boolean shortCircuit = false;

    public Repository(Schema.SObjectType repoType, List<Schema.SObjectField> queryFields) {
        this.repoType = repoType;
        this.queryFields = queryFields;
    }

    public QueryWrapper getWrapper(Query query) {
        return this.getWrapper(new List<Query>{ query });
    }

    public QueryWrapper getWrapper(List<Query> queries) {
        String queryString = this.getQueryString(queries);
        Integer resultSize = this.getAggregateResultSize(queries);

        Database.QueryLocator locator = Database.getQueryLocator(queryString);
        return new QueryWrapper(locator, resultSize);
    }

    public List<SObject> get(Query query) {
        return this.get(new List<Query>{ query });
    }

    public List<SObject> get(List<Query> queries) {
        String finalQuery = this.getQueryString(queries);
        System.debug('Query: \n' + finalQuery);
        List<SObject> results = this.getFromQuery(finalQuery);
        System.debug('Results: \n' + results);
        return results;
    }

    private String getQueryString(List<Query> queries) {
        String selectClause = 'SELECT ' + this.addSelectFields();
        String fromClause = this.getFrom();
        String whereClause = this.addWheres(queries);
        return selectClause + fromClause + whereClause;
    }

    private String addSelectFields() {
        Set<String> fieldStrings = new Set<String>{ 'Id' };
        for(SObjectField field : this.queryFields) {
            fieldStrings.add(field.getDescribe().getName());
        }
        return String.join(new List<String>(fieldStrings), ', ');
    }

    private String getFrom() { return '\nFROM ' + this.repoType;  }

    private String addWheres(List<Query> queries) {
        List<String> wheres = new List<String>();
        for(Query query : queries) {
            if(query.isEmpty()) { this.shortCircuit = true; }
            wheres.add(query.toString());
        }
        return '\nWHERE ' + String.join(wheres, '\nAND');
    }

    private List<SObject> getFromQuery(String queryString) {
        return shortCircuit ? new List<SObject>() : Database.query(queryString);
    }

    private Integer getAggregateResultSize(List<Query> queries) {
        String countName = 'CountId';
        String selectClause = 'SELECT Count(Id) ' +  countName;
        String fromClause = this.getFrom();
        String whereClause = this.addWheres(queries);

        List<AggregateResult> results = this.getFromQuery(selectClause + fromClause + whereClause);
        return (Integer) results[0].get(countName);
    }
}