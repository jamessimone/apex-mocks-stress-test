public without sharing class RollupCalculator implements Queueable {
  private final List<SObject> calcItems;
  private final Map<Id, SObject> oldCalcItems;
  private final SObjectField opField;
  private final SObjectField lookupFieldOnCalcItem;
  private final SObjectField lookupField;
  private final SObjectField lookupObjOpField;
  private final SObjectType lookupObj;
  private final Op op;

  private enum Op {
    SUM,
    UPDATE_SUM,
    DELETE_SUM
  } //AVG, MAX, MIN, COUNT operations can be added as needed

  private RollupCalculator(
    List<SObject> calcItems,
    SObjectField opField,
    SObjectField lookupFieldOnCalcItem,
    SObjectField lookupField,
    SObjectField lookupObjOpField,
    SObjectType lookupObj,
    Op op,
    Map<Id, SObject> oldCalcItems
  ) {
    this.calcItems = calcItems;
    this.opField = opField;
    this.lookupFieldOnCalcItem = lookupFieldOnCalcItem;
    this.lookupField = lookupField;
    this.lookupObjOpField = lookupObjOpField;
    this.lookupObj = lookupObj;
    this.op = op;
    this.oldCalcItems = oldCalcItems;
  }

  public void execute(System.QueueableContext qc) {
    Map<String, List<SObject>> calcItemsByLookupField = this.getCalcItemsByLookupField();
    List<SObject> lookupItems = this.getLookupItems(calcItemsByLookupField.keySet());
    this.performRollup(calcItemsByLookupField, lookupItems);
  }

  public interface Evaluator {
    Boolean matches(Object item);
  }

  /**
    Rollup calculation section. Any time a new rollup calculation type is added, the three different operation types:
        - insert
        - update
        - delete
    need to be added. Afterwards, the object itself is enqueued to handle the actual processing.
  */

  // TODO: eval should be an optional argument, and there should be a singleton "always true" case handled internally here

  public static void sum(
    List<SObject> calcItems,
    SObjectField sumField,
    SObjectField lookupFieldOnCalcItem,
    SObjectField lookupField,
    SObjectField lookupObjSumField,
    Evaluator eval,
    SObjectType lookupObj
  ) {
    enqueue(calcItems, sumField, lookupFieldOnCalcItem, lookupField, lookupObjSumField, lookupObj, Op.SUM, eval, null);
  }

  public static void updateSum(
    List<SObject> calcItems,
    SObjectField sumField,
    SObjectField lookupFieldOnCalcItem,
    SObjectField lookupField,
    SObjectField lookupObjSumField,
    Evaluator eval,
    SObjectType lookupObj,
    Map<Id, SObject> oldCalcItems
  ) {
    enqueue(calcItems, sumField, lookupFieldOnCalcItem, lookupField, lookupObjSumField, lookupObj, Op.UPDATE_SUM, eval, oldCalcItems);
  }

  public static void deleteSum(
    List<SObject> calcItems,
    SObjectField sumField,
    SObjectField lookupFieldOnCalcItem,
    SObjectField lookupField,
    SObjectField lookupObjSumField,
    Evaluator eval,
    SObjectType lookupObj
  ) {
    enqueue(calcItems, sumField, lookupFieldOnCalcItem, lookupField, lookupObjSumField, lookupObj, Op.DELETE_SUM, eval, null);
  }

  private static void enqueue(
    List<SObject> calcItems,
    SObjectField opField,
    SObjectField lookupFieldOnCalcItem,
    SObjectField lookupField,
    SObjectField lookupObjOpField,
    SObjectType lookupObj,
    Op op,
    Evaluator eval,
    Map<Id, SObject> oldCalcItems
  ) {
    List<SObject> applicableCalcItems = filter(calcItems, eval);
    if (applicableCalcItems.isEmpty()) {
      return;
    }
    //TODO: do this by platform event with a fallback to queueable instead
    System.enqueueJob(
      new RollupCalculator(calcItems, opField, lookupFieldOnCalcItem, lookupField, lookupObjOpField, lookupObj, op, oldCalcItems)
    );
  }
  // end public-facing section

  private static List<SObject> filter(List<SObject> calcItems, Evaluator eval) {
    List<SObject> applicableItems = new List<SObject>();
    for (SObject calcItem : calcItems) {
      if (eval.matches(calcItem)) {
        applicableItems.add(calcItem);
      }
    }
    return applicableItems;
  }

  private Map<String, List<SObject>> getCalcItemsByLookupField() {
    Map<String, List<SObject>> lookupFieldToCalcItems = new Map<String, List<SObject>>();
    for (SObject calcItem : this.calcItems) {
      String key = (String) calcItem.get(this.lookupFieldOnCalcItem);
      if (lookupFieldToCalcItems.containsKey(key) == false) {
        lookupFieldToCalcItems.put(key, new List<SObject>{ calcItem });
      } else {
        lookupFieldToCalcItems.get(key).add(calcItem);
      }
    }
    return lookupFieldToCalcItems;
  }

  private List<SObject> getLookupItems(Set<String> objIds) {
    String queryString =
      'SELECT Id, ' +
      this.lookupObjOpField.getDescribe().getName() +
      '\nFROM ' +
      this.lookupObj.getDescribe().getName() +
      '\nWHERE ' +
      this.lookupField.getDescribe().getName() +
      ' = :objIds';
    return Database.query(queryString);
  }

  private void performRollup(Map<String, List<SObject>> calcItemsByLookupField, List<SObject> lookupItems) {
    List<SObject> toUpdate = new List<SObject>();
    for (SObject lookupRecord : lookupItems) {
      String key = (String) lookupRecord.get(this.lookupField);
      if (calcItemsByLookupField.containsKey(key) == false) {
        continue;
      }

      List<SObject> calcItems = calcItemsByLookupField.get(key);
      Object priorVal = lookupRecord.get(this.lookupObjOpField);
      Object newVal = this.getRollupVal(calcItems, priorVal);
      lookupRecord.put(this.lookupObjOpField, newVal);
      toUpdate.add(lookupRecord);
    }

    update toUpdate;
  }

  private Object getRollupVal(List<SObject> calcItems, Object priorVal) {
    Rollup rollup = this.getRollupType(priorVal);
    for (SObject calcItem : calcItems) {
      rollup.performRollup(this.op, priorVal, calcItem, this.oldCalcItems, this.opField.getDescribe().getName());
    }
    return rollup.getReturnValue();
  }

  private Rollup getRollupType(Object priorVal) {
    if (priorVal instanceof Decimal) {
      return new DecimalRollup(priorVal);
    } else {
      throw new IllegalArgumentException('Rollup operation not defined for: ' + JSON.serialize(priorVal));
    }
  }

  private abstract class Rollup {
    protected Object returnVal;
    public Rollup(Object returnVal) {
      this.returnVal = returnVal;
    }
    public Object getReturnValue() {
      return returnVal;
    }
    public abstract void performRollup(Op op, Object priorVal, SObject calcItem, Map<Id, SObject> oldCalcItems, String operationField);
  }

  private class DecimalRollup extends Rollup {
    public DecimalRollup(Object priorVal) {
      super(priorVal == null ? 0 : priorVal);
    }

    public override void performRollup(
      Op operation,
      Object priorVal,
      SObject calcItem,
      Map<Id, SObject> oldCalcItems,
      String operationField
    ) {
      Decimal returnVal = (Decimal) this.returnVal;
      switch on operation {
        when SUM {
          returnVal += (Decimal) calcItem.get(operationField);
        }
        when DELETE_SUM {
          returnVal -= (Decimal) calcItem.get(operationField);
        }
        when UPDATE_SUM {
          Decimal oldVal = (Decimal) oldCalcItems.get(calcItem.Id).get(operationField);
          Decimal newVal = (Decimal) calcItem.get(operationField);
          returnVal += (newVal - oldVal); // could be negative, could be positive
        }
        when else {
          throw new IllegalArgumentException('Other rollup op: ' + operation.name() + ' not yet implemented');
        }
      }
    }
  }
}
