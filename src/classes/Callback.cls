public virtual class Callback implements System.Queueable {
    private Type callbackType;
    protected string responseBody;

    protected Callback() {}

    public Callback(Type callbackType) {
        this.callbackType = callbackType;
    }

    public void callback() {
        System.enqueueJob(this);
    }

    public void callback(HttpResponse res) {
        this.responseBody = res.getBody();
        this.callback();
    }

    public virtual void execute(System.QueueableContext context) {
        if(this.callbackType == null) {
            this.callbackType = EmptyCallback.class;
        }
        ((Callback) this.callbackType.newInstance())
            .load(responseBody)
            .execute(context);
    }

    protected Callback load(String responseBody) {
        this.responseBody = responseBody;
        return this;
    }

    private class EmptyCallback extends Callback {
        public override void execute(System.QueueableContext context) {
            //do something like debug here
            //or just do nothing, like the name suggests!
        }
    }
}