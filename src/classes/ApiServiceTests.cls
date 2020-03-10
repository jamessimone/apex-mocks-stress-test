@isTest
private class ApiServiceTests {
    @isTest
    static void it_should_return_fail_for_not_existent_route() {
        RestContext.request = new RestRequest();
        RestContext.request.requestURI = '/api/fake/';

        Api.Response res = ApiService.doGet();

        System.assertEquals(false, res.Success);
        System.assertEquals(Api.BASIC_RESPONSE, res.ResponseBody);
    }

    @isTest
    static void it_should_return_true_for_existing_route() {
        RestContext.request = new RestRequest();
        RestContext.request.requestURI = '/api/test/';

        //have to insert the "namespace" for the test class
        //otherwise it will fail to dynamically build correctly
        Api.HANDLER_NAME = 'ApiServiceTests.' + Api.HANDLER_NAME;

        Api.Response res = ApiService.doGet();

        System.assertEquals(true, res.Success);
        System.assertEquals(TEST_RESPONSE, res.ResponseBody);
    }

    static String TEST_RESPONSE = 'test';
    public class ApiHandlerTest extends Api.Handler {
        public override Api.Response doGet(ApiRequestResolver resolver) {
            Api.Response res = this.getResponse(TEST_RESPONSE);
            res.Success = true;
            return res;
        }
    }
}