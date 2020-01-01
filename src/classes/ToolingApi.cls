public class ToolingApi {
    private final String BASE_URL = URL.getSalesforceBaseUrl().toExternalForm();
    private final String TOOLING_API_URI = '/services/data/v47.0/tooling' ;
    private final String SESSION_ID = UserInfo.getSessionId();
    private final Http http;

    public ToolingApi() {
        this.http = new Http();
    }

    public Object getLogs() {


        HttpResponse res = this.queryLogIds();
        ToolingApiResponse toolingResponse = (ToolingApiResponse)Json.deserialize(res.getBody(), ToolingApiResponse.class);

        String logBodyQuery = '/sobjects/ApexLog/{0}/Body/';
        String currentLog = String.format(logBodyQuery, new List<String> { toolingResponse.records[0].Id });
        // System.debug(currentLog);
        // HttpRequest req = this.createHttpRequest();
        // req.setEndpoint(req.getEndpoint() + currentLog);
        // HttpResponse logBody = this.http.Send(req);

        return toolingResponse;
    }

    private HttpResponse queryLogIds() {
        String query = 'SELECT Id, Status from ApexLog where Starttime >= TODAY'
            + ' and Status != \'Success\' and Operation != \'Async Metadata\''
            + ' order by Starttime LIMIT 10';

        HttpRequest request = this.createHttpRequest();
        query = query.replace(' ','+');
        request.setEndpoint(request.getEndpoint() + '/query?q=' + query);
        return this.http.Send(request);
    }

    private HttpRequest createHttpRequest(){
        HttpRequest request = new HttpRequest();
        System.debug('Make sure this URL is included in a Remote Site Setting: ' + BASE_URL);
        request.setEndpoint(BASE_URL + TOOLING_API_URI);
        request.setHeader('Authorization', 'OAuth ' + SESSION_ID);
        request.setHeader('Content-Type', 'application/json');
        request.setMethod('GET');
        return request;
    }

    private class ToolingApiResponse {
        List<LogResponse> records { get; set;}
    }

    private class LogResponse {
        Id Id { get; set; }
        String Status { get; set; }
    }
}