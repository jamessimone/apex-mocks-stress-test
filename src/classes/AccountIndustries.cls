public class AccountIndustries extends Picklist {
  public AccountIndustries() {
    super(Account.Industry);
  }

  public static final AccountIndustries Current = (AccountIndustries)Singleton.getSingleton(AccountIndustries.class);

  public static final AccountIndustries Instance = new AccountIndustries();

  public String AGRICULTURE { get { return this.getValue('Agriculture'); }}
  public String APPAREL { get { return this.getValue('Apparel'); }}
}