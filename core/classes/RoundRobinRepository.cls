public class RoundRobinRepository extends AbstractCacheRepo {
  private static Map<String, RoundRobin__c> CACHED_ASSIGNMENTS;
  private static final String SENTINEL_USER_INDEX = getSentinelIndex();

  public void accept(IThreadSafeVisitor visitor, List<SObject> records) {
    RoundRobin__c currentAssignment = this.getCurrentAssignment(visitor.getVisitKey());
    visitor.visitRecords(records, currentAssignment);
    while (this.commitUpdatedAssignment(currentAssignment) == false) {
      this.forceRefreshCache();
      this.accept(visitor, records);
    }
  }

  private RoundRobin__c getCurrentAssignment(String assignmentType) {
    if (CACHED_ASSIGNMENTS == null) {
      CACHED_ASSIGNMENTS = this.getCachedAssignments();
    }
    if (CACHED_ASSIGNMENTS.containsKey(assignmentType) == false) {
      this.initializeAssignment(assignmentType);
    }

    return CACHED_ASSIGNMENTS.get(assignmentType);
  }

  private void forceRefreshCache() {
    CACHED_ASSIGNMENTS = getRoundRobinRecords();
    this.updateCache(CACHED_ASSIGNMENTS);
  }

  private Boolean commitUpdatedAssignment(RoundRobin__c updatedAssignment) {
    Boolean wasCommitSuccessful = true;
    Map<String, RoundRobin__c> currentCache = this.getCachedAssignments();
    if (
      currentCache.containsKey(updatedAssignment.Name) &&
      currentCache.get(updatedAssignment.Name).LastUpdated__c > CACHED_ASSIGNMENTS.get(updatedAssignment.Name).LastUpdated__c
    ) {
      updatedAssignment = currentCache.get(updatedAssignment.Name);
      wasCommitSuccessful = false;
    } else {
      // this line wouldn't be necessary if we were using LastModifiedDate
      updatedAssignment.LastUpdated__c = System.now();
      upsert updatedAssignment;
    }

    CACHED_ASSIGNMENTS.put(updatedAssignment.Name, updatedAssignment);
    return wasCommitSuccessful;
  }

  protected override Object populateCache() {
    return getRoundRobinRecords();
  }

  protected override String getCacheKey() {
    return RoundRobinRepository.class.getName();
  }

  private Map<String, RoundRobin__c> getCachedAssignments() {
    return (Map<String, RoundRobin__c>) this.getFromCache();
  }

  private void initializeAssignment(String assignmentType) {
    CACHED_ASSIGNMENTS.put(
      assignmentType,
      new RoundRobin__c(
        Name = assignmentType,
        // some sentinel value
        LastUpdated__c = Datetime.newInstanceGmt(1970, 1, 1),
        Index__c = SENTINEL_USER_INDEX
      )
    );
  }

  private static Map<String, RoundRobin__c> getRoundRobinRecords() {
    return new Map<String, RoundRobin__c>(RoundRobin__c.getAll());
  }

  private static String getSentinelIndex() {
    return User.SObjectType.getDescribe().getKeyPrefix() + '0'.repeat(12);
  }
}
