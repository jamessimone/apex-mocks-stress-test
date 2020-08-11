@isTest
private class PlatformCacheTests {
    @TestSetup
    static void setup() {
        List<Account> accounts = new List<Account>();
        for(Integer index = 0; index < 9999; index++) {
            accounts.add(new Account(Name = 'Test' + index));
        }
        insert accounts;
    }


    @isTest
    static void it_should_measure_uncached_selection_time() {
        Map<Id, Account> accounts = new Map<Id, Account>([SELECT Id FROM Account]);

        //we want to establish a baseline iteration time, as well
        for(Id accountId : accounts.keySet()) {
            System.assertEquals(true, accounts.containsKey(accountId));
        }
    }

    @isTest
    static void it_should_measure_cached_selection_time() {
        CacheTest cacher = new CacheTest();
        Map<Id, SObjectWrapper> wrapperMap = cacher.getWrapperMap();

        List<Account> accounts = [SELECT Id FROM Account];
        for(Account acc : accounts) {
            System.assertEquals(true, wrapperMap.containsKey(acc.Id));
        }
    }

    private class CacheTest extends AbstractCacheRepo {
        public Map<Id, SObjectWrapper> getWrapperMap() {
            return (Map<Id, SObjectWrapper>) this.getFromCache();
        }

        protected override String getCacheKey() {
            return 'CacheTest';
        }

        protected override Object populateCache() {
            Map<Id, Account> accountMap = new Map<Id, Account>([SELECT Id FROM Account]);
            Map<Id, SObjectWrapper> wrapperMap = new Map<Id, SObjectWrapper>();
            for(Id accountId : accountMap.keySet()) {
                wrapperMap.put(accountId, new SObjectWrapper(accountMap.get(accountId)));
            }
            return wrapperMap;
        }

        protected override Type getCacheBuilder() { return CacheTest.class; }
    }

    public class SObjectWrapper {
        public SObjectWrapper(SObject record) {
            this.Record = record;
            this.IsProcessed = false;
        }

        public SObject Record { get; private set; }
        public Boolean IsProcessed { get; set; }
    }
}