public virtual class DataProcessor implements Database.Batchable<SObject> {
  protected final Integer resultSize;
  protected final String queryString;
  protected final DataProcessor processor;

  protected Id jobId;

  public DataProcessor(Factory factory) {
  }

  protected DataProcessor(QueryWrapper wrapper, DataProcessor processor) {
    this.resultSize = wrapper.ResultSize;
    this.queryString = wrapper.Locator.getQuery();
    this.processor = processor;
  }

  public Database.QueryLocator start(Database.BatchableContext context) {
    this.jobId = context.getJobId();
    return Database.getQueryLocator(this.queryString);
  }
  public void execute(Database.BatchableContext context, List<SObject> records) {
    this.processor.execute(records);
  }
  public void finish(Database.BatchableContext context) {
    this.processor.finish();
  }

  protected virtual QueryWrapper getWrapper() {
    throw new DataProcessorException('Not Implemented');
  }

  protected virtual void execute(List<SObject> records) {
  }

  protected virtual void finish() {
  }

  protected virtual Boolean isBatchable() {
    return this.resultSize > Limits.getLimitDmlRows() / 3;
  }

  public void process() {
    QueryWrapper wrapper = this.getWrapper();
    if (this.isBatchable()) {
      Database.executeBatch(new DataProcessor(wrapper, this));
    } else {
      System.enqueueJob(new DataProcessorQueueable(wrapper, this));
    }
  }

  private class DataProcessorQueueable extends DataProcessor implements System.Queueable {

    public DataProcessorQueueable(QueryWrapper wrapper, DataProcessor processor) {
      super(wrapper, processor);
    }

    public void execute(QueueableContext context) {
      this.jobId = context.getJobId();
      this.processor.execute(Database.query(this.queryString));
      this.processor.finish();
    }
  }

  private class DataProcessorException extends Exception {
  }
}
