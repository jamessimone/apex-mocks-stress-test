public abstract class Picklist extends Singleton {
  private final SObjectField field;
  protected final List<String> picklistValues;

  protected Picklist(SObjectField field) {
      this.field = field;
      this.picklistValues = this.getPicklistValues(field);
  }

  protected String getValue(String value) {
    if(!picklistValues.contains(value)) {
      throw new PicklistException(value + ' is not a valid entry for ' + this.field.getDescribe().getName() + '!');
    }

    return value;
  }

  private List<String> getPicklistValues(SObjectField field) {
    Schema.DescribeFieldResult fieldMetadata = field.getDescribe();
    List<Schema.PicklistEntry> picklistEntries = fieldMetadata.getPicklistValues();

    List<String> returnValues = new List<String>();
    for(Schema.PicklistEntry picklistEntry : picklistEntries) {
      returnValues.add(picklistEntry.getValue());
    }
    return returnValues;
}

  private class PicklistException extends Exception {}
}