public without sharing class RoundRobinAssigner implements IThreadSafeVisitor {
  private final RoundRobinRepository roundRobinRepo;
  private final IRepository userRepo;

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

  public void visitRecords(List<SObject> records, RoundRobin__c currentAssignment) {
    List<User> applicableUsers = this.userRepo.get(
      Query.equals(User.Department, 'Inside Sales')
    );
    for (SObject record : records) {

    }
  }
}