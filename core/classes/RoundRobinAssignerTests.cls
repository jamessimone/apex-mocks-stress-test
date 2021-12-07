@IsTest
private class RoundRobinAssignerTests {
  @IsTest
  static void shouldRoundRobinSalesLeads() {
    // arrange
    List<User> users = createUsersForDepartment('SDR');
    IRepository mockUserRepo = new RepoFactoryMock.RepoMock(users);

    List<Lead> leadsToAssign = new List<Lead>{ new Lead(), new Lead(), new Lead(), new Lead() };

    // act
    new RoundRobinAssigner(mockUserRepo).assignOwners(leadsToAssign);

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
  }

  @IsTest
  static void shouldRoundRobinPreviouslyAssignedLeadsWhenTheirCurrentOwnerFlagIsInactive() {
    // arrange
    List<User> users = createUsersForDepartment('SDR');
    User inactiveUser = users.remove(0);

    IRepository mockUserRepo = new RepoFactoryMock.RepoMock(users);

    List<Lead> leadsToAssign = new List<Lead>{
      new Lead(OwnerId = inactiveUser.Id),
      new Lead(OwnerId = inactiveUser.Id),
      new Lead(),
      new Lead()
    };

    // act
    new RoundRobinAssigner(mockUserRepo).assignOwners(leadsToAssign);

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
