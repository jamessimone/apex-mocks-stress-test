public class ToolingApi {
    private static final String TOOLING_API_URI = '/services/data/v47.0/tooling';
    private static final String LOG_BODY_QUERY = '/sobjects/ApexLog/{0}/Body/';
    private static final String TRACE_UPDATE_QUERY = '/sobjects/TraceFlag/{0}?_HttpMethod=PATCH';
    private static final String TRACE_DATE_FORMAT = 'yyyy-MM-dd\'T\'HH:mm:ss.SSSXXX';
    private final Http http;

    public ToolingApi() {
        this.http = new Http();
    }

    public Map<String, String> getLogs() {
        HttpResponse res = this.queryLogIds();
        ToolingApiResponse toolingResponse = (ToolingApiResponse)Json.deserialize(res.getBody(), ToolingApiResponse.class);

        Map<String, String> logIdToLogBody = new Map<String, String>();
        for(ToolingApiRecord logRecord : toolingResponse.records) {
            HttpRequest logBodyReq = this.createHttpRequest();
            String logIdPath = String.format(LOG_BODY_QUERY, new List<String> { logRecord.Id });
            logBodyReq.setEndpoint(logBodyReq.getEndpoint() + logIdPath);
            HttpResponse logBodyRes = this.http.Send(logBodyReq);
            logIdToLogBody.put(logRecord.Id, logBodyRes.getBody());
        }

        String twelveHoursFromNow = System.now().addHours(12).format(TRACE_DATE_FORMAT);
        this.updateTraces(twelveHoursFromNow);
        this.updateAuditLog(twelveHoursFromNow);

        return logIdToLogBody;
    }

    private HttpResponse queryLogIds() {
        String query = 'SELECT Id, Status from ApexLog where Starttime >= TODAY'
            + ' and Status != \'Success\' and Operation != \'Async Metadata\''
            + ' order by Starttime LIMIT 10';

        HttpRequest request = this.getQueryRequest(query);
        return this.http.Send(request);
    }

    private HttpRequest getQueryRequest(String query) {
        HttpRequest request = this.createHttpRequest();
        query = query.replace(' ','+');
        request.setEndpoint(request.getEndpoint() + '/query?q=' + query);
        return request;
    }

    private HttpRequest createHttpRequest() {
        HttpRequest request = new HttpRequest();
        String baseUrl = URL.getSalesforceBaseUrl().toExternalForm();
        System.debug('Make sure this URL is included in a Remote Site Setting: ' + baseUrl);
        request.setEndpoint(baseUrl + TOOLING_API_URI);
        request.setHeader('Authorization', 'OAuth ' + UserInfo.getSessionId());
        request.setHeader('Content-Type', 'application/json');
        request.setMethod('GET');
        return request;
    }

    private void updateTraces(String twelveHoursFromNow) {
        String query = 'SELECT Id from TraceFlag where LogType = \'USER_DEBUG\'';
        HttpRequest request = this.getQueryRequest(query);
        HttpResponse res = this.http.Send(request);
        ToolingApiResponse toolingResponse = (ToolingApiResponse)Json.deserialize(res.getBody(), ToolingApiResponse.class);

        for(ToolingApiRecord traceRecord : toolingResponse.records) {
            HttpRequest traceRecordReq = this.createHttpRequest();
            traceRecordReq.setMethod('POST');
            String traceRecordBody = this.getTraceRecordBody(twelveHoursFromNow);
            System.debug(traceRecordBody);
            traceRecordReq.setBody(traceRecordBody);

            String traceRecordPath = String.format(TRACE_UPDATE_QUERY, new List<String> { traceRecord.Id });
            traceRecordReq.setEndpoint(traceRecordReq.getEndpoint() + traceRecordPath);
            this.http.Send(traceRecordReq);
        }
    }

    private void updateAuditLog(String twelveHoursFromNow) {

    }

    private String getTraceRecordBody(String twelveHoursFromNow) {
        JSONGenerator gen = JSON.createGenerator(true);
        gen.writeStartObject();
        gen.writeStringField('StartDate', System.now().format(TRACE_DATE_FORMAT));
        gen.writeStringField('ExpirationDate', twelveHoursFromNow);
        gen.writeEndObject();
        return gen.getAsString();
    }

    private class ToolingApiResponse {
        List<ToolingApiRecord> records { get; set;}
    }

    private class ToolingApiRecord {
        Id Id { get; set; }
    }
}