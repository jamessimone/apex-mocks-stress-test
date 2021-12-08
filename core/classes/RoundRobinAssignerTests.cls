@IsTest
private class RoundRobinAssignerTests {
  @IsTest
  static void shouldRoundRobinSalesLeads() {
    // arrange
    String assignmentType = 'SDR';
    List<User> users = createUsersForDepartment(assignmentType);
    IRepository mockUserRepo = new RepoFactoryMock.RepoMock(users);

    List<Lead> leadsToAssign = new List<Lead>{ new Lead(), new Lead(), new Lead(), new Lead() };

    // act
    RoundRobinAssigner.IAssignmentRepo repo = new SDRUserRepo(mockUserRepo);
    new RoundRobinAssigner(repo).assignOwners(leadsToAssign, assignmentType);

    // assert
    Integer firstInsideSalesUserAssignmentCount = 0;
    Integer secondInsideSalesUserAssignmentCount = 0;

    for (Lead assignedLead : leadsToAssign) {
      System.assertNotEquals(null, assignedLead.OwnerId, 'Assignment should have been run');
      if (assignedLead.OwnerId == users[0].Id) {
        firstInsideSalesUserAssignmentCount++;
      } else if (assignedLead.OwnerId == users[1].Id) {
        secondInsideSalesUserAssignmentCount++;
      }
    }
    System.assertEquals(2, firstInsideSalesUserAssignmentCount, 'Leads should have been assigned equally');
    System.assertEquals(2, secondInsideSalesUserAssignmentCount, 'Leads should have been assigned equally');
    // now verify that the assignment index was updated
    RoundRobin__c cachedAssignment = [SELECT LastUpdated__c, Index__c FROM RoundRobin__c WHERE Name = :assignmentType];
    System.assertEquals(users[1].Id, cachedAssignment.Index__c, 'Last assigned user should match updated index');
  }

  @IsTest
  static void shouldRoundRobinPreviouslyAssignedLeadsWhenTheirCurrentOwnerFlagIsInactive() {
    // arrange
    String assignmentType = 'SDR';
    List<User> users = createUsersForDepartment(assignmentType);
    User inactiveUser = users.remove(0);

    IRepository mockUserRepo = new RepoFactoryMock.RepoMock(users);

    List<Lead> leadsToAssign = new List<Lead>{
      new Lead(OwnerId = inactiveUser.Id),
      new Lead(OwnerId = inactiveUser.Id),
      new Lead(),
      new Lead()
    };

    // act
    RoundRobinAssigner.IAssignmentRepo repo = new SDRUserRepo(mockUserRepo);
    new RoundRobinAssigner(repo).assignOwners(leadsToAssign, assignmentType);

    // assert
    for (Lead assignedLead : leadsToAssign) {
      System.assertEquals(users[0].Id, assignedLead.OwnerId);
    }
    // now we also can validate that IsRoundRobinActive__c was part of the query
    System.assertEquals(
      new List<Query>{
        Query.equals(User.Department, 'SDR'),
        Query.equals(User.IsActive, true),
        Query.equals(User.IsRoundRobinActive__c, true)
      },
      RepoFactoryMock.QueriesMade
    );
  }

  static List<User> createUsersForDepartment(String department) {
    List<User> users = new List<User>{
      new User(Department = department, IsRoundRobinActive__c = true),
      new User(Department = department, IsRoundRobinActive__c = true)
    };
    TestingUtils.generateIds(users);
    return users;
  }
}
