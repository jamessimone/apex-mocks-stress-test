@IsTest
public without sharing class MockFactory {
  private MockFactory() {
    //@IsTest classes cannot be abstract :(
  }

  public class LeadConversion extends Factory {
    public LeadConversion() {
      super();
    }

    public override LeadConverter getLeadConverter() {
      return new LeadConverterMock();
    }
  }

  public class LeadConverterMock extends LeadConverter {
    public LeadConverterMock() {
      super(Factory.getFactory().withMocks);
    }

    public override List<Database.LeadConvertResult> convertLeads(List<Lead> leads) {
      List<Database.LeadConvertResult> leadConvertResults = new List<Database.LeadConvertResult>();
      for (Lead lead : leads) {
        leadConvertResults.add(this.convert(lead));
      }
      return leadConvertResults;
    }

    private Database.LeadConvertResult convert(Lead lead) {
      Id oppId = TestingUtils.generateId(Opportunity.SObjectType);
      Id accountId = TestingUtils.generateId(Account.SObjectType);
      Id contactId = TestingUtils.generateId(Contact.SObjectType);
      this.updateLead(lead, accountId, contactId);
      Database.LeadConvertResult res = (Database.LeadConvertResult) JSON.deserialize(
        JSON.serialize(
          new Map<String, Object>{
            'accountid' => accountId,
            'contactid' => contactId,
            'leadid' => lead.Id,
            'opportunityid' => oppId
          }
        ),
        Database.LeadConvertResult.class
      );
      return res;
    }

    private void updateLead(Lead lead, Id accountId, Id contactId) {
      Contact con = new Contact(
        Id = contactId,
        FirstName = lead.FirstName,
        LastName = lead.LastName,
        Email = lead.Email,
        Phone = lead.Phone,
        AccountId = accountId,
        LeadSource = lead.LeadSource
      );

      Map<String, Object> readOnlyFields = new Map<String, Object>{
        'ConvertedContactId' => con.Id,
        'ConvertedAccountId' => con.AccountId,
        'IsConverted' => true
      };
      lead = (Lead) TestingUtils.setReadOnlyField(lead, readOnlyFields);
      DMLMock.UpdatedRecords.add(lead);
      DMLMock.UpsertedRecords.add(con);
    }
  }
}
