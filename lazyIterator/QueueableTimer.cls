public class QueueableTimer implements System.Queueable {
  private Datetime lastTime;

  public QueueableTimer() {
    this.lastTime = System.now();
  }

  public void execute(QueueableContext context) {
    Savepoint sp = Database.setSavepoint();
    List<Account> accounts = this.getExampleAccountsToInsert();
    this.log('Starting execute after gathering sample records');

    insert accounts;

    this.log('Ending');
    Database.rollback(sp);
  }

  private List<Account> getExampleAccountsToInsert() {
    List<Account> accounts = new List<Account>();
    //savepoint usage consumes a DML row ...
    for(Integer index = 0; index < 9998; index++) {
      accounts.add(
        new Account(
          Name = ' Testing' + index.format() + ' ',
          Phone = '8438816989'
        )
      );
    }
    return accounts;
  }

  private void log(String startingString) {
    System.debug(
      startingString + ', time passed: '
      + this.getSecondsPassed().format()
      + ' seconds'
    );
    this.lastTime = System.now();
  }

  private Decimal getSecondsPassed() {
    return ((Decimal)(System.now().getTime() - this.lastTime.getTime())).divide(1000, 4);
  }
}