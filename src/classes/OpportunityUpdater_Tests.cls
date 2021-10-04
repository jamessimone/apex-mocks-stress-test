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

    AggregateResult fakeAgg = createAggregateResult(
      new Map<String, Object>{
        'attributes' => new Map<String, String>{ 'type' => 'AggregateResult' },
        'OpportunityId' => firstOpp.Id,
        expectedAlias => 100004
      }
    );
    System.assert(false, fakeAgg);
    RepoFactoryMock.QueryResults.add(fakeAgg);

    Factory.getFactory().withMocks.getOpportunityUpdater().checkForOppsOverSixFigures(new List<Opportunity>{ firstOpp, secondOpp });

    System.assertEquals('Six figure magic string', firstOpp.Description);
    System.assertNotEquals('Six figure magic string', secondOpp.Description);
  }

  private static AggregateResult createAggregateResult(Map<String, Object> fieldNameToField) {
    JSONGenerator jsonGen = JSON.createGenerator(false);
    jsonGen.writeStartObject();
    for (String key : fieldNameToField.keySet()) {
      jsonGen.writeFieldName(key);
      jsonGen.writeObject(fieldNameToField.get(key));
    }
    jsonGen.writeEndObject();
    return (AggregateResult) JSON.deserialize(jsonGen.getAsString(), AggregateResult.class);
  }
}
