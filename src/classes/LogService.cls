@RestResource(urlMapping='/logs/*')
global class LogService {
    @HttpGet
    global static Map<String, String> getLogs() {
        return new ToolingApi().getLogs();
    }
}