public class ApiHandlerAccount extends Api.Handler {
    public final static String NOT_FOUND = 'Account Not Found';

    private final IRepository accountRepo;

    public ApiHandlerAccount() {
        super();
        //install your dependencies via the Factory
        this.accountRepo = Factory.getFactory().RepoFactory.getAccountRepo();
    }

    public override Api.Response doGet(ApiRequestResolver resolver) {
        Id accountId = Id.valueOf(resolver.RequestUrlBody);
        List<Account> accounts = this.accountRepo.get(new Query(Account.Id, Query.Operator.EQUALS, accountId));
        Account acc = accounts.size() > 0 ? accounts[0] : new Account(Name = NOT_FOUND);

        Api.Response res = this.getResponse(Json.serialize(acc));
        res.Success = accounts.size() > 0;
        return res;
    }
}