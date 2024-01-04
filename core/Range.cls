public class Range implements System.Iterable<Integer> {
  private final List<Integer> ints = new List<Integer>();

  private Range(Integer starting, Integer ending) {
    for (Integer index = starting; index < ending; index++) {
      this.ints.add(index);
    }
  }

  public static Range create(Integer startingNumber, Integer endingNumber) {
    return new Range(startingNumber, endingNumber);
  }

  public static Range create(Integer endingNumber) {
    return new Range(0, endingNumber);
  }

  public System.Iterator<Integer> iterator() {
    return this.ints.iterator();
  }

  public Integer size() {
    return this.ints.size();
  }
}
