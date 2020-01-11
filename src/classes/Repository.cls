public class Repository implements IRepository {
    private final Schema.SObjectType repoType;
    private final List<Schema.SObjectField> queryFields;

    private Boolean shortCircuit = false;

    public Repository(Schema.SObjectType repoType, List<Schema.SObjectField> queryFields) {
        this.repoType = repoType;
        this.queryFields = queryFields;
    }

    public List<SObject> get(Query query) {
        return this.get(new List<Query>{ query });
    }

    public List<SObject> get(List<Query> queries) {
        String selectClause = 'SELECT ' + this.addSelectFields();
        String fromClause = '\nFROM ' + this.repoType;
        String whereClause = this.addWheres(queries);

        String finalQuery = selectClause + fromClause + whereClause;
        System.debug('Query: \n' + finalQuery);
        List<SObject> results = shortCircuit ? new List<SObject>() : Database.query(finalQuery);
        System.debug('Results: \n' + results);
        return results;
    }

    private String addSelectFields() {
        Set<String> fieldStrings = new Set<String>{ 'Id' };
        for(SObjectField field : this.queryFields) {
            fieldStrings.add(field.getDescribe().getName());
        }
        return String.join(new List<String>(fieldStrings), ', ');
    }

    private String addWheres(List<Query> queries) {
        List<String> wheres = new List<String>();
        for(Query query : queries) {
            if(query.isEmpty()) { this.shortCircuit = true; }
            wheres.add(query.toString());
        }
        return '\nWHERE ' + String.join(wheres, '\nAND');
    }
}