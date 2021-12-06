@IsTest
private class PlatformCacheTests {
  @TestSetup
  static void setup() {
    List<Account> accounts = new List<Account>();
    for (Integer index = 0; index < 9999; index++) {
      accounts.add(new Account(Name = 'Test' + index));
    }
    insert accounts;
  }

  @IsTest
  static void it_should_measure_uncached_selection_time() {
    Map<Id, Account> accounts = new Map<Id, Account>([SELECT Id FROM Account]);

    // we want to establish a baseline iteration time, as well
    for (Id accountId : accounts.keySet()) {
      System.assertEquals(true, accounts.containsKey(accountId));
    }
  }

  @IsTest
  static void it_should_measure_cached_selection_time() {
    CacheTest cacher = new CacheTest();
    Map<Id, Account> wrapperMap = cacher.getWrapperMap();

    for (Id someId : wrapperMap.keySet()) {
      System.assertEquals(true, someId != null);
    }
  }

  private class CacheTest extends AbstractCacheRepo {
    public Map<Id, Account> getWrapperMap() {
      return (Map<Id, Account>) this.getFromCache();
    }

    protected override String getCacheKey() {
      return 'CacheTest';
    }

    protected override Object populateCache() {
      return new Map<Id, Account>([SELECT Id FROM Account]);
    }

    protected override Type getCacheBuilder() {
      return CacheTest.class;
    }
  }
}
