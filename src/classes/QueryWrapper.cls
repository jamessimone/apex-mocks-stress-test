public class QueryWrapper {
  public QueryWrapper(Database.QueryLocator locator, Integer resultSize) {
    this.Locator = locator;
    this.ResultSize = resultSize;
  }

  public Database.QueryLocator Locator { get; private set; }
  public Integer ResultSize { get; private set; }
}