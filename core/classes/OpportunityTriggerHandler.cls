public without sharing class OpportunityTriggerHandler extends TriggerHandler {
  protected override void andFinally() {
    Rollup.runFromTrigger();
  }
}
