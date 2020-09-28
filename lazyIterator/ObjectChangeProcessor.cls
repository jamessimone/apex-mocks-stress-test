public class ObjectChangeProcessor {
  private LazyIterator iterator;
  private List<Function> functions;

  //assumes objects are in the same order
  //as in Trigger.oldRecord, Trigger.new
  public ObjectChangeProcessor(List<SObject> oldObjects, List<SObject> newObjects) {
    this(new LazySObjectPairIterator(oldObjects, newObjects));
  }

  public ObjectChangeProcessor(List<SObject> records) {
    this(new LazySObjectIterator(records.iterator()));
  }

  private ObjectChangeProcessor(LazyIterator iterator) {
    this.iterator = iterator;
    this.functions = new List<Function>();
  }

  public ObjectChangeProcessor addFunction(Function func) {
    this.functions.add(func);
    return this;
  }

  public void process() {
    this.iterator.forEach(this.functions);
  }

  public ObjectChangeProcessor filterByChangeInField(SObjectField field) {
    return this.filterByChangeInFields(new List<SObjectField>{ field });
  }

  public ObjectChangeProcessor filterByChangeInFields(List<SObjectField> fields) {
    this.iterator = new LazyFilterIterator(this.iterator, new FieldChangedFilterProcessor(fields));
    return this;
  }

  public ObjectChangeProcessor filter(BooleanFunction function) {
    this.iterator = new LazyFilterIterator(this.iterator, function);
    return this;
  }

  public List<Object> toList(List<Object> toList) {
    return this.iterator.toList(toList);
  }

  class FieldChangedFilterProcessor implements BooleanFunction {
    private final List<SObjectField> fields;
    public FieldChangedFilterProcessor(SObjectField field) {
      this(new List<SObjectField>{ field });
    }
    public FieldChangedFilterProcessor(List<SObjectField> fields) {
      this.fields = fields;
    }

    public Boolean isTrueFor(Object obj) {
      SObjectWrapper wrapper = (SObjectWrapper)obj;
      Boolean hasMatch = false;
      Integer counter = 0;
      while(counter < this.fields.size() && !hasMatch) {
        hasMatch = wrapper.oldRecord.get(this.fields[counter]) != wrapper.newRecord.get(this.fields[counter]);
        counter++;
      }
      return hasMatch;
    }
  }

  virtual class LazyIterator implements Iterator<Object> {
    private final Iterator<Object> iterator;

    public LazyIterator(Iterator<Object> iterator) {
      this.iterator = iterator;
    }

    protected LazyIterator() {
      this.iterator = this;
    }

    public virtual Boolean hasNext() {
      return this.iterator.hasNext();
    }

    public virtual Object next() {
      return this.iterator.next();
    }

    public List<Object> toList(List<Object> toList) {
      while(this.hasNext()) {
        toList.add(this.next());
      }
      return toList;
    }

    public LazyIterator forEach(Function func) {
      return this.forEach(new List<Function>{ func });
    }
    public LazyIterator forEach(List<Function> funcs) {
      while(this.hasNext()) {
        Iterator<Function> funcIterator = funcs.iterator();
        Object nextObject = this.next();
        while(funcIterator.hasNext()) {
          Function func = funcIterator.next();
          func.call(nextObject);
        }
      }
      return this;
    }
  }

   virtual class LazySObjectPairIterator extends LazyIterator {
    private final Iterator<SObject> oldIterator;
    private final Iterator<SObject> newIterator;

    public LazySObjectPairIterator(List<SObject> oldObjects, List<SObject> newObjects) {
      super();
      this.newIterator = newObjects.iterator();
      this.oldIterator = oldObjects.iterator();
    }

    public override Boolean hasNext() {
      return this.oldIterator.hasNext() && this.newIterator.hasNext();
    }

    public override Object next() {
      return new SObjectWrapper(this.oldIterator.next(), this.newIterator.next());
    }
  }

  virtual class LazySObjectIterator extends LazyIterator {
    public LazySObjectIterator(Iterator<SObject> iterator) {
      super(iterator);
    }
  }

  virtual class LazyFilterIterator extends LazyIterator {
    private Object next;
    private final BooleanFunction filter;
    public LazyFilterIterator(LazyIterator iterator, BooleanFunction filter) {
      super(iterator);
      this.filter = filter;
    }

    public override Boolean hasNext() {
      if(super.hasNext()) {
        this.next = super.next();
        return this.filter.isTrueFor(this.next) ? true : this.hasNext();
      }

      return false;
    }

    public override Object next() {
      if(this.next != null && this.next instanceof SObjectWrapper) {
        return ((SObjectWrapper)this.next).newRecord;
      }
      return this.next;
    }
  }

  private class SObjectWrapper {
    public final SObject oldRecord, newRecord;
    public SObjectWrapper(SObject oldRecord, SObject newRecord) {
      this.oldRecord = oldRecord;
      this.newRecord = newRecord;
    }
  }
}