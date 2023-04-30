public class ApiHandlerAbandonedCart extends Api.Handler {
  public override Api.Response doPost(ApiRequestResolver resolver) {
    Api.Response res = new Api.Response('OK');
    res.Success = true;
    return res;
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
