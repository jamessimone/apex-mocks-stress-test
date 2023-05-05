public virtual class Factory {
  public RepoFactory repoFactory { get; protected set; }

  @TestVisible
  private static Factory factory;

  protected Factory() {
    this.repoFactory = new RepoFactory();
  }

  public static Factory getFactory() {
    // production code can only initialize the factory through this method
    if (factory == null) {
      factory = new Factory();
    }

    return factory;
  }

  public virtual LeadConverter getLeadConverter() {
    return new LeadConverter(this);
  }

  @TestVisible
  private Factory withMocks {
    get {
      this.repoFactory = new RepoFactoryMock();
      return this;
    }
  }
}
