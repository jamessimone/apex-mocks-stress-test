public class ApiRequestResolver {
    private final String apiBase = '/api/';

    public String ApiName { get; private set; }
    public String RequestBody { get; private set; }
    public String RequestUrlBody { get; private set; }

    public ApiRequestResolver(RestRequest req) {
        this.ApiName = this.getApiName(req.requestURI);
        this.RequestBody = req.requestBody != null ? req.requestBody.toString() : '';
        //taken straight outta the docs...
        this.RequestUrlBody = req.requestURI != null ? req.requestURI.substring(req.requestURI.lastIndexOf('/') + 1) : '';
    }

    private String getApiName(String requestURI) {
        if(requestURI == null) { return ''; }
        Integer apiNameStart = requestURI.indexOf(apiBase) + apiBase.length();
        Integer lastSlash = requestURI.lastIndexOf('/');
        Integer apiNameEnd = lastSlash < apiNameStart ? requestURI.length() : lastSlash;
        return requestURI.substring(apiNameStart, apiNameEnd).capitalize();
    }
}