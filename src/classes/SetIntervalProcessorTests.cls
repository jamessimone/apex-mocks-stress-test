@isTest
private class SetIntervalProcessorTests {
    @TestSetup
    static void setup() {
        innerSetup('');
    }

    static void innerSetup(String prefix) {
        List<Account> accounts = new List<Account>();
        for(Integer index = 0; index < SetIntervalProcessor.CALLOUT_LIMIT; index++) {
            accounts.add(new Account(Name = prefix + index.format()));
        }
        insert accounts;
    }

    @isTest
    static void it_should_always_return_true_for_first_interval() {
        Integer counter = 0;
        SetIntervalProcessor.Interval interval
            = new SetIntervalProcessor.FirstInterval();
        while(true) {
            if(interval.hasElapsed() == false) {
                counter++;
            } else {
                break;
            }
        }

        System.assertEquals(0, counter);
    }

    @isTest
    static void it_should_wait_ten_seconds_for_ten_second_delay_interval() {
        Datetime nowish = System.now();
        SetIntervalProcessor.Interval tenSecDelay =
            new SetIntervalProcessor.TenSecondDelay();
        while(tenSecDelay.hasElapsed() == false) {
            //wait
        }
        System.assertEquals(true, nowish.addSeconds(10) <= System.now());
    }

    @isTest
    static void it_should_perform_as_batch_for_low_record_sizes() {
        Test.setMock(HttpCalloutMock.class, new MockHttpResponse(200));

        Test.startTest();
        Database.executeBatch(new SetIntervalProcessor());
        Test.stopTest();

        Account acc = (Account)JSON.deserialize(lastReqBody, Account.class);
        //remember, we iterate through the list in REVERSE!
        System.assertEquals('0', acc.Name);
    }

    @isTest
    static void it_should_perform_as_queueable_and_wait_ten_seconds() {
        Test.setMock(HttpCalloutMock.class, new MockHttpResponse(200));

        insert new Account(Name = '5');
        Datetime nowish = System.now();

        Test.startTest();
        Database.executeBatch(new SetIntervalProcessor());
        Test.stopTest();

        Account acc = (Account)JSON.deserialize(lastReqBody, Account.class);
        System.assertEquals('0', acc.Name);
        //at least ten seconds should have elapsed
        System.assertEquals(true, nowish.addSeconds(10) <= System.now());
    }

    @isTest
    static void it_should_try_to_requeue_for_larger_sizes() {
        innerSetup('second ');

        insert new Account(Name = '9');

        Test.setMock(HttpCalloutMock.class, new MockHttpResponse(200));

        Exception ex;
        try {
            Test.startTest();
            Database.executeBatch(new SetIntervalProcessor());
            Test.stopTest();
        } catch(Exception e) {
            ex = e;
        }

        //Tests can only run a queueable once
        //verify the correct error has been thrown
        //and that the processor WOULD have requeued
        System.assertEquals('Maximum stack depth has been reached.', ex.getMessage());
        System.assertEquals(2, SetIntervalProcessor.runCounter);
    }

    static string lastReqBody;

    private class MockHttpResponse implements HttpCalloutMock {
        private final Integer code;

        public MockHttpResponse(Integer code) {
            this.code = code;
        }

        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(this.code);
            lastReqBody = req.getBody();
            return res;
        }
    }
}