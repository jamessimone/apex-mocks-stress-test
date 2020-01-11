public class OpportunityUpdater {
    private final IRepository oppLineItemRepo;

    public OpportunityUpdater(Factory factory) {
        this.oppLineItemRepo = factory.RepoFactory.getOppLineItemRepo();
    }

    public void updateOppsOnClose(List<Opportunity> updatedOpps) {
        Map<Id, Opportunity> idtoUpdatedOpps = new Map<Id, Opportunity>(updatedOpps);

        Query oppQuery = new Query(Opportunity.Id, Query.Operator.EQUALS, idToUpdatedOpps.keySet());
        List<OpportunityLineItem> lineItems = (List<OpportunityLineItem>)this.oppLineItemRepo.get(
            oppQuery
        );
        for(OpportunityLineItem lineItem : lineItems) {
            if(lineItem.Description == 'business logic criteria') {
                Opportunity opp = idToUpdatedOpps.get(lineItem.OpportunityId);
                opp.Description = 'Magic Business String';
            }
        }
        //etc...
    }
}