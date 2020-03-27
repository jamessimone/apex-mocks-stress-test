public virtual class RepoFactory {
    public virtual IRepository getAccountRepo() {
        return new Repository(
            Account.SObjectType, new List<SObjectField>{ Account.Name }
        );
    }

    public virtual IRepository getOppRepo() {
        List<SObjectField> queryFields = new List<SObjectField>{
            Opportunity.IsWon,
            Opportunity.StageName
            //etc ...
        };
        return new Repository(Opportunity.SObjectType, queryFields);
    }

    public virtual IRepository getOppLineItemRepo() {
        List<SObjectField> queryFields = new List<SObjectField>{
            OpportunityLineItem.Description,
            OpportunityLineItem.OpportunityId
            //etc
        };
        return new Repository(OpportunityLineItem.SObjectType, queryFields);
    }

    //etc
}