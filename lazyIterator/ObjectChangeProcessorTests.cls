@isTest
private class ObjectChangeProcessorTests {
  @isTest
  static void it_should_correctly_filter_records() {
    Account acc = new Account(
      Name = 'Test Account',
      NumberOfEmployees = 5
    );

    Account newAcc = new Account(
      Name = acc.Name,
      NumberOfEmployees = acc.NumberOfEmployees + 2
    );

    Account accTwo = new Account(
      Name = 'Test Two',
      NumberOfEmployees = 5
    );

    Account accThree = new Account(
      Name = 'Test Three',
      NumberOfEmployees = 6
    );

    Account accThreeNew = new Account(
      Name = accThree.Name,
      NumberOfEmployees = accThree.NumberOfEmployees + 1
    );

    List<SObject> oldObjects = new List<SObject>{ acc, accTwo, accThree } ;
    List<SObject> newObjects = new List<SObject>{ newAcc, accTwo, accThreeNew };

    ObjectChangeProcessor processor = new ObjectChangeProcessor(oldObjects, newObjects);

    List<Account> accounts = (List<Account>)
      processor
        .filterByChangeInField(Account.NumberOfEmployees)
        .toList(new List<Account>());

    System.assertEquals(2, accounts.size());
    System.assertNotEquals(null, accounts[0]);
    System.assertEquals(7, accounts[0].NumberOfEmployees);
    System.assertEquals(7, accounts[1].NumberOfEmployees);
  }

  @isTest
  static void it_should_call_functions_added_to_processor() {
    //lets use a bunch of different accounts
    //just to ensure we don't blow the stack
    Account acc = new Account(Name = ' Do Re Mi Pizza ', Phone = '8438816989');
    List<Account> accs = getAccounts(10000);
    accs.add(acc);

    ObjectChangeProcessor processor = new ObjectChangeProcessor(accs);
    processor
      .addFunction(new NameNormalizer())
      .addFunction(new PhoneNormalizer())
      .process();

    System.assertEquals('Do Re Mi Pizza', acc.Name);
    System.assertEquals('(843) 881-6989', acc.Phone);
  }

  class NameNormalizer implements Function {
    public void call(Object o) {
      Account acc = (Account)o;
      acc.Name = acc.Name.normalizeSpace();
    }
  }

  class PhoneNormalizer implements Function {
    public void call(Object o) {
      Account acc = (Account)o;
      acc.Phone = this.formatPhoneNumber(acc.Phone.replaceAll('[^0-9]', ''));
    }

    private String formatPhoneNumber(String phone) {
      if(phone.length() == 10) {
            return  '(' + phone.substring(0, 3) + ') '
                + phone.substring(3, 6) + '-'
                + phone.substring(6);
        } else if (phone.length() == 11 && phone.substring(0) == '1') {
            return this.formatPhoneNumber(phone.substring(1, phone.length() - 1));
        }
        return phone;
    }
  }

  @isTest
  static void it_should_not_blow_the_stack_while_filtering() {
    Double sentinelValue = Math.pow(10, 5);
    List<Account> accounts = new List<Account>();
    for(Integer index = 0; index < sentinelValue; index++) {
      accounts.add(new Account(Name = 'Test ' + index));
    }

    ObjectChangeProcessor processor = new ObjectChangeProcessor(accounts);
    List<Object> sameAccounts = processor
      .filter(new AlwaysTrue())
      .toList(new List<Account>());

    System.assertEquals(sentinelValue, sameAccounts.size());
    System.assert(true, 'Should make it here');
  }

  class AlwaysTrue implements BooleanFunction {
    public Boolean isTrueFor(Object o) { return true; }
  }

  private static List<Account> getAccounts(Integer sentinelValue) {
    List<Account> accounts = new List<Account>();
    for(Integer index = 0; index < sentinelValue; index++) {
      accounts.add(new Account(Name = 'Test ' + index, Phone = '8438816989'));
    }
    return accounts;
  }
}