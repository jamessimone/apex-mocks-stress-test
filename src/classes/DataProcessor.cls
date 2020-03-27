public abstract class DataProcessor {
  protected final Integer resultSize;
  protected final DataProcessor processor;

  protected Id jobId;

  public DataProcessor(Factory factory) { }

  protected DataProcessor(QueryWrapper wrapper, DataProcessor processor) {
    this.resultSize = wrapper.ResultSize;
    this.processor = processor;
  }

  protected virtual QueryWrapper getWrapper() { throw new DataProcessorException('Not Implemented'); }
  protected virtual void execute(List<SObject> records) { }
  protected virtual void finish() { }
  protected virtual Boolean isBatchable() {
    return this.resultSize > Limits.getLimitDmlRows() / 3;
  }

  public void process() {
    QueryWrapper wrapper = this.getWrapper();
    //some sentinel value
    if(this.isBatchable()) {
        Database.executeBatch(new DataProcessorBatchable(wrapper, this));
    } else {
        System.enqueueJob(new DataProcessorQueueable(wrapper, this));
    }
  }

  private class DataProcessorException extends Exception{}
}