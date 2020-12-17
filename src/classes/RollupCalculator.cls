public without sharing class RollupCalculator implements Queueable {
  private final List<SObject> calcItems;
  private final Map<Id, SObject> oldCalcItems;
  private final String opField;
  private final String lookupFieldOnCalcItem;
  private final String lookupField;
  private final String lookupObjOpField;
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
    String opField,
    String lookupFieldOnCalcItem,
    String lookupField,
    String lookupObjOpField,
    SObjectType lookupObj,
    Op op,
    Map<Id, SObject> oldCalcItems,
    Evaluator eval
  ) {
    this.calcItems = this.filter(calcItems, eval);
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

  public void execute(System.QueueableContext qc) {
    for (RollupCalculator calc : this.calculators) {
      Map<String, List<SObject>> calcItemsByLookupField = this.getCalcItemsByLookupField(calc);
      List<SObject> lookupItems = this.getLookupItems(calcItemsByLookupField.keySet());
      this.performRollup(calc, calcItemsByLookupField, lookupItems);
    }
  }

  public interface Evaluator {
    Boolean matches(Object item);
  }

  /**
   * public facing Rollup calculation section
   * - trigger context operations
   * - TODO: invocable, and scheduled invocations (need to pass list, oldMap, and Op enum explicitly)
   * - Batch
   */

  public static void batch(RollupCalculator calc, RollupCalculator secondCalc) {
    batch(new List<RollupCalculator>{ calc, secondCalc });
  }

  public static void batch(RollupCalculator calc, RollupCalculator secondCalc, RollupCalculator thirdCalc) {
    batch(new List<RollupCalculator>{ calc, secondCalc, thirdCalc });
  }

  public static void batch(List<RollupCalculator> calcs) {
    RollupCalculator batchCalculator = new RollupCalculator();
    for (RollupCalculator calc : calcs) {
      processOrDefer(calc, batchCalculator);
    }
    System.enqueueJob(batchCalculator);
  }

  public static RollupCalculator sumFromTrigger(
    String sumFieldOnCalcItem,
    String lookupFieldOnCalcItem,
    String lookupFieldOnOpObject,
    String sumFieldOnOpOject
  ) {
    return rollupFromTrigger(sumFieldOnCalcItem, lookupFieldOnCalcItem, lookupFieldOnOpObject, sumFieldOnOpOject, Op.SUM.name(), null);
  }
  // end public-facing section

  private static RollupCalculator rollupFromTrigger(
    String rollupFieldOnCalcItem,
    String lookupFieldOnCalcItem,
    String lookupFieldOnOpObject,
    String rollupFieldOnOpObject,
    String rollupOperation,
    Evaluator eval
  ) {
    String triggerContextAndRollupOp = '';
    Boolean shouldReturnNull = false;
    List<SObject> calcItems;
    Map<Id, SObject> oldCalcItems;

    switch on Trigger.operationType {
      when AFTER_INSERT {
        triggerContextAndRollupOp += rollupOperation;
        calcItems = Trigger.new;
      }
      when AFTER_UPDATE {
        triggerContextAndRollupOp = 'UPDATE_' + rollupOperation;
        calcItems = Trigger.new;
        oldCalcItems = Trigger.oldMap;
      }
      when BEFORE_DELETE {
        triggerContextAndRollupOp = 'DELETE_' + rollupOperation;
        calcItems = Trigger.old;
      }
      when else {
        shouldReturnNull = true;
      }
    }
    if (shouldReturnNull) {
      return null;
    }
    SObjectType sObjectType = records.getSObjectType();
    Op rollupOp = getOpFromTriggerContext(triggerContextAndRollupOp);

    RollupCalculator calc = new RollupCalculator(
      calcItems,
      rollupFieldOnCalcItem,
      lookupFieldOnCalcItem,
      lookupFieldOnOpObject,
      rollupFieldOnOpObject,
      sObjectType,
      rollupOp,
      oldCalcItems,
      eval
    );
    return processOrDefer(calc, null);
  }

  private static Op getOpFromTriggerContext(String rollupOperation) {
    Op rollupOp;
    for (Op operation : op.values()) {
      if (operation.name() == rollupOperation) {
        rollupOp = operation;
        break;
      }
    }
    return rollupOp;
  }

  private static RollupCalculator processOrDefer(RollupCalculator calc, RollupCalculator batchCalc) {
    if (batchCalc != null && calc != null && calc.isNoOp == false) {
      batchCalc.calculators.add(calc);
      return batchCalc;
    } else if (calc != null && calc.isNoOp == false) {
      calc.calculators.add(calc);
      System.enqueueJob(calc);
    }
    return calc;
  }

  private List<SObject> filter(List<SObject> calcItems, Evaluator eval) {
    List<SObject> applicableItems = new List<SObject>();
    for (SObject calcItem : calcItems) {
      if (eval == null || eval.matches(calcItem)) {
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
    String queryString = 'SELECT Id, ' + this.lookupObjOpField + '\nFROM ' + this.lookupObj + '\nWHERE ' + this.lookupField + ' = :objIds';
    return Database.query(queryString);
  }

  private void performRollup(RollupCalculator calc, Map<String, List<SObject>> calcItemsByLookupField, List<SObject> lookupItems) {
    List<SObject> toUpdate = new List<SObject>();
    for (SObject lookupRecord : lookupItems) {
      String key = (String) lookupRecord.get(calc.lookupField);
      if (calcItemsByLookupField.containsKey(key) == false) {
        List<SObject> calcItems = calcItemsByLookupField.get(key);
        Object priorVal = lookupRecord.get(calc.lookupObjOpField);
        Object newVal = this.getRollupVal(calc, calcItems, priorVal);
        lookupRecord.put(calc.lookupObjOpField, newVal);
        toUpdate.add(lookupRecord);
      }
    }

    update toUpdate;
  }

  private Object getRollupVal(RollupCalculator calc, List<SObject> calcItems, Object priorVal) {
    Rollup rollup = this.getRollupType(priorVal);
    for (SObject calcItem : calcItems) {
      rollup.performRollup(calc.op, priorVal, calcItem, calc.oldCalcItems, calc.opField);
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
