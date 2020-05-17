@isTest
private class AntiPrimeTests {
  @isTest
  static void it_should_detect_one_as_an_antiprime() {
    System.assertEquals(true, AntiPrime.isAntiPrime(1));
  }

  @isTest
  static void it_should_detect_two_as_an_antiprime() {
    System.assertEquals(true, AntiPrime.isAntiPrime(2));
  }

  @isTest
  static void it_should_throw_exception_if_number_larger_than_anti_primes_generated_is_passed() {
    Exception e;
    try {
      AntiPrime.isAntiPrime(200);
    } catch(Exception ex) {
      e = ex;
    }

    System.assertNotEquals(null, e);
  }

  @isTest
  static void it_should_properly_generate_anti_primes_below_sentinel_value() {
    //make no assumptions
    AntiPrime.primesBeforeDefault = 100;
    System.assertEquals(
      new Set<Integer>{ 1, 2, 4, 6, 12, 24, 36, 48, 60 },
      AntiPrime.getAntiPrimes()
    );
  }

  @isTest
  static void it_should_work_with_numbers_greater_than_100() {
    AntiPrime.primesBeforeDefault = 120;
    System.assertEquals(true, AntiPrime.isAntiPrime(120));
  }
}