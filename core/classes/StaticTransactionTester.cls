public class StaticTransactionTester implements System.Queueable {
  // demonstrates that static caching in and of itself isn't enough
  // across concurrent transactions
  private static final Account ACC = [SELECT Id, Description FROM Account ORDER BY Id LIMIT 1];
  private Integer index = 0;

  public void execute(System.QueueableContext qc) {
    if (ACC.Description == 'Sentinel') {
      System.debug('Encountered the right static variable!!!!!!!!!!!!!!!!!!!');
    } else {
      // this branch will always be hit
      System.debug('updating static value');
      ACC.Description = 'Sentinel';
    }
    if (this.index < 5 && qc != null) {
      this.index++;
      System.enqueueJob(this);
    }
  }
}
