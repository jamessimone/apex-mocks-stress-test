public abstract class Function {
  private Datetime now = System.now();

  protected abstract void call();
  protected abstract String getTypeName();

  public Function() {
    Savepoint sp = Database.setSavePoint();
    this.recordTime('Starting for ' + getTypeName());
    this.call();
    this.recordTime('Ending for ' + getTypeName());
    Database.rollBack(sp);
  }

  protected List<Account> getAccounts() {
    List<Account> accounts = new List<Account>();
    for(Integer index = 0; index < 2000; index++) {
      accounts.add(new Account(Name = 'Test' + index));
    }
    return accounts;
  }

  protected void recordTime(String startString) {
    System.debug(startString + ': ' + getSecondsPassed() + ' seconds elapsed');
    now = System.now();
  }

  private Integer getSecondsPassed() {
    return Datetime.newInstance(System.now().getTime() - now.getTime()).second();
  }
}

public class DatabaseInsert extends Function {
  protected override String getTypeName() { return 'Database.insert'; }

  protected override void call() {
    Database.insert(this.getAccounts());
  }
}

public class DMLFunctionWithSorting extends Function {
  protected override String getTypeName() { return 'Crud (with sorting)'; }

  protected override void call() {
    Crud.SORT_CHUNKS = true;
    new Crud().doInsert(this.getAccounts());
  }
}

public class DMLFunctionNoSorting extends Function {
  protected override String getTypeName() { return 'Crud (no sorting)'; }

  protected override void call() {
    Crud.SORT_CHUNKS = false;
    new Crud().doInsert(this.getAccounts());
  }
}

new DatabaseInsert();
new DMLFunctionWithSorting();
new DMLFunctionNoSorting();

/* Prints the following:
  USER_DEBUG [24]|DEBUG|Starting for Database.insert: 0 seconds elapsed
  USER_DEBUG [24]|DEBUG|Ending for Database.insert: 9 seconds elapsed
  USER_DEBUG [24]|DEBUG|Starting for Crud (with sorting): 0 seconds elapsed
  USER_DEBUG [24]|DEBUG|Ending for Crud (with sorting): 8 seconds elapsed
  USER_DEBUG [24]|DEBUG|Starting for Crud (no sorting): 0 seconds elapsed
  USER_DEBUG [24]|DEBUG|Ending for Crud (no sorting): 8 seconds elapsed
*/