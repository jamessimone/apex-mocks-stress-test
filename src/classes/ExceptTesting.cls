@isTest
private class ExceptTesting {
    //salesforce has bizarre rules in place about
    //naming classes with the word Exception in them
    @isTest
    static void it_should_provide_baseline_testing_time() {}

    @isTest
    static void it_should_throw_exception() {
        throw new TestException();
    }

    @isTest
    static void it_should_catch_thrown_exception() {
        Exception ex;

        try {
            throw new TestException('Some message here');
        } catch(Exception exc) {
            ex = exc;
        }

        System.assertNotEquals(null, ex);
    }

    @isTest
    static void it_should_build_big_nested_stacktrace() {
        String exceptionMessage = 'hi'.repeat(100000);
        Exception caughtEx;
        try {
            try {
                throw new TestException('First exception');
            } catch(Exception ex) {
                throw new TestException(ex.getMessage() + '\n' + exceptionMessage);
            }
        } catch(Exception ex) {
            caughtEx = ex;
        }

        System.assertNotEquals(null, caughtEx);
    }

    private class TestException extends Exception {}
}