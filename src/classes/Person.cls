public abstract class Person implements IPerson {

    private final SObject person;
    //notice the use of the protected keyword
    //this means that only classes inheriting from
    //this class have the use of this constructor
    //you can also make methods protected
    protected Person(SObject person) {
      this.person = person;
    }

    public String getName() {
      return String.valueOf(this.person.get('FirstName') + ' ' + this.person.get('LastName'));
    }

    //more on static methods in a second
    public static Person make(Lead lead) {
      return new LeadPerson(lead);
    }

    public static Person make(Contact con) {
      return new ContactPerson(con);
    }

    public static DealBreakerPerson make(Lead lead, String dealBreakerReason) {
        return new DealBreakerPerson(lead, dealBreakerReason);
    }

    public static ISpecialDealBreaker makeSpecial(Lead lead, String dealBreakerReason) {
        return new SpecialDealBreakerPerson(lead, dealBreakerReason);
    }

    public virtual void process(Datetime processTime) {
        //here we use a string instead of an SObjectField
        //but we want for both the Lead and Contact
        //to make use of the same field!
        this.person.put('ProcessTime__c', processTime);
    }

    private virtual class ContactPerson extends Person {
      protected ContactPerson(SObject contact) {
        //calling "super" means "call the constructor
        //of the class I am derived from"
        super(contact);
      }
    }

    private virtual class LeadPerson extends Person {
      protected final Lead lead;
      protected LeadPerson(SObject lead) {
        super(lead);
        this.lead = (Lead)lead;
      }
    }

    public virtual class DealBreakerPerson extends LeadPerson implements IDealBreaker {
        private final String dealBreakerReason;
        protected DealBreakerPerson(Lead lead, String dealBreakerReason) {
            super(lead);
            this.dealBreakerReason = dealBreakerReason;
        }

        public virtual override void process(Datetime processTime) {
            super.process(processTime);
        }

        public String getDealBreakerReason() {
            return this.dealBreakerReason;
        }
    }

    //this class declaration is quickly becoming an eyesore ...
    public virtual class SpecialDealBreakerPerson extends DealBreakerPerson implements ISpecialDealBreaker {
        protected SpecialDealBreakerPerson(Lead lead, String dealBreakerReason) {
            super(lead, dealBreakerReason);
        }

        //by leaving this method signature blank
        //we are borrowing from the Null Object pattern
        //look it up, it's worth it!
        public override void process(Datetime processTime) {}

        public Boolean isVIPLead() {
            //use of the ternary to make this operation always safe
            List<String> descriptionWords = this.lead.Description != null ?
             this.lead.Description.split(' ') :
             new List<String>();
            Boolean hasMatch = false;
            for(String descriptionWord : descriptionWords) {
                if(descriptionWord.equalsIgnoreCase('SPECIALKEYWORD')) {
                    hasMatch = true;
                    break;
                }
                //you could keep going with this logic
                //testing different keywords
            }
            return hasMatch;
        }
    }
  }