@IsTest
private class CustomObjectRepositoryTests {

  // @IsTest
  static void queriesAreCachedByFactory() {
    CustomObjectRepository customObjectRepo = Factory.getFactory().getCustomObjectRepository();
    // now retrieve second instance
    CustomObjectRepository secondRepo = Factory.getFactory().getCustomObjectRepository();

    System.assertEquals(1, Limits.getQueries());
    System.assertEquals(customObjectRepo, secondRepo);
  }

  private static final Integer STRESSTEST_ITERATIONS = 1000000;
  private static final Map<Integer, Object> STRESSTEST_MAP = new Map<Integer, Object>{
    1 => 15,
    80 => 30,
    1500 => 45,
    4791 => 60,
    5789 => 75,
    7834 => 90,
    9322 => 105
  };

  @IsTest
  static void stresstestIfElseMapAccess() {
    for (Integer index = 0; index < STRESSTEST_ITERATIONS; index++) {
      Object potentialObject;
      if (STRESSTEST_MAP.containsKey(index)) {
        potentialObject = STRESSTEST_MAP.get(index);
      } else {
        potentialObject = index;
        STRESSTEST_MAP.put(index, potentialObject);
      }
    }
  }

  @IsTest
  static void stresstestGetPutMapAccess() {
    for (Integer index = 0; index < STRESSTEST_ITERATIONS; index++) {
      Object potentialMatch = STRESSTEST_MAP.get(index);
      if (potentialMatch == null) {
        potentialMatch = index;
      }
      STRESSTEST_MAP.put(index, potentialMatch);
    }
  }
}