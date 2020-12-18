public without sharing class RollupCalculator implements Queueable {
  @testVisible
  private static Boolean shouldRunFromTrigger = System.Trigger.isExecuting;

  private final List<SObject> calcItems;
  private final Map<Id, SObject> oldCalcItems;
  private final SObjectField opFieldOnCalcItem;
  private final SObjectField lookupFieldOnCalcItem;
  private final SObjectField lookupFieldOnLookupObject;
  private final SObjectField opFieldOnLookupObject;
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
    SObjectField opFieldOnCalcItem,
    SObjectField lookupFieldOnCalcItem,
    SObjectField lookupFieldOnLookupObject,
    SObjectField opFieldOnLookupObject,
    SObjectType lookupObj,
    Op op,
    Map<Id, SObject> oldCalcItems,
    Evaluator eval
  ) {
    this.calcItems = this.filter(calcItems, eval);
    this.opFieldOnCalcItem = opFieldOnCalcItem;
    this.lookupFieldOnCalcItem = lookupFieldOnCalcItem;
    this.lookupFieldOnLookupObject = lookupFieldOnLookupObject;
    this.opFieldOnLookupObject = opFieldOnLookupObject;
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

  // TODO: Eval overload method
  public static RollupCalculator sumFromTrigger(
    SObjectField sumFieldOnCalcItem,
    SObjectField lookupFieldOnCalcItem,
    SObjectField lookupFieldOnOpObject,
    SObjectField sumFieldOnOpOject
  ) {
    //                                                                                                                         eval, batchCalc
    return rollupFromTrigger(sumFieldOnCalcItem, lookupFieldOnCalcItem, lookupFieldOnOpObject, sumFieldOnOpOject, Op.SUM.name(), null, null);
  }

  public static RollupCalculator runFromTrigger() {
    // this can be overridden, but only in tests
    if (shouldRunFromTrigger == false) {
      return null;
    }
    // otherwise, there are only three allowed trigger operations that qualify. if the operation type running is not one of those, return early
    if (
      Trigger.operationType != TriggerOperation.AFTER_INSERT &&
      Trigger.operationType != TriggerOperation.AFTER_UPDATE &&
      Trigger.operationType != TriggerOperation.BEFORE_DELETE
    ) {
      return null;
    }

    SObjectType triggerSObjectType = Trigger.isDelete ? Trigger.old.getSObjectType() : Trigger.new.getSObjectType();
    DescribeSObjectResult describeForSObject = triggerSObjectType.getDescribe();
    List<Rollup__mdt> rollupOperations = [
      SELECT CalcItem__c, RollupFieldOnCalcItem__c, LookupObject__c, LookupFieldOnCalcItem__c, RollupFieldOnLookupObject__c, RollupType__c
      FROM Rollup__mdt
      WHERE CalcItem__c = :describeForSObject.getName()
    ];

    if (rollupOperations.isEmpty()) {
      return null;
    }

    /**
     * We have rollup operations to perform. That's great! BUT Field Definition CMDT records are stored like such: `Account.NumberOfEmployees`
     * Frustratingly, the generic "put" operation for SObjects (necessary later) doesn't support these "full length" field names
     * (nor can you retrieve them from the "fieldNameToField" map below). Let's pare them down and get ready to rollup!
     */
    RollupCalculator batchCalc = new RollupCalculator();
    Map<String, SObjectField> fieldNameToField = describeForSObject.fields.getMap();
    for (Rollup__mdt rollupMetadata : rollupOperations) {
      SObjectField rollupFieldOnCalcItem = fieldNameToField.get(getParedFieldName(rollupMetadata.RollupFieldOnCalcItem__c, describeForSObject));
      SObjectField lookupFieldOnCalcItem = fieldNameToField.get(getParedFieldName(rollupMetadata.LookupFieldOnCalcItem__c, describeForSObject));

      // It ain't pretty, but it works. Oddly, attempts to directly construct the SObjectType class from Type.forName always seem to return ...
      // the SObject Type. If anybody has more success with this, let me know!
      DescribeSObjectResult lookupObjectDescribe = ((SObject) Type.forName(rollupMetadata.LookupObject__c).newInstance()).getSObjectType().getDescribe();

      Map<String, SObjectField> lookupFieldNameToLookupFields = lookupObjectDescribe.fields.getMap();
      SObjectField lookupFieldOnOpObject = lookupFieldNameToLookupFields.get(
        getParedFieldName(rollupMetadata.LookupFieldOnLookupObject__c, lookupObjectDescribe)
      );
      SObjectField rollupFieldOnOpObject = lookupFieldNameToLookupFields.get(
        getParedFieldName(rollupMetadata.RollupFieldOnLookupObject__c, lookupObjectDescribe)
      );
      // adds to the batch, TODO: still need to perform processing cleanly ...
      rollupFromTrigger(
        lookupFieldOnCalcItem,
        lookupFieldOnCalcItem,
        lookupFieldOnOpObject,
        rollupFieldOnOpObject,
        rollupMetadata.RollupType__c,
        null,
        batchCalc
      );
    }
    return batchCalc;
  }
  // end public-facing section

  private static String getParedFieldName(String fullFieldName, DescribeSObjectResult describeForSObject) {
    return fullFieldName.replace(describeForSObject.getName() + '.', '');
  }

  private static RollupCalculator rollupFromTrigger(
    SObjectField rollupFieldOnCalcItem,
    SObjectField lookupFieldOnCalcItem,
    SObjectField lookupFieldOnOpObject,
    SObjectField rollupFieldOnOpObject,
    String rollupOperation,
    Evaluator eval,
    RollupCalculator batchCalc
  ) {
    String triggerContextAndRollupOp = '';
    Boolean shouldReturnNull = false;
    List<SObject> calcItems;
    Map<Id, SObject> oldCalcItems;

    switch on Trigger.operationType {
      when AFTER_INSERT {
        calcItems = Trigger.new;
      }
      when AFTER_UPDATE {
        triggerContextAndRollupOp = 'UPDATE_';
        calcItems = Trigger.new;
        oldCalcItems = Trigger.oldMap;
      }
      when BEFORE_DELETE {
        triggerContextAndRollupOp = 'DELETE_';
        calcItems = Trigger.old;
      }
      when else {
        shouldReturnNull = true;
      }
    }
    if (shouldReturnNull) {
      return null;
    }
    // for AFTER_INSERT, the base operation name will always be used
    triggerContextAndRollupOp += rollupOperation;
    SObjectType sObjectType = calcItems.getSObjectType();
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
    return processOrDefer(calc, batchCalc);
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
    String queryString = 'SELECT Id, ' + this.opFieldOnLookupObject + '\nFROM ' + this.lookupObj + '\nWHERE ' + this.lookupFieldOnLookupObject + ' = :objIds';
    return Database.query(queryString);
  }

  private void performRollup(RollupCalculator calc, Map<String, List<SObject>> calcItemsByLookupField, List<SObject> lookupItems) {
    List<SObject> toUpdate = new List<SObject>();
    for (SObject lookupRecord : lookupItems) {
      String key = (String) lookupRecord.get(calc.lookupFieldOnLookupObject);
      if (calcItemsByLookupField.containsKey(key) == false) {
        List<SObject> calcItems = calcItemsByLookupField.get(key);
        Object priorVal = lookupRecord.get(calc.opFieldOnLookupObject);
        Object newVal = this.getRollupVal(calc, calcItems, priorVal);
        lookupRecord.put(calc.opFieldOnLookupObject, newVal);
        toUpdate.add(lookupRecord);
      }
    }

    update toUpdate;
  }

  private Object getRollupVal(RollupCalculator calc, List<SObject> calcItems, Object priorVal) {
    Rollup rollup = this.getRollupType(priorVal);
    for (SObject calcItem : calcItems) {
      rollup.performRollup(calc.op, priorVal, calcItem, calc.oldCalcItems, calc.opFieldOnCalcItem);
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
    public abstract void performRollup(Op op, Object priorVal, SObject calcItem, Map<Id, SObject> oldCalcItems, SObjectField operationField);
  }

  private class DecimalRollup extends Rollup {
    public DecimalRollup(Object priorVal) {
      super(priorVal == null ? 0 : priorVal);
    }

    public override void performRollup(Op operation, Object priorVal, SObject calcItem, Map<Id, SObject> oldCalcItems, SObjectField operationField) {
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
