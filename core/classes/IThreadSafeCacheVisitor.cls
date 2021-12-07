public interface IThreadSafeCacheVisitor {
  String getVisitKey();
  void visitRecords(List<SObject> records, SObject currentCacheRecord);
}