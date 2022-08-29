public virtual class Factory {
  public RepoFactory RepoFactory { get; protected set; }

  @TestVisible
  private static Factory factory;

  protected Factory() {
    this.RepoFactory = new RepoFactory();
  }

  public static Factory getFactory() {
    // production code can only initialize the factory through this method
    if (factory == null) {
      factory = new Factory();
    }

    return factory;
  }

  public CustomObjectRepository getCustomObjectRepository() {
    return new CustomObjectRepository();
  }

  @TestVisible
  private Factory withMocks {
    get {
      this.RepoFactory = new RepoFactoryMock();
      return this;
    }
  }
}