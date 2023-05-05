public virtual class LeadConverter {
  @TestVisible
  private static Integer MAX_CONVERT_BATCH_SIZE = 100;

  private final IDML dml;
  private Builder builder;

  public LeadConverter(Factory factory) {
    this.dml = factory.repoFactory.getDml();
  }

  public LeadConverter setBuilder(Builder builder) {
    this.builder = builder;
    return this;
  }

  public virtual class Builder {
    public virtual String getConvertedStatus(Lead lead) {
      return 'Closed - Converted';
    }

    public virtual Boolean getShouldNotCreateOpportunity(Lead lead) {
      return true;
    }

    public virtual Id getOwnerId(Lead lead) {
      return lead.OwnerId;
    }

    public virtual Boolean getShouldOverwriteLeadSource(Lead lead) {
      return true;
    }

    public virtual void setAccountAndContactInfo(Database.LeadConvert leadConvert, Account acc, Contact con) {
      leadConvert.setAccountId(acc.Id);
      leadConvert.setContactId(con.Id);
    }

    public virtual List<Database.LeadConvert> getLeadConverts(List<Lead> leads, IDML dml) {
      List<Account> accounts = new List<Account>();
      List<Contact> contacts = new List<Contact>();

      for (Lead lead : leads) {
        Account account = new Account(
          AccountSource = lead.LeadSource,
          Name = (Lead.FirstName + ' ' + Lead.LastName).trim()
        );
        accounts.add(account);

        Contact con = new Contact(
          Email = lead.Email,
          HasOptedOutOfEmail = lead.HasOptedOutOfEmail,
          LastName = lead.LastName,
          Phone = lead.Phone,
          DoNotCall = lead.DoNotCall
        );
        contacts.add(con);
      }

      dml.doInsert(accounts);

      for (Integer i = 0; i < accounts.size(); i++) {
        Account account = accounts[i];
        Contact con = contacts[i];
        Lead lead = leads[i];
        con.AccountId = account.Id;
      }

      dml.doInsert(contacts);

      return this.getLeadConverts(leads, accounts, contacts);
    }

    protected virtual List<Database.LeadConvert> getLeadConverts(
      List<Lead> leads,
      List<Account> accounts,
      List<Contact> contacts
    ) {
      List<Database.LeadConvert> leadConverts = new List<Database.LeadConvert>();
      for (Integer i = 0; i < accounts.size(); i++) {
        Lead lead = leads[i];
        Database.LeadConvert leadConvert = new Database.LeadConvert();
        leadConvert.setLeadId(lead.Id);
        leadConvert.setConvertedStatus(this.getConvertedStatus(lead));
        leadConvert.setDoNotCreateOpportunity(this.getShouldNotCreateOpportunity(lead));
        leadConvert.setOwnerId(this.getOwnerId(lead));
        this.setAccountAndContactInfo(leadConvert, accounts[i], contacts[i]);
        leadConvert.setOverwriteLeadSource(this.getShouldOverwriteLeadSource(lead));
        leadConverts.add(leadConvert);
      }
      return leadConverts;
    }
  }

  public virtual List<Database.LeadConvertResult> convertLeads(List<Lead> leads) {
    if (this.builder == null) {
      this.builder = new Builder();
    }
    List<Database.LeadConvertResult> leadConvertResults = new List<Database.LeadConvertResult>();

    List<Lead> overflowLeads = new List<Lead>();

    while (leads.size() > MAX_CONVERT_BATCH_SIZE) {
      overflowLeads.add(leads.remove(0));
    }
    List<Database.LeadConvert> leadConverts = this.builder.getLeadConverts(leads, this.dml);
    leadConvertResults.addAll(Database.convertLead(leadConverts));

    if (overflowLeads.isEmpty() == false) {
      leadConvertResults.addAll(this.convertLeads(overflowLeads));
    }
    return leadConvertResults;
  }
}
