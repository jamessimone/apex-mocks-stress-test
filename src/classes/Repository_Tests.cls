@isTest
private class Repository_Tests {
    @isTest
    static void it_should_take_in_a_query() {
        Query basicQuery = new Query(Opportunity.IsWon, Query.Operator.EQUALS, true);
        IRepository repo = new Repository(Opportunity.SObjectType, new List<SObjectField>{
            Opportunity.Id
        });

        repo.get(basicQuery);
        System.assertEquals(1, Limits.getQueries());
    }

    @isTest
    static void it_should_handle_lists_and_sets_of_ids_or_strings() {
        Id accountId = TestingUtils.generateId(Account.SObjectType);
        List<Id> ids = new List<Id>{ accountId, accountId };
        Set<Id> setIds = new Set<Id>(ids);
        Set<String> oppNames = new Set<String>{ 'Open', 'Closed' };

        Query listQuery = new Query(Opportunity.Id, Query.Operator.EQUALS, ids);
        Query setQuery = new Query(Opportunity.Id, Query.Operator.EQUALS, setIds);
        Query setStringQuery = new Query(Opportunity.Name, Query.Operator.EQUALS, oppNames);

        IRepository repo = new Repository(Opportunity.SObjectType, new List<SObjectField>{
            Opportunity.Id
        });

        repo.get(listQuery);
        repo.get(setQuery);
        repo.get(setStringQuery);
        System.assertEquals(3, Limits.getQueries());
        //we need to write a special assert for sets with multiple values
        System.assertEquals('Name in (\'Closed\',\' Open\')', setStringQuery.toString());
    }

    @isTest
    static void it_should_properly_short_circuit_when_empty_collections_passed_in() {
        Query listQuery = new Query(Opportunity.Id, Query.Operator.EQUALS, new List<Id>());

        IRepository repo = new Repository(Opportunity.SObjectType, new List<SObjectField>{
            Opportunity.Id
        });

        List<SObject> opps = repo.get(listQuery);
        System.assertEquals(0, opps.size());
        System.assertEquals(0, Limits.getQueries());
    }

    @isTest
    static void it_should_return_count_properly() {
        insert new Account(Name = 'Test');
        Query nameEqualsTest = new Query(Account.Name, Query.Operator.EQUALS, 'Test');
        IRepository repo = new Repository(Account.SObjectType, new List<SObjectField>());

        QueryWrapper wrapper = repo.getWrapper(nameEqualsTest);

        System.assertEquals(1, wrapper.ResultSize);
    }
}