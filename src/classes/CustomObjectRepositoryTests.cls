@IsTest
private class CustomObjectRepositoryTests {

  @IsTest
  static void queriesAreCachedByFactory() {
    CustomObjectRepository customObjectRepo = Factory.getFactory().getCustomObjectRepository();
    // now retrieve second instance
    CustomObjectRepository secondRepo = Factory.getFactory().getCustomObjectRepository();

    System.assertEquals(1, Limits.getQueries());
    System.assertEquals(customObjectRepo, secondRepo);
  }
}