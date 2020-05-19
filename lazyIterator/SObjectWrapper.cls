public class SObjectWrapper {
  public final SObject oldRecord, newRecord;
  public SObjectWrapper(SObject oldRecord, SObject newRecord) {
    this.oldRecord = oldRecord;
    this.newRecord = newRecord;
  }
}