public without sharing class RoundRobinAssigner implements IThreadSafeCacheVisitor {
  private final RoundRobinRepository roundRobinRepo;
  private final IAssignmentRepo assignmentRepo;

  private String assignmentType;

  private static final Integer SENTINEL_INDEX = -1;
  private static final String OWNER_Id = 'OwnerId';

  public interface IAssignmentRepo {
    List<Id> getAssignmentIds(String assignmentType);
  }

  public RoundRobinAssigner(IAssignmentRepo assignmentRepo) {
    this.roundRobinRepo = new RoundRobinRepository();
    this.assignmentRepo = assignmentRepo;
  }

  public void assignOwners(List<SObject> records, String assignmentType) {
    this.assignmentType = assignmentType;
    this.roundRobinRepo.accept(this, records);
  }

  public String getVisitKey() {
    return this.assignmentType;
  }

  public void visitRecords(List<SObject> records, SObject currentCachedAssignment) {
    RoundRobin__c cachedAssignment = (RoundRobin__c) currentCachedAssignment;
    List<Id> assignmentIds = this.assignmentRepo.getAssignmentIds(this.assignmentType);
    Set<Id> activeAssignmentIds = new Set<Id>(assignmentIds);
    Integer nextAssignmentIndex = this.getNextAssignmentIndex(assignmentIds, cachedAssignment);
    for (SObject record : records) {
      Id ownerId = (Id) record.get(OWNER_Id);
      Id nextOwnerId = assignmentIds[nextAssignmentIndex];
      if (ownerId == null || activeAssignmentIds.contains(ownerId) == false) {
        record.put(OWNER_Id, nextOwnerId);
        cachedAssignment.Index__c = nextOwnerId;
        nextAssignmentIndex = nextAssignmentIndex == assignmentIds.size() - 1 ? 0 : nextAssignmentIndex + 1;
      }
    }
  }

  private Integer getNextAssignmentIndex(List<Id> assignmentIds, RoundRobin__c cachedAssignment) {
    Integer currentAssignmentIndex = SENTINEL_INDEX;
    for (Integer index = 0; index < assignmentIds.size(); index++) {
      Id assignmentId = assignmentIds[index];
      if (assignmentId > cachedAssignment.Index__c) {
        currentAssignmentIndex = index;
        break;
      }
    }
    if (currentAssignmentIndex == SENTINEL_INDEX) {
      currentAssignmentIndex = 0;
    }
    return currentAssignmentIndex;
  }
}
