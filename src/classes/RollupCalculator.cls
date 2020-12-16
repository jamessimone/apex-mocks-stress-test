public without sharing class RollupCalculator implements Queueable {
  private final List<SObject> calcItems;
  private final Map<Id, SObject> oldCalcItems;
  private final SObjectField opField;
  private final SObjectField lookupFieldOnCalcItem;
  private final SObjectField lookupField;
  private final SObjectField lookupObjOpField;
  private final SObjectType lookupObj;
  private final Op op;
  private final Boolean isNoOp;
  private final Boolean isBatched;

  private List<RollupCalculator> calculators {
    get {
      if (calculators == null) {
        calculators = new List<RollupCalculator>();
      }
      return calculators;
    }
    set;
  }

  private enum Op {
    SUM,
    UPDATE_SUM,
    DELETE_SUM
  } //AVG, MAX, MIN, COUNT operations can be added as needed

  private RollupCalculator() {
    this.isBatched = true;
  }

  private RollupCalculator(
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
    Evaluator evaluator = eval == null ? alwaysTrue : eval;
    this.calcItems = this.filter(calcItems, evaluator);
    this.opField = opField;
    this.lookupFieldOnCalcItem = lookupFieldOnCalcItem;
    this.lookupField = lookupField;
    this.lookupObjOpField = lookupObjOpField;
    this.lookupObj = lookupObj;
    this.op = op;
    this.oldCalcItems = oldCalcItems;
    this.isNoOp = this.calcItems.isEmpty() == false;
    this.isBatched = false;
  }

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
    this(calcItems, opField, lookupFieldOnCalcItem, lookupField, lookupObjOpField, lookupObj, op, null, null);
  }

  private RollupCalculator(
    List<SObject> calcItems,
    SObjectField opField,
    SObjectField lookupFieldOnCalcItem,
    SObjectField lookupField,
    SObjectField lookupObjOpField,
    SObjectType lookupObj,
    Op op
  ) {
    this(calcItems, opField, lookupFieldOnCalcItem, lookupField, lookupObjOpField, lookupObj, op, null, null);
  }

  private RollupCalculator(
    List<SObject> calcItems,
    SObjectField opField,
    SObjectField lookupFieldOnCalcItem,
    SObjectField lookupField,
    SObjectField lookupObjOpField,
    SObjectType lookupObj,
    Op op,
    Evaluator eval
  ) {
    this(calcItems, opField, lookupFieldOnCalcItem, lookupField, lookupObjOpField, lookupObj, op, eval, null);
  }

  public void execute(System.QueueableContext qc) {
    if (this.isBatched == false) {
      this.calculators.add(this);
    }
    for (RollupCalculator calc : this.calculators) {
      Map<String, List<SObject>> calcItemsByLookupField = this.getCalcItemsByLookupField(calc);
      List<SObject> lookupItems = this.getLookupItems(calcItemsByLookupField.keySet());
      this.performRollup(calc, calcItemsByLookupField, lookupItems);
    }
  }

  public interface Evaluator {
    Boolean matches(Object item);
  }

  // Singleton for use when Evaluator is not passed
  private static final Evaluator alwaysTrue = new AlwaysTrue();
  private class AlwaysTrue implements Evaluator {
    public Boolean matches(Object item) {
      return true;
    }
  }

  /**
   * public facing Rollup calculation section
   * - insert
   * - update
   * - delete
   * - plus the special wrapper, Batch
   */

  public static void batch(RollupCalculator calc, RollupCalculator secondCalc) {
    RollupCalculator batchCalculator = processOrDefer(calc, new RollupCalculator());
    processOrDefer(secondCalc, batchCalculator);
  }

  public static void batch(RollupCalculator calc, RollupCalculator secondCalc, RollupCalculator thirdCalc) {
    RollupCalculator batchCalculator = processOrDefer(calc, new RollupCalculator());
    processOrDefer(secondCalc, batchCalculator);
    processOrDefer(thirdCalc, batchCalculator);
  }

  public static void batch(List<RollupCalculator> calcs) {
    RollupCalculator batchCalculator = new RollupCalculator();
    for (RollupCalculator calc : calcs) {
      processOrDefer(calc, batchCalculator);
    }
    System.enqueueJob(batchCalculator);
  }

  public static RollupCalculator sum(
    List<SObject> calcItems,
    SObjectField sumField,
    SObjectField lookupFieldOnCalcItem,
    SObjectField lookupField,
    SObjectField lookupObjSumField,
    Evaluator eval,
    SObjectType lookupObj
  ) {
    RollupCalculator calc = new RollupCalculator(calcItems, sumField, lookupFieldOnCalcItem, lookupField, lookupObjSumField, lookupObj, Op.SUM, eval);
    return processOrDefer(calc, null);
  }

  public static RollupCalculator updateSum(
    List<SObject> calcItems,
    SObjectField sumField,
    SObjectField lookupFieldOnCalcItem,
    SObjectField lookupField,
    SObjectField lookupObjSumField,
    Evaluator eval,
    SObjectType lookupObj,
    Map<Id, SObject> oldCalcItems
  ) {
    RollupCalculator calc = new RollupCalculator(
      calcItems,
      sumField,
      lookupFieldOnCalcItem,
      lookupField,
      lookupObjSumField,
      lookupObj,
      Op.UPDATE_SUM,
      eval,
      oldCalcItems
    );
    return processOrDefer(calc, null);
  }

  public static RollupCalculator deleteSum(
    List<SObject> calcItems,
    SObjectField sumField,
    SObjectField lookupFieldOnCalcItem,
    SObjectField lookupField,
    SObjectField lookupObjSumField,
    Evaluator eval,
    SObjectType lookupObj
  ) {
    RollupCalculator calc = new RollupCalculator(calcItems, sumField, lookupFieldOnCalcItem, lookupField, lookupObjSumField, lookupObj, Op.DELETE_SUM, eval);
    return processOrDefer(calc, null);
  }
  // end public-facing section

  private static RollupCalculator processOrDefer(RollupCalculator calc, RollupCalculator batchCalc) {
    if (batchCalc != null && calc.isNoOp == false) {
      batchCalc.calculators.add(calc);
      return batchCalc;
    } else {
      System.enqueueJob(calc);
    }
    return calc;
  }

  private List<SObject> filter(List<SObject> calcItems, Evaluator eval) {
    List<SObject> applicableItems = new List<SObject>();
    for (SObject calcItem : calcItems) {
      if (eval.matches(calcItem)) {
        applicableItems.add(calcItem);
      }
    }
    return applicableItems;
  }

  private Map<String, List<SObject>> getCalcItemsByLookupField(RollupCalculator calc) {
    Map<String, List<SObject>> lookupFieldToCalcItems = new Map<String, List<SObject>>();
    for (SObject calcItem : calc.calcItems) {
      String key = (String) calcItem.get(calc.lookupFieldOnCalcItem);
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

  private void performRollup(RollupCalculator calc, Map<String, List<SObject>> calcItemsByLookupField, List<SObject> lookupItems) {
    List<SObject> toUpdate = new List<SObject>();
    for (SObject lookupRecord : lookupItems) {
      String key = (String) lookupRecord.get(calc.lookupField);
      if (calcItemsByLookupField.containsKey(key) == false) {
        continue;
      }

      List<SObject> calcItems = calcItemsByLookupField.get(key);
      Object priorVal = lookupRecord.get(calc.lookupObjOpField);
      Object newVal = this.getRollupVal(calc, calcItems, priorVal);
      lookupRecord.put(calc.lookupObjOpField, newVal);
      toUpdate.add(lookupRecord);
    }

    update toUpdate;
  }

  private Object getRollupVal(RollupCalculator calc, List<SObject> calcItems, Object priorVal) {
    Rollup rollup = this.getRollupType(priorVal);
    for (SObject calcItem : calcItems) {
      rollup.performRollup(calc.op, priorVal, calcItem, calc.oldCalcItems, calc.opField.getDescribe().getName());
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

    public override void performRollup(Op operation, Object priorVal, SObject calcItem, Map<Id, SObject> oldCalcItems, String operationField) {
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
