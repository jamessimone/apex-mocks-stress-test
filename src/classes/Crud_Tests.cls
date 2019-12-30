@isTest
private class Crud_Tests {
    @TestSetup
    static void setup() {
        Contact con = new Contact(LastName='Test1');
        con.Email = 'something@something.com';
        insert new List<SObject>{ new Account(Name='TestAccount'), con };
    }

    @isTest
    static void it_should_do_crud_insert() {
        Contact contact = new Contact(LastName= 'Test2');
        new Crud().doInsert(contact);

        System.assertNotEquals(null, contact.Id);
    }

    @isTest
    static void it_should_do_crud_update() {
        Contact contact = [SELECT Id FROM Contact];

        contact.FirstName = 'Harry';
        new Crud().doUpdate(contact);

        System.assert(contact.FirstName == 'Harry');
    }

    @isTest
    static void it_should_not_fail_on_update_call_from_empty_list() {
        List<Contact> contacts = new List<Contact>();
        new Crud().doUpdate(contacts);
    }

    @isTest
    static void it_should_do_crud_upsert() {
        Contact contact = [SELECT Id FROM Contact];
        contact.FirstName = 'Harry';
        new Crud().doUpsert(contact);

        System.assert(contact.FirstName == 'Harry');
    }

    @isTest
    static void it_should_do_crud_delete() {
        Contact contact = [SELECT Id FROM Contact];

        new Crud().doDelete(contact);
        List<Contact> deletedContacts = [SELECT Id, IsDeleted FROM Contact ALL ROWS];

        System.assert(deletedContacts[0].IsDeleted);
    }

    @isTest
    static void it_should_do_crud_hard_delete() {
        Contact contact = [SELECT Id FROM Contact];

        new Crud().doHardDelete(contact);
        List<Contact> deletedContacts = [SELECT Id, IsDeleted FROM Contact ALL ROWS];

        System.assert(deletedContacts[0].IsDeleted);
    }

    @isTest
    static void it_should_do_crud_undelete() {
        Contact contact = [SELECT Id FROM Contact];

        Crud crud = new Crud();
        crud.doDelete(contact);
        crud.doUndelete(contact);

        List<Contact> notDeletedContacts = [SELECT Id FROM Contact];
        System.assert(!notDeletedContacts.isEmpty());
    }

    @isTest
    static void it_should_rollback_all_upserts_if_upsert_list_had_error() {
        Account one = new Account(Name = 'Test1');
        Account two = new Account();
        try {//should fail because name is a required field on Account
            new Crud().doUpsert(new List<Account>{ one, two });
        } catch (Exception e) { }
        System.assertEquals(null, one.Id);
        System.assertEquals(null, two.Id);
    }

    @isTest
    static void it_should_not_fail_on_update_due_to_chunking_errors() {
        List<SObject> records = new List<SObject>();
        List<Account> accounts = new List<Account>();
        List<Contact> contacts = new List<Contact>();

        for(Integer i = 0; i < Crud.MAX_DML_CHUNKING; i ++) {
            Account a = new Account(Name=''+i);
            accounts.add(a);
            records.add(a);

            Contact c = new Contact(LastName=''+i);
            contacts.add(c);
            records.add(c);
        }

        insert accounts;
        insert contacts;

        try {
            new Crud().doUpdate(records);
        } catch(Exception ex) {
            System.assert(false, ex);
        }
    }
}