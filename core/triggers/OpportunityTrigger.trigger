trigger OpportunityTrigger on Opportunity(after insert, before update, after update, before delete, after undelete) {
  new OpportunityTriggerHandler().execute();
}
