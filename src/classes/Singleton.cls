public abstract class Singleton {
  protected Singleton() {}
  private static final Map<Type, Singleton> typeToSingleton = new Map<Type, Singleton>();

  public static Singleton getSingleton(Type type) {
    if(typeToSingleton.containsKey(type) == false) {
      System.debug('Filling cache');
      typeToSingleton.put(type, (Singleton)type.newInstance());
    }
    return typeToSingleton.get(type);
  }
}