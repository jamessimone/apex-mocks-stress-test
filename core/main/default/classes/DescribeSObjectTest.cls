@IsTest
private class DescribeSObjectTest {
  // used in the Idiomatic Apex article, which I updated while writing this one
  private static final Integer ITERATION_COUNT = 100;
  private static final List<String> TYPES_TO_TEST = new List<String>{
    'Account',
    'Campaign',
    'Case',
    'Contact',
    'ContactPointConsent',
    'ContactPointEmail',
    'ContactPointAddress',
    'EmailMessage',
    'Individual',
    'Lead',
    'Opportunity',
    'Event',
    'Task',
    'User'
  };

  @IsTest
  static void globalDescribeBenchmark() {
    Map<String, SObjectType> types = Schema.getGlobalDescribe();
    for (Integer i = 0; i < ITERATION_COUNT; i++) {
      for (String typeToTest : TYPES_TO_TEST) {
        DescribeSObjectResult describeResult = types.get(typeToTest).getDescribe(SObjectDescribeOptions.DEFERRED);
      }
    }
  }

  @IsTest
  static void describeSObjectBenchmarkSingular() {
    for (Integer i = 0; i < ITERATION_COUNT; i++) {
      for (String typeToTest : TYPES_TO_TEST) {
        // we'll actually test two different versions of this - one with the singular lookup, below; one with
        // TYPES_TO_TEST passed directly without an inner for loop
        DescribeSObjectResult describeResult = Schema.describeSObjects(new List<String>{ typeToTest })[0];
      }
    }
  }

  @IsTest
  static void describeSObjectBenchmarkBulk() {
    for (Integer i = 0; i < ITERATION_COUNT; i++) {
      List<DescribeSObjectResult> results = Schema.describeSObjects(TYPES_TO_TEST);
    }
  }

  @IsTest
  static void typeForNameBenchmark() {
    for (Integer i = 0; i < ITERATION_COUNT; i++) {
      for (String typeToTest : TYPES_TO_TEST) {
        DescribeSObjectResult d = ((SObject) Type.forName(typeToTest).newInstance()).getSObjectType().getDescribe(SObjectDescribeOptions.DEFERRED);
      }
    }
  }
}