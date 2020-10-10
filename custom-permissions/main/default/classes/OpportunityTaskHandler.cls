public without sharing class OpportunityTaskHandler {
    private final ICrud crud;

    public static final String TASK_SUBJECT = 'You have 10 days to move this sale along!';

    public OpportunityTaskHandler(ICrud crud) {
        this.crud = crud;
    }

    public void createTasksForEligibleSalespeople(List<Opportunity> opps) {
    // here we will assume the passed in Opps are pre-filtered
        if(FeatureManagement.checkPermission('Is_API_Task_Creation_Enabled')) {
            this.createTasks(opps);
        }
    }

    private void createTasks(List<Opportunity> opps) {
        List<Task> tasksToInsert = new List<Task>();
        for(Opportunity opp : opps) {
            Task t = new Task(
                ActivityDate = System.today().addDays(10),
                OwnerId = opp.OwnerId,
                Subject = TASK_SUBJECT,
                WhatId = opp.AccountId,
                WhoId = opp.ContactId
            );
            tasksToInsert.add(t);
        }
        this.crud.doInsert(tasksToInsert);
    }

    private void insertTasks(List<Task> tasks) {
        insert tasks;
    }
}