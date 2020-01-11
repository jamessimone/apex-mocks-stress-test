public class RepoFactoryMock extends RepoFactory {
    @testVisible
    private static List<SObject> QueryResults = new List<SObject>();
    @testVisible
    private static List<Query> QueriesMade = new List<Query>();

    public override IRepository getOppLineItemRepo() {
        List<SObject> queriedResults = this.getResults(OpportunityLineItem.SObjectType);
        return queriedResults.size() > 0 ?
            new RepoMock(queriedResults) :
            super.getOppLineItemRepo();
    }

    private List<SObject> getResults(SObjectType sobjType) {
        List<SObject> resultList = new List<SObject>();
        for(SObject potentialResult : QueryResults) {
            if(potentialResult.getSObjectType() == sobjType) {
                resultList.add(potentialResult);
            }
        }
        return resultList;
    }

    //now, when you reach the point
    //in testing where you need to
    //stub out a specific repo
    private class RepoMock implements IRepository {
        private final List<SObject> results;

        public RepoMock(List<SObject> results) {
            this.results = results;
        }

        public List<SObject> get(Query query) {
            return this.get(new List<Query>{ query });
        }

        public List<SObject> get(List<Query> queries) {
            QueriesMade.addAll(queries);
            return this.results;
        }
    }
}