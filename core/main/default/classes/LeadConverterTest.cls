@IsTest
private class LeadConverterTest {
  @TestSetup
  static void setup() {
    Lead first = new Lead(
      Company = 'required',
      Email = 'one@' + LeadConverterTest.class.getName() + '.com',
      LastName = 'Integration Test One'
    );
    Lead second = new Lead(
      Company = 'required',
      Email = 'two@' + LeadConverterTest.class.getName() + '.com',
      LastName = 'Integration Test One'
    );
    insert new List<Lead>{ first, second };
  }

  @IsTest
  static void properlyConvertsLeadsByChunk() {
    LeadConverter.MAX_CONVERT_BATCH_SIZE = 1;

    Factory.getFactory().getLeadConverter().convertLeads(getLeadsForConversion());

    Assert.areEqual(0, [SELECT COUNT() FROM Lead WHERE IsConverted = FALSE]);
    Assert.areEqual(0, [SELECT COUNT() FROM Opportunity]);
  }

  @IsTest
  static void itHandlesCustomConversionBuilders() {
    Account exampleExistingAccount = new Account(Name = 'Example Existing');
    insert exampleExistingAccount;

    insert new Contact(LastName = 'Belongs to above account', AccountId = exampleExistingAccount.Id);

    Factory.getFactory().getLeadConverter().setBuilder(new ExampleBuilder()).convertLeads(getLeadsForConversion());

    Assert.areEqual(1, [SELECT COUNT() FROM Opportunity]);
    Assert.areEqual(exampleExistingAccount.Id, [SELECT ConvertedAccountId FROM Lead LIMIT 1].ConvertedAccountId);
  }

  private static List<Lead> getLeadsForConversion() {
    return Factory.getFactory().repoFactory.getLeadRepo().getAll();
  }

  private class ExampleBuilder extends LeadConverter.Builder {
    public override List<Database.LeadConvert> getLeadConverts(List<Lead> leads, IDML dml) {
      List<Contact> existingContacts = [SELECT Account.Id, Id FROM Contact];
      return this.getLeadConverts(leads, new List<Account>{ existingContacts.get(0).Account }, existingContacts);
    }

    public override Boolean getShouldNotCreateOpportunity(Lead lead) {
      return false;
    }
  }
}
