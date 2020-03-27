public virtual class DataProcessorBatchable extends DataProcessor implements Database.Batchable<SObject>, Database.Stateful {
  private final String queryLocatorString;
  public DataProcessorBatchable(QueryWrapper wrapper, DataProcessor processor) {
      super(wrapper, processor);
      this.queryLocatorString = wrapper.Locator.getQuery();
  }

  public Database.QueryLocator start(Database.BatchableContext context) {
    this.jobId = context.getJobId();
    return Database.getQueryLocator(queryLocatorString);
  }
  public void execute(Database.BatchableContext context, List<SObject> records) {
    this.processor.execute(records);
  }
  public void finish(Database.BatchableContext context) {
    this.processor.finish();
  }
}