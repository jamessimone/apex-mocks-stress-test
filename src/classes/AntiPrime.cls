public class AntiPrime {
  public static Integer primesBeforeDefault = 100;

  public static Boolean isAntiPrime(Integer num) {
    if(num > primesBeforeDefault) {
      throw new AntiPrimeException('Primes weren\'t generated to: ' + num);
    }
    return antiPrimesBefore.contains(num);
  }

    private static final Set<Integer> antiPrimesBefore {
      get {
        if(antiPrimesBefore == null) {
          antiPrimesBefore = getAntiPrimes();
        }
        return antiPrimesBefore;
      }
      private set;
  }

  @testVisible
  public static Set<Integer> getAntiPrimes() {
    Integer potentialAntiPrime = 1;
    Integer divisorCount = 0;
    Set<Integer> antiPrimes = new Set<Integer>();
    while(potentialAntiPrime <= primesBeforeDefault) {
      Integer localDivisorCount = 0;
      for(Integer potentialDivisor = 1; potentialDivisor <= potentialAntiPrime; potentialDivisor++) {
        if(Math.mod(potentialAntiPrime, potentialDivisor) == 0) {
          localDivisorCount++;
        }
      }
      if(localDivisorCount > divisorCount) {
        divisorCount = localDivisorCount;
        antiPrimes.add(potentialAntiPrime);
      }
      potentialAntiPrime++;
    }
    return antiPrimes;
  }

  public class AntiPrimeException extends Exception {}
}