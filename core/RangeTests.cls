@IsTest
private class RangeTests {
  @IsTest
  static void sizeReflectRangeAmount() {
    Assert.areEqual(50, Range.create(50, 100).size());
    Assert.areEqual(1, Range.create(0, 1).size());
  }

  @IsTest
  static void iteratesThroughRange() {
    Integer startingCount = 0;
    for (Integer intermediate : Range.create(startingCount, 50)) {
      Assert.areEqual(startingCount, intermediate);
      startingCount++;
    }
    Assert.areEqual(50, startingCount);
  }

  @IsTest
  static void iteratesEfficientlyOverLargeNumbers() {
    Long nowInMs = System.now().getTime();
    for (Integer unused : Range.create(100000));
    Assert.isTrue(System.now().getTime() - nowInMs <= 1000);
  }
}
