@IsTest
private class ApiHandlerAbandonedCartTest {
  @IsTest
  static void convertsLeadsFromRequestIntegration() {
    Factory.factory = new MockFactory.LeadConversion();
    Lead existingLead = new Lead(
      Company = 'E-comm',
      Email = '' + System.now().getTime() + '@convertsLeadsFromRequestIntegration.com',
      LastName = 'Integration Test'
    );
    RepoFactoryMock.QueryResults.add(existingLead);

    ApiHandlerAbandonedCart.Request abandonedCartReq = new ApiHandlerAbandonedCart.Request();
    abandonedCartReq.email = existingLead.Email;
    sendAbandonedCartRequest(new List<ApiHandlerAbandonedCart.Request>{ abandonedCartReq });

    Assert.areEqual(Query.equals(Lead.Email, new Set<String>{ existingLead.Email }), RepoFactoryMock.QueriesMade[0]);
    Assert.isTrue(((Lead) DMLMock.Updated.Leads.firstOrDefault).IsConverted, 'Lead should have been converted');
  }

  private static void sendAbandonedCartRequest(List<ApiHandlerAbandonedCart.Request> requests) {
    RestRequest req = new RestRequest();
    req.requestURI = '/api/abandonedCart';
    req.requestBody = Blob.valueOf(JSON.serialize(requests));
    RestContext.request = req;
    Api.Response res = ApiService.post();
    Assert.isTrue(res.Success, res.ResponseBody);
  }
}
