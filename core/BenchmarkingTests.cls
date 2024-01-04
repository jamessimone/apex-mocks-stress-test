@IsTest
private class BenchmarkingTests {
  private static final Integer ITERATION_MAX = 1000;
  @IsTest
  static void benchmarksIfStatement() {
    for (Integer potentiallyNull : Range.create(ITERATION_MAX)) {
      Integer assignment = potentiallyNull;
      if (assignment == null) {
        assignment = 0;
      }
    }
  }

  @IsTest
  static void benchmarksNullCoalesceStatement() {
    for (Integer potentiallyNull : Range.create(ITERATION_MAX)) {
      Integer assignment = potentiallyNull ?? 0;
    }
  }

  private static final List<Account> FIXED_ACCOUNTS = new List<Account>{
    null, new Account(), null, new Account(Name = 'Hello!')
  };

  @IsTest
  static void benchmarksComplexIfStatement() {
    List<String> accountNames = new List<String>();
    for (Integer index : Range.create(ITERATION_MAX)) {
      for (Account acc : FIXED_ACCOUNTS) {
        String accountName = acc?.Name;
        if (accountName == null) {
          accountName = 'Fallback';
        }
        accountNames.add(accountName);
      }
    }
  }

  @IsTest
  static void benchmarksComplexNullCoalesce() {
    List<String> accountNames = new List<String>();
    for (Integer index : Range.create(ITERATION_MAX)) {
      for (Account acc : FIXED_ACCOUNTS) {
        accountNames.add(acc?.Name ?? 'Fallback');
      }
    }
  }

  @IsTest
  static void benchmarksOldCustomSorter() {
    List<Account> unsortedAccounts = new List<Account>();
    for (Integer index : Range.create(10)) {
      unsortedAccounts.add(new Account(Industry = '' + index + ' unsorted'));
    }

    OldComparator oldSorter = new OldIndustrySorter();
    for (Integer index : Range.create(ITERATION_MAX)) {
      oldSorter.sort(unsortedAccounts);
    }
  }

  private class OldIndustrySorter extends OldComparator {
    public override Integer compare(Object o1, Object o2) {
      Account one = (Account) o1;
      Account two = (Account) o2;
      return one.Industry.compareTo(two.Industry);
    }
  }

  @IsTest
  static void benchmarksWinterTwentyFourSorting() {
    List<Account> unsortedAccounts = new List<Account>();
    for (Integer index : Range.create(10)) {
      unsortedAccounts.add(new Account(Industry = '' + index + ' unsorted'));
    }

    System.Comparator<Account> sorter = new WinterTwentyFourIndustrySorter();
    for (Integer index : Range.create(ITERATION_MAX)) {
      unsortedAccounts.sort(sorter);
    }
  }

  private class WinterTwentyFourIndustrySorter implements System.Comparator<Account> {
    public Integer compare(Account one, Account two) {
      return one.Industry.compareTo(two.Industry);
    }
  }

  public abstract class OldComparator {
    public abstract Integer compare(Object o1, Object o2);

    public void sort(Object[] values) {
      ItemWrapper[] wrappedItems = new List<ItemWrapper>();

      for (Object value : values) {
        wrappedItems.add(new ItemWrapper(this, value));
      }

      wrappedItems.sort();
      values.clear();

      for (ItemWrapper item : wrappedItems) {
        values.add(item.value);
      }
    }
  }

  private class ItemWrapper implements System.Comparable {
    private final OldComparator comparer;
    private final Object value;

    public ItemWrapper(OldComparator comparer, Object value) {
      this.comparer = comparer;
      this.value = value;
    }

    public Integer compareTo(Object o) {
      return this.comparer.compare(value, ((ItemWrapper) o).value);
    }
  }
}
