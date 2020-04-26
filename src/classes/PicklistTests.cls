@isTest
private class PicklistTests {
  @isTest
  static void it_should_return_account_industries() {
    System.assertEquals('Agriculture', AccountIndustries.Current.AGRICULTURE);
    System.assertEquals('Apparel', AccountIndustries.Current.APPAREL);
  }
}