public virtual class RepoFactory {
  public virtual IAggregateRepository getOppRepo() {
    List<SObjectField> queryFields = new List<SObjectField>{
      Opportunity.IsWon,
      Opportunity.StageName
      // etc ...
    };
    return new AggregateRepository(Opportunity.SObjectType, queryFields, this);
  }

  public virtual IAggregateRepository getOppLineItemRepo() {
    List<SObjectField> queryFields = new List<SObjectField>{
      OpportunityLineItem.Description,
      OpportunityLineItem.OpportunityId
      // etc
    };
    return new AggregateRepository(OpportunityLineItem.SObjectType, queryFields, this);
  }

  public virtual IDML getDML() {
    return new DML();
  }
}
