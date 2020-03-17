@isTest
private class PersonTests {
    static Lead lead = new Lead(FirstName = 'Test', LastName = 'Person');

    @isTest
    static void it_should_return_name_for_lead_person() {
        IPerson person = Person.make(lead);

        System.assertEquals('Test Person', person.getName());
    }

    @isTest
    static void it_should_return_name_for_contact_person() {
        IPerson person = Person.make(new Contact(FirstName = 'Test', LastName = 'Contact'));

        System.assertEquals('Test Contact', person.getName());
    }

    @isTest
    static void it_should_return_name_and_dealbreaker_reason_for_dealbreaker_lead() {
        String dealBreakerReason = 'Contract too expensive';
        IDealBreaker dealbreakerLead = Person.make(lead, dealBreakerReason);

        System.assertEquals('Test Person', dealbreakerLead.getName());
        System.assertEquals(dealBreakerReason, dealbreakerLead.getDealBreakerReason());
    }

    @isTest
    static void it_should_return_name_dealbreaker_reason_and_vip_status() {
        String dealBreakerReason = 'Some other reason';
        ISpecialDealBreaker specialLead = Person.makeSpecial(lead, dealBreakerReason);

        System.assertEquals('Test Person', specialLead.getName());
        System.assertEquals(dealBreakerReason, specialLead.getDealBreakerReason());
        System.assertEquals(false, specialLead.isVIPLead());

        lead.Description = 'something something SPECIALKEYWORD something';
        //this works because the REFERENCE to the lead
        //is still the same in the wrapper!
        System.assertEquals(true, specialLead.isVIPLead());
    }

    @isTest
    static void it_should_let_specific_grandchild_instance_call_grandparent() {
        Person.SpecialDealBreakerPerson vipDealBreaker = (Person.SpecialDealBreakerPerson)
            Person.makeSpecial(lead, '');
        System.assertEquals('Test Person', vipDealBreaker.getName());
    }
}