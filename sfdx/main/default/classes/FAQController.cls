public class FAQController {

    @AuraEnabled(cacheable=true)
    public static List<FAQ> getFAQs() {
        List<FAQ> faqs = new List<FAQ>();
        for(Integer index = 0; index < 100; index++) {
            String indexString = String.valueOf(index);
            faqs.add(new FAQ('Question for ' + indexString, 'Answer for' + indexString));
        }
        return faqs;
    }

    public class FAQ {
        public FAQ(String question, String answer) {
            this.question = question;
            this.answer = answer;
        }
        public String question { get; private set; }
        public String answer { get; private set; }
    }
}