@isTest
private class Callback_Tests {
    @isTest
    static void it_should_callback() {
        Callback mock = new Callback(CallbackMock.class);

        Test.startTest();
        mock.callback();
        Test.stopTest();

        System.assertEquals(true, MockWasCalled);
    }

    static boolean MockWasCalled = false;
    public virtual class CallbackMock extends Callback {
        public override void execute(System.QueueableContext context) {
            MockWasCalled = true;
        }
    }
}