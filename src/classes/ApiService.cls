@RestResource(urlMapping='/api/*')
global class ApiService {
    private static final ApiRequestResolver resolver = new ApiRequestResolver(RestContext.request);

    @HttpDelete
    global static Api.Response doDelete() {
        return Api.Facade.doDelete(resolver);
    }

    @HttpGet
    global static Api.Response doGet() {
        return Api.Facade.doGet(resolver);
    }

    @HttpPatch
    global static Api.Response patch() {
        return Api.Facade.doPatch(resolver);
    }

    @HttpPost
    global static Api.Response post() {
        return Api.Facade.doPost(resolver);
    }

    @HttpPut
    global static Api.Response put() {
        return Api.Facade.doPut(resolver);
    }
}