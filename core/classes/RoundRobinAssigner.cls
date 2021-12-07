public without sharing class RoundRobinAssigner implements IThreadSafeCacheVisitor {
  private final RoundRobinRepository roundRobinRepo;
  private final IRepository userRepo;

  private static final Integer SENTINEL_INDEX = -1;
  private static final String OWNER_Id = 'OwnerId';

  public RoundRobinAssigner(IRepository userRepo) {
    this.roundRobinRepo = new RoundRobinRepository();
    this.userRepo = userRepo;
  }

  public void assignOwners(List<SObject> records) {
    this.roundRobinRepo.accept(this, records);
  }

  public String getVisitKey() {
    return RoundRobinAssigner.class.getName();
  }

  public void visitRecords(List<SObject> records, SObject currentCachedAssignment) {
    RoundRobin__c cachedAssignment = (RoundRobin__c) currentCachedAssignment;
    List<User> users = this.getUsers('SDR');
    Set<Id> activeOwnerIds = new Map<Id, User>(users).keySet();
    Integer nextUserIndex = this.getNextUserIndex(users, cachedAssignment);
    for (SObject record : records) {
      Id ownerId = (Id) record.get(OWNER_Id);
      User nextUser = users[nextUserIndex];
      if (ownerId == null || activeOwnerIds.contains(ownerId) == false) {
        record.put(OWNER_Id, nextUser.Id);
        cachedAssignment.Index__c = nextUser.Id;
        nextUserIndex = nextUserIndex == users.size() - 1 ? 0 : nextUserIndex + 1;
      }
    }
  }

  private List<User> getUsers(String departmentType) {
    return this.userRepo.get(
      new List<Query>{
        Query.equals(User.Department, departmentType),
        Query.equals(User.IsActive, true),
        Query.equals(User.IsRoundRobinActive__c, true)
      }
    );
  }

  private Integer getNextUserIndex(List<User> users, RoundRobin__c cachedAssignment) {
    Integer currentUserIndex = SENTINEL_INDEX;
    for (Integer index = 0; index < users.size(); index++) {
      User user = users[index];
      if (user.Id > cachedAssignment.Index__c) {
        currentUserIndex = index;
        break;
      }
    }
    if (currentUserIndex == SENTINEL_INDEX) {
      currentUserIndex = 0;
    }
    return currentUserIndex;
  }
}
