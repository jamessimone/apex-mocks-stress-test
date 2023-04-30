@IsTest
private class ApiHandlerAbandonedCartTest {
  @IsTest
  static void convertsLeadsFromRequestIntegration() {
    // we can start with an integration test where a pre-existing lead actually exists
    Lead existingLead = new Lead(
      Company = 'E-comm',
      Email = '' + System.now().getTime() + '@convertsLeadsFromRequestIntegration.com',
      LastName = 'Integration Test'
    );
    insert existingLead;

    ApiHandlerAbandonedCart.Request abandonedCartReq = new ApiHandlerAbandonedCart.Request();
    abandonedCartReq.email = existingLead.Email;
    sendAbandonedCartRequest(new List<ApiHandlerAbandonedCart.Request>{ abandonedCartReq });

    Assert.isTrue(
      [SELECT IsConverted FROM Lead WHERE Id = :existingLead.Id].IsConverted,
      'Lead should have been converted'
    );
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
