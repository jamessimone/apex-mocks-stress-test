@isTest
private class OpportunityTaskHandlerTests {

  @isTest
  static void it_should_create_tasks_for_eligible_sales_people() {
    TestingUtils.activateCustomPerm(UserInfo.getUserId(), 'Is_API_Task_Creation_Enabled');

    Opportunity opp = new Opportunity(
      AccountId = TestingUtils.generateId(Account.SObjectType),
      ContactId = TestingUtils.generateId(Contact.SObjectType),
      OwnerId = UserInfo.getUserId()
    );

    System.runAs(new User(Id = UserInfo.getUserId())) {
      new OpportunityTaskHandler(CrudMock.getMock()).createTasksForEligibleSalespeople(
        new List<Opportunity>{
            opp
        }
      );
    }

    Task createdTask = (Task)CrudMock.Inserted.Tasks.singleOrDefault;
    System.assertEquals(System.today().addDays(10), createdTask.ActivityDate, 'Activity Date didn\'t match for task!');
    System.assertEquals(opp.OwnerId, createdTask.OwnerId, 'Owner Id didn\'t match for task!');
    System.assertEquals(opp.AccountId, createdTask.WhatId, 'What Id didn\'t match for task!');
    System.assertEquals(opp.ContactId, createdTask.WhoId, 'Who Id didn\'t match for task!');
  }
}