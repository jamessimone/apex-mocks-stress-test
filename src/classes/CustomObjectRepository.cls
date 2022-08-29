public class CustomObjectRepository {
  private final List<ExampleSObject__c> exampleSObjects;

  public CustomObjectRepository() {
    this.exampleSObjects = [SELECT Id, Name, TextKey__c FROM ExampleSObject__c];
  }

  private List<ExampleSObject__c> getFiltered(String filter) {
    List<ExampleSObject__c> matchingObjects = new List<ExampleSObject__c>();
    for (ExampleSObject__c potentialMatch : this.exampleSObjects) {
      if (potentialMatch.TextKey__c.contains(filter)) {
        matchingObjects.add(potentialMatch);
      }
    }
    return matchingObjects;
  }
}