@IsTest
private class SDRUserRepoTests {
  @IsTest
  static void shouldAssignFallbackUserWhenNoUsersReturned() {
    SDRUserRepo repo = new SDRUserRepo(new RepoFactoryMock.RepoMock());
    List<Id> assignmentIds = repo.getAssignmentIds('some department type');
    System.assertEquals(1, assignmentIds.size(), 'fallback Id should have been included!');
  }
}
