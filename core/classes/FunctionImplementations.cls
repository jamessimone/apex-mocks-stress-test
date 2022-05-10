public class FunctionImplementations {
  public class FunctionLogger implements Function {
    public Object call(Object obj) {
      System.debug(obj);
      return obj;
    }
  }

  public class AccountAssignmentFunction implements Function {
    private final Schema.SObjectField fieldToken;
    private final Object value;

    public AccountAssignmentFunction(Schema.SObjectField fieldToken, Object value) {
      this.fieldToken = fieldToken;
      this.value = value;
    }

    public Object call(Object obj) {
      if (obj instanceof Account) {
        Account acc = (Account) obj;
        acc.put(this.fieldToken, this.value);
      }
      return obj;
    }
  }

  public void useExampleFunctions(List<Account> accounts) {
    List<Function> functions = new List<Function>{ new FunctionLogger(), new AccountAssignmentFunction(Account.Name, 'Updated name') };

    for (Account acc : accounts) {
      for (Function func : functions) {
        func.call(acc);
      }
    }
  }
}
