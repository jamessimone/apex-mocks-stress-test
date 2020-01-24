public class HttpCallout {
    @future(callout = true)
    public static void process(String calloutString) {
        Callout calloutObj = (Callout)JSON.deserialize(calloutString, Callout.class);
        HttpRequest req = setupHttpRequest(calloutObj);
        HttpResponse res = makeRequest(req);
        Type callbackType = Type.forName(calloutObj.CallbackName);
        new Callback(callbackType).callback(res);
    }

    @testVisible
    private static HttpResponse makeRequest(HttpRequest req) {
        HttpResponse res;
        try {
            res = new Http().send(req);
        } catch(Exception ex) {
            //or you could just throw ...
            res = new HttpResponse();
            res.setStatusCode(503);
            res.setBody(ex.getMessage());
        }
        return res;
    }

    private static HttpRequest setupHttpRequest(Callout callout) {
        HttpRequest req = new HttpRequest();
        req.setEndpoint(callout.Endpoint);
        req.setMethod(callout.RestMethod);
        req.setTimeout(callout.Timeout);
        req.setHeader('Content-Type', 'application/json');
        req.setBody(callout.BodyString);
        if(String.isNotBlank(callout.ApiKey)) {
            req.setHeader('x-api-key', callout.ApiKey);
        }
        return req;
    }
}