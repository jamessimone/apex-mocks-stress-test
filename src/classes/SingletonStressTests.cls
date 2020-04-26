  @isTest
  private class SingletonStressTests {
    @isTest
    static void it_should_establish_a_baseline_iteration_time() {
      runTest(null);
    }

    @isTest
    static void it_should_use_idiomatic_singleton() {
      runTest(new TestIdiomaticSingleton());
    }

    @isTest
    static void it_should_use_new_singleton() {
      runTest(new TestNewSingleton());
    }

    static void runTest(TestFunction function) {
      for(Integer index = 0; index < 10000; index++) {
        if(function != null) {
          function.call();
        }
      }
    }

    private abstract class TestFunction {
      public abstract void call();
    }

    private class TestIdiomaticSingleton extends TestFunction {
      public override void call() {
        System.debug(AccountIndustries.Instance.AGRICULTURE);
      }
    }

    private class TestNewSingleton extends TestFunction {
      public override void call() {
        System.debug(AccountIndustries.Current.AGRICULTURE);
      }
    }
  }