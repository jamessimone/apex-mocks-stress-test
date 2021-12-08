public without sharing class SDRUserRepo implements RoundRobinAssigner.IAssignmentRepo {
  private final IRepository userRepo;

  public SDRUserRepo(IRepository userRepo) {
    this.userRepo = userRepo;
  }

  public List<Id> getAssignmentIds(String departmentType) {
    List<Id> assignmentIds = new List<Id>();
    for (User user : this.getUsers(departmentType)) {
      assignmentIds.add(user.Id);
    }
    if (assignmentIds.isEmpty()) {
      assignmentIds.add(this.getFallbackUserId());
    }
    return assignmentIds;
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

  private Id getFallbackUserId() {
    return [SELECT Id FROM User LIMIT 1].Id;
  }
}
