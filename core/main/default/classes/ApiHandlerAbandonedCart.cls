public class ApiHandlerAbandonedCart extends Api.Handler {
  private final LeadConverter converter;
  private final IRepository leadRepo;

  public ApiHandlerAbandonedCart() {
    this(Factory.getFactory());
  }

  public ApiHandlerAbandonedCart(Factory factory) {
    this.converter = factory.getLeadConverter();
    this.leadRepo = factory.repoFactory.getLeadRepo();
  }

  public override Api.Response doPost(ApiRequestResolver resolver) {
    String responseMessage = 'Successfully received abandoned cart request';
    Boolean isSuccess = true;

    try {
      this.convertLeads((List<Request>) JSON.deserialize(resolver.RequestBody, List<Request>.class));
    } catch (Exception ex) {
      isSuccess = false;
      responseMessage = ex.getMessage() + '\n' + ex.getStackTraceString();
    }
    Api.Response res = new Api.Response(responseMessage);
    res.Success = isSuccess;
    return res;
  }

  private void convertLeads(List<Request> requests) {
    Set<String> emails = new Set<String>();
    for (Request req : requests) {
      emails.add(req.email);
    }
    List<Lead> matchingLeads = this.leadRepo.get(Query.equals(Lead.Email, emails));
    this.converter.convertLeads(matchingLeads);
  }

  public class Request {
    public String email { get; set; }

    public String deviceId { get; set; }

    public Boolean isLikelyToConvert {
      get {
        if (isLikelyToConvert == null) {
          isLikelyToConvert = false;
        }
        return isLikelyToConvert;
      }
      set;
    }
  }
}
