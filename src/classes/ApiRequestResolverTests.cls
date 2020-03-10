@isTest
private class ApiRequestResolverTests {
    @isTest
    static void it_should_resolve_api_route() {
        String endpointName = 'orders';
        RestRequest req = new RestRequest();
        req.requestURI = '/services/apexrest/api/' + endpointName + '/';

        ApiRequestResolver resolver = new ApiRequestResolver(req);

        System.assertEquals(endpointName.capitalize(), resolver.ApiName);
    }

    @isTest
    static void it_should_handle_non_trailing_slash() {
        String endpointName = 'orders';
        RestRequest req = new RestRequest();
        req.requestURI = '/services/apexrest/api/' + endpointName;

        ApiRequestResolver resolver = new ApiRequestResolver(req);

        System.assertEquals(endpointName.capitalize(), resolver.ApiName);
    }

    @isTest
    static void it_should_resolve_request_body() {
        String body = '{}';
        RestRequest req = new RestRequest();
        req.requestBody = Blob.valueOf(body);

        ApiRequestResolver resolver = new ApiRequestResolver(req);

        System.assertEquals(body, resolver.RequestBody);
    }

    @isTest
    static void it_should_resolve_request_url_param() {
        String fakeAccountId = '0016g00000EPjVcXXX';
        RestRequest req = new RestRequest();
        req.requestURI = '/services/apexrest/api/account/' + fakeAccountId;

        ApiRequestResolver resolver = new ApiRequestResolver(req);

        System.assertEquals(fakeAccountId, resolver.RequestUrlBody);
    }
}