@IsTest
private class OpportunityUpdater_Tests {
  @IsTest
  static void it_should_update_opportunities_correctly() {
    // arrange
    Opportunity firstOpp = new Opportunity(Id = TestingUtils.generateId(Opportunity.SObjectType));
    Opportunity secondOpp = new Opportunity(Id = TestingUtils.generateId(Opportunity.SObjectType));
    List<Opportunity> opps = new List<Opportunity>{ firstOpp, secondOpp };

    OpportunityLineItem lineItem = new OpportunityLineItem(OpportunityId = firstOpp.Id, Description = 'business logic criteria');

    // act
    RepoFactoryMock.QueryResults.add(lineItem);
    Factory.getFactory().withMocks.getOpportunityUpdater().updateOppsOnClose(opps);

    // assert
    System.assertEquals('Magic Business String', firstOpp.Description);
    System.assertNotEquals('Magic Business String', secondOpp.Description);
  }

  @IsTest
  static void it_should_update_opps_with_line_items_over_six_figures() {
    String expectedAlias = 'sumOli';
    Opportunity firstOpp = new Opportunity(Id = TestingUtils.generateId(Opportunity.SObjectType));
    Opportunity secondOpp = new Opportunity(Id = TestingUtils.generateId(Opportunity.SObjectType));

    AggregateRecord fakeAgg = new AggregateRecord();
    fakeAgg.putAll(new Map<String, Object>{ expectedAlias => 100001, 'OpportunityId' => firstOpp.Id });
    RepoFactoryMock.AggregateResults.put(OpportunityLineItem.SObjectType, new List<AggregateRecord>{ fakeAgg });

    Factory.getFactory().withMocks.getOpportunityUpdater().checkForOppsOverSixFigures(new List<Opportunity>{ firstOpp, secondOpp });

    System.assertEquals('Six figure magic string', firstOpp.Description);
    System.assertNotEquals('Six figure magic string', secondOpp.Description);
  }
}
