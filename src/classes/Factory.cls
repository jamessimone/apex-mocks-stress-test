public virtual class Factory {
    public RepoFactory RepoFactory { get; private set;}

    private static Factory factory;

    @testVisible
    protected Factory() {
        this.RepoFactory = new RepoFactory();
    }

    public static Factory getFactory() {
        //production code can only initialize the factory through this method
        if(factory == null) {
            factory = new Factory();
        }

        return factory;
    }

    //factory methods for initializing objects
    public OpportunityUpdater getOpportunityUpdater() {
        return new OpportunityUpdater(this);
    }

    public static void useMocks() {
        factory = getFactory().withMocks;
    }

    @testVisible
    private Factory withMocks {
        get {
            this.RepoFactory = new RepoFactoryMock();
            return this;
        }
    }
}