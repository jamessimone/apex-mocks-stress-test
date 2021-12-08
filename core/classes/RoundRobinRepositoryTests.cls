@IsTest
private class RoundRobinRepositoryTests {
  private static String cacheKey = 'a sales team';
  @IsTest
  static void shouldUpdateAssignment() {
    Datetime someTimeAgo = System.now().addDays(-3);
    upsert new RoundRobin__c(LastUpdated__c = someTimeAgo, Name = cacheKey);
    RoundRobinRepository repo = new RoundRobinRepository();

    repo.accept(new VisitorMock(), new List<SObject>());

    RoundRobin__c updatedAssignment = [SELECT LastUpdated__c FROM RoundRobin__c WHERE Name = :cacheKey];
    System.assertEquals(
      true,
      someTimeAgo < updatedAssignment.LastUpdated__c,
      'Cached record should have had its LastUpdated__c field updated properly: ' + updatedAssignment
    );
  }

  private class VisitorMock implements IThreadSafeCacheVisitor {
    public String getVisitKey() {
      return cacheKey;
    }
    public void visitRecords(List<SObject> records, SObject currentCacheRecord) {
      // no-op
    }
  }
}
