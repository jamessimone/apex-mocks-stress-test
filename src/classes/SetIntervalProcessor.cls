public class SetIntervalProcessor implements Database.Batchable<SObject>, Database.AllowsCallouts, System.Queueable {
    public static final Integer CALLOUT_LIMIT = 5;

    //Interval section, constrained to this class
    //till cases for re-use present themselves
    public interface Interval {
        Boolean hasElapsed();
    }

    public class FirstInterval implements Interval {
        public boolean hasElapsed() {
            //on the first run, we simply process
            //as many requests as necessary
            return true;
        }
    }

    public class TenSecondDelay implements Interval {
        private final Datetime initialTime;
        public TenSecondDelay() {
            this.initialTime = System.now();
        }

        public Boolean hasElapsed() {
            return this.initialTime.addSeconds(10) <= System.now();
        }
    }

    //rest of class body ...
    private final Interval interval;
    private List<SObject> records;
    @testVisible static Integer runCounter = 0;

    public SetIntervalProcessor() {
        this.interval = new FirstInterval();
    }

    public SetIntervalProcessor(Interval interval, List<SObject> records) {
        this.interval = interval;
        this.records = records;
    }

    public List<SObject> start(Database.BatchableContext context) {
        //your query here ...
        return [SELECT Id, Name FROM Account];
    }

    public void execute(Database.BatchableContext context, List<SObject> records) {
        this.records = records;
        this.innerExecute();
    }

    public void execute(System.QueueableContext context) {
        this.innerExecute();
    }

    public void finish(Database.BatchableContext context) {
        //..your finish logic
    }

    private void innerExecute() {
        while(this.interval.hasElapsed() == false) {
            //wait it out
        }
        Integer calloutCount = 0;
        for(Integer index = this.records.size() - 1;
            index >= 0
                && calloutCount < CALLOUT_LIMIT
                && this.interval.hasElapsed();
            index--) {
            //we have to iterate backwards
            //to safely remove items from the list
            SObject record = records[index];
            this.callout(record);
            calloutCount++;
            this.records.remove(index);
        }
        if(this.shouldRunAgain()) {
            runCounter++;
            System.enqueueJob(new SetIntervalProcessor(
                new TenSecondDelay(),
                this.records
            ));
        }
    }

    private Boolean shouldRunAgain() {
        return this.records.size() > 0 &&
            Limits.getQueueableJobs() <= Limits.getLimitQueueableJobs();
    }

    private void callout(SObject record) {
        //whatever your callout logic is
        Http http = new Http();
        HttpRequest req = new HttpRequest();
        req.setEndpoint('https://httpstat.us/200');
        req.setBody(Json.serialize(record));
        http.send(req);
    }
}