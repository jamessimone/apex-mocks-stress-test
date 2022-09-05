public virtual class Factory {
  private final Map<Type, Object> singletonTypeToInstance = new Map<Type, Object>();

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
    return (CustomObjectRepository) this.getOrRegisterSingleton(CustomObjectRepository.class);
  }

  private Object getOrRegisterSingleton(Type instanceType) {
    if (this.singletonTypeToInstance.containsKey(instanceType)) {
      return this.singletonTypeToInstance.get(instanceType);
    }
    Object discreteInstance = instanceType.newInstance();
    this.singletonTypeToInstance.put(instanceType, discreteInstance);
    return discreteInstance;
  }

  @TestVisible
  private Factory withMocks {
    get {
      this.RepoFactory = new RepoFactoryMock();
      return this;
    }
  }
}