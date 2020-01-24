@isTest
public class HttpCallout_Tests {
    @isTest
    static void it_should_properly_stub_response() {
        Test.setMock(HttpCalloutMock.class, new MockHttpResponse(200, 'Success', '{}'));
        HttpResponse res = HttpCallout.makeRequest(new HttpRequest());
        System.assertEquals(200, res.getStatusCode());
    }

    @isTest
    static void it_should_callout_successfully() {
        Callout fakeCallout = new Callout('{parameter1: perhaps a serialized list or id!}',
            new Url('https://api.com'),
            RestMethod.POST
        );
        String jsonString = Json.serialize(fakeCallout);

        Test.setMock(HttpCalloutMock.class, new MockHttpResponse(200, 'Success', '{}'));

        Test.startTest();
        HttpCallout.process(jsonString);
        Test.stopTest();

        System.assert(true, 'should make it here!');
    }

    @isTest
    static void it_should_callout_and_callback() {
        Type callbackType = HttpCallbackMock.class;
        Callout fakeCallout = new Callout('{parameter1: perhaps a serialized list or id!}',
            new Url('https://api.com'),
            RestMethod.POST,
            callbackType
        );
        String jsonString = Json.serialize(fakeCallout);

        Id accountId = TestingUtils.generateId(Account.SObjectType);
        Test.setMock(
            HttpCalloutMock.class,
            new MockHttpResponse(200, 'Success', '{ "AccountId" : "' + accountId + '"}')
        );

        Test.startTest();
        HttpCallout.process(jsonString);
        Test.stopTest();

        System.assertEquals(accountId, mockId);
    }

    private class MockHttpResponse implements HttpCalloutMock {
        private final Integer code;
        private final String status;
        private final String body;

        public MockHttpResponse(Integer code, String status, String body) {
            this.code = code;
            this.status = status;
            this.body = body;
        }

        public HTTPResponse respond(HTTPRequest req) {
            System.assertEquals(1, Limits.getCallouts());
            HttpResponse res = new HttpResponse();

            if(this.body != null) {
                res.setBody(this.body);
            }
            res.setStatusCode(this.code);
            res.setStatus(this.status);

            return res;
        }
    }

    private static Id mockId;
    public virtual class HttpCallbackMock extends Callback {
        public override void execute(System.QueueableContext context) {
            FakeApiResponse fakeResponse = (FakeApiResponse)Json.deserialize(this.responseBody, FakeApiResponse.class);
            mockId = fakeResponse.AccountId;
            //do other work and perform DML ...
        }
    }

    private class FakeApiResponse {
        Id AccountId { get; set; }
    }
}

