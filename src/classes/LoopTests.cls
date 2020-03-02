@isTest
private class LoopTests {

    @isTest
    static void it_should_establish_baseline_using_while_loop() {
        List<SObject> accountsToInsert = fillAccountList();
    }

    @isTest
    static void it_should_test_fake_while_loop_insert() {
        List<SObject> accountsToInsert = fillAccountList();

        CrudMock.getMock().doInsert(accountsToInsert);

        System.assertEquals(LARGE_NUMBER, CrudMock.Inserted.size());
    }

    @isTest
    static void it_should_test_actual_while_loop_insert() {
        List<SObject> accountsToInsert = fillAccountList();

        insert accountsToInsert;

        List<Account> insertedAccs = [SELECT Id FROM Account];
        System.assertEquals(LARGE_NUMBER, insertedAccs.size());
    }

    @isTest
    static void it_should_test_fake_basic_for_loop_insert() {
        List<SObject> accountsToInsert = new List<SObject>();
        for(Integer index = 0; index < LARGE_NUMBER; index++) {
            Account acc = new Account(Name = 'Test' + index);
            accountsToInsert.add(acc);
        }

        CrudMock.getMock().doInsert(accountsToInsert);

        System.assertEquals(LARGE_NUMBER, CrudMock.Inserted.size());
    }

    @isTest
    static void it_should_test_fake_syntax_sugar_for_loop_insert() {
        List<SObject> accountsToInsert = fillAccountList();

        for(SObject record : accountsToInsert) {
            setNameToRandomValue(record);
        }

        CrudMock.getMock().doInsert(accountsToInsert);

        System.assertEquals(LARGE_NUMBER, CrudMock.Inserted.size());
    }

    @isTest
    static void it_should_test_iterator_while_loop_insert() {
        List<SObject> accountsToInsert = fillAccountList();
        Iterator<SObject> accountIterator = accountsToInsert.iterator();

        while(accountIterator.hasNext()) {
            setNameToRandomValue(accountIterator.next());
        }
    }

    @isTest
    static void it_should_test_custom_iterator_while_loop() {
        List<SObject> accountsToInsert = fillAccountList();
        Iterator<SObject> listIterator = new ListIterator(accountsToInsert);

        while(listIterator.hasNext()) {
            setNameToRandomValue(listIterator.next());
        }
    }

    private static Integer LARGE_NUMBER = 10000;
    private static List<SObject> fillAccountList() {
        Integer counter = 0;
        List<SObject> accountsToInsert = new List<SObject>();
        while(counter < LARGE_NUMBER) {
            Account acc = new Account(Name = 'Test' + counter);
            accountsToInsert.add(acc);
            counter++;
        }
        return accountsToInsert;
    }

    private static void setNameToRandomValue(SObject record) {
        record.put('Name', 'Something ' + Math.random().format());
    }
}