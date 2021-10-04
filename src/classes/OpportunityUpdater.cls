public class OpportunityUpdater {
  private final IAggregateRepository oppLineItemRepo;

  public OpportunityUpdater(Factory factory) {
    this.oppLineItemRepo = factory.RepoFactory.getOppLineItemRepo();
  }

  public void updateOppsOnClose(List<Opportunity> updatedOpps) {
    Map<Id, Opportunity> idtoUpdatedOpps = new Map<Id, Opportunity>(updatedOpps);

    Query oppQuery = Query.equals(Opportunity.Id, idToUpdatedOpps.keySet());
    List<OpportunityLineItem> lineItems = (List<OpportunityLineItem>) this.oppLineItemRepo.get(oppQuery);
    for (OpportunityLineItem lineItem : lineItems) {
      if (lineItem.Description == 'business logic criteria') {
        Opportunity opp = idToUpdatedOpps.get(lineItem.OpportunityId);
        opp.Description = 'Magic Business String';
      }
    }
  }

  public void checkForOppsOverSixFigures(List<Opportunity> updatedOpps) {
    Map<Id, Opportunity> idtoUpdatedOpps = new Map<Id, Opportunity>(updatedOpps);

    Query oppQuery = Query.equals(Opportunity.Id, idtoUpdatedOpps.keySet());
    Aggregation overSixFigures = Aggregation.sum(OpportunityLineItem.TotalPrice, 'sumOli');
    List<AggregateResult> results = this.oppLineItemRepo.aggregate(overSixFigures, oppQuery);
    System.assert(false, results);

    for (AggregateResult res : results) {
      Decimal totalSalesPrice = (Decimal) res.get(overSixFigures.getAlias());
      if (totalSalesPrice > 100000) {
        Id oppId = (Id) res.get('OpportunityId');
        Opportunity opp = idtoUpdatedOpps.get(oppId);
        opp.Description = 'Six figure magic string';
      }
    }
  }
}
