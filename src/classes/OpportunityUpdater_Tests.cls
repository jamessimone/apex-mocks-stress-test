@isTest
private class OpportunityUpdater_Tests {
    @isTest
    static void it_should_update_opportunities_correctly() {
        //arrange
        Opportunity firstOpp = new Opportunity(Id = TestingUtils.generateId(Opportunity.SObjectType));
        Opportunity secondOpp = new Opportunity(Id = TestingUtils.generateId(Opportunity.SObjectType));
        List<Opportunity> opps = new List<Opportunity>{ firstOpp, secondOpp };

        OpportunityLineItem lineItem = new OpportunityLineItem(
            OpportunityId = firstOpp.Id,
            Description = 'business logic criteria'
        );

        //act
        RepoFactoryMock.QueryResults.addAll(opps);
        RepoFactoryMock.QueryResults.add(lineItem);
        Factory.getFactory().withMocks.getOpportunityUpdater().updateOppsOnClose(opps);

        //assert
        System.assertEquals('Magic Business String', firstOpp.Description);
        System.assertNotEquals('Magic Business String', secondOpp.Description);
    }
}