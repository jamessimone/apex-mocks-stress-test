public class ListIterator implements System.Iterator<SObject> {
    private final List<SObject> records;
    private Integer index;

    public ListIterator(List<SObject> records) {
        this.records = records;
        this.index = 0;
    }

    public boolean hasNext() {
        return this.index < this.records.size() - 1;
    }

    public SObject next() {
        if(index == records.size() -1) {
            return null;
        }
        index++;
        return records[index];
    }
}