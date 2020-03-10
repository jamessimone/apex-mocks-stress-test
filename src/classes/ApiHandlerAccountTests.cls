@isTest
private class ApiHandlerAccountTests {
    @isTest
    static void it_should_return_stringified_account_to_api() {
        //in other test cases, where the factory was what
        //was being injected, we could simply call
        //Factory.withMocks.getClassHere.methodUnderTest
        Factory.useMocks();
        //arrange
        Id accountId = TestingUtils.generateId(Account.SObjectType);
        Account fakeAccount = new Account(Id = accountId, Name = 'ApiHandlerTest');
        RepoFactoryMock.QueryResults.add(fakeAccount);
        RestContext.request = getAccountRequest(accountId);

        //act
        Api.Response res = ApiService.doGet();
        Account deserializedAccount = (Account)Json.deserialize(res.ResponseBody, Schema.Account.class);

        //assert
        System.assertEquals(true, res.Success);
        System.assertEquals(accountId, deserializedAccount.Id);
        System.assertEquals(fakeAccount.Name, deserializedAccount.Name);

        Query performedQuery = RepoFactoryMock.QueriesMade[0];
        System.assertEquals(Account.Id, performedQuery.field);
        System.assertEquals(Query.Operator.EQUALS, performedQuery.operator);
        System.assertEquals(accountId, performedQuery.predicates[0]);
    }

    @isTest
    static void it_should_return_account_not_found_for_no_results() {
        //no need to mock the result
        //we can go straight to the db here
        //even though there's no result
        // it's still 8x slower than mocking!!
        RestContext.request = getAccountRequest(TestingUtils.generateId(Account.SObjectType));

        Api.Response res = ApiService.doGet();
        Account deserializedAccount = (Account)Json.deserialize(res.ResponseBody, Schema.Account.class);

        System.assertEquals(false, res.Success);
        System.assertEquals(ApiHandlerAccount.NOT_FOUND, deserializedAccount.Name);
    }

    static RestRequest getAccountRequest(Id accountId) {
        RestRequest req = new RestRequest();
        req.requestURI = '/api/account/' + accountId;
        return req;
    }
}