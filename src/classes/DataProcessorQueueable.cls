public virtual class DataProcessorQueueable extends DataProcessor implements System.Queueable {
  private final String query;

  public DataProcessorQueueable(QueryWrapper wrapper, DataProcessor processor) {
      super(wrapper, processor);
      this.query = wrapper.Locator.getQuery();
  }

  public void execute(QueueableContext context) {
      this.jobId = context.getJobId();
      this.processor.execute(Database.query(query));
      this.processor.finish();
  }
}