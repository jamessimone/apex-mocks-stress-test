public class Callout {
    private static final Integer DEFAULT_TIMEOUT = 10000;

    public Callout(String jsonString, Url endpoint, RestMethod method, Integer millisecondTimeout, Type callbackType) {
        this.BodyString = jsonString;
        //Type.forName throws for nulls, alas
        this.CallbackName = callbackType == null ? '' : callbackType.getName();
        this.Endpoint = endpoint.toExternalForm();
        this.RestMethod = method.name();
        this.Timeout = millisecondTimeout;
    }

    public Callout(String jsonString, Url endpoint, RestMethod method, Type callbackType) {
        //10 seconds is the default timeout
        this(jsonString, endpoint, method, DEFAULT_TIMEOUT, callbackType);
    }

    public Callout (String jsonString, Url endpoint, RestMethod method) {
        this(jsonString, endpoint, method, null);
    }

    //sometimes an api key is supplied as part of the URL ...
    //because it's not always necessary, we make it a public member of the class
    public String ApiKey { get; set; }

    public String BodyString { get; private set; }
    public String CallbackName { get; private set; }
    public String Endpoint { get; private set; }
    public String RestMethod { get; private set; }
    public Integer Timeout { get; private set; }
}