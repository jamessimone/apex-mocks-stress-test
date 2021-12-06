public interface IThreadSafeVisitor {
  String getVisitKey();
  void visitRecords(List<SObject> records, RoundRobin__c currentAssignment);
}