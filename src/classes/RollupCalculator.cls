public without sharing class RollupCalculator implements Queueable {
  @testVisible
  private static Boolean shouldRunFromTrigger = Trigger.isExecuting;
  @testVisible
  private static TriggerOperation triggerContext = Trigger.operationType;
  @testVisible
  private static List<SObject> triggerRecords;
  @testVisible
  private static Map<Id, SObject> oldTriggerRecordsMap;

  private final List<SObject> calcItems;
  private final Map<Id, SObject> oldCalcItems;
  private final SObjectField opFieldOnCalcItem;
  private final SObjectField lookupFieldOnCalcItem;
  private final SObjectField lookupFieldOnLookupObject;
  private final SObjectField opFieldOnLookupObject;
  private final SObjectType lookupObj;
  private final Op op;
  private final Boolean isBatched;

  // only non-final instance variable; can change for Batched rollups
  private Boolean isNoOp;

  private List<RollupCalculator> calculators {
    get {
      if (calculators == null) {
        calculators = new List<RollupCalculator>();
      }
      return calculators;
    }
    set;
  }

  private static Map<String, Op> opNameToOp {
    get {
      if(opNameToOp == null) {
        opNameToOp = new Map<String, Op>();
        for(Op operation : Op.values()) {
          opNameToOp.put(operation.name(), operation);
        }
      }
      return opNameToOp;
    }
    set;
  }

  private enum Op {
    SUM,
    UPDATE_SUM,
    DELETE_SUM,
    COUNT_DISTINCT,
    UPDATE_COUNT_DISTINCT,
    DELETE_COUNT_DISTINCT,
    COUNT,
    UPDATE_COUNT,
    DELETE_COUNT
  } //AVG, MAX, MIN operations can be added as needed

  private RollupCalculator() {
    this.isBatched = true;
    // a batch only becomes valid if other Calculators are added to it
    this.isNoOp = true;
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

  public interface Evaluator {
    Boolean matches(Object item);
  }

  public void runCalc() {
    if (this.isNoOp == false) {
      System.enqueueJob(this);
    }
  }

  public void execute(System.QueueableContext qc) {
    for (RollupCalculator calc : this.calculators) {
      Map<String, List<SObject>> calcItemsByLookupField = this.getCalcItemsByLookupField(calc);
      List<SObject> lookupItems = this.getLookupItems(calcItemsByLookupField.keySet());
      this.performRollup(calc, calcItemsByLookupField, lookupItems);
    }
  }

  /**
   * public facing Rollup calculation section
   * - Trigger operations
   * - TODO: invocable, and scheduled invocations (need to pass list, and Op enum explicitly)
   * - Batch
   */

  public class FlowInput {
      @InvocableVariable(label='Records to rollup to parent/related item(s)' required=true)
      public List<SObject> originalCollection;

      @InvocableVariable(label='Rollup target\'s SObject name' required=true)
      public String rollupSObjectName;
  }

  public class FlowOutput {
    public FlowOutput() {
      this.IsSuccess = true;
      this.Message = 'SUCCESS';
    }

    @InvocableVariable(label='Was rollup enqueued successfully?')
    public Boolean IsSuccess;
    @InvocableVariable(label='"SUCCESS" when IsSuccess is true, otherwise the encountered error message')
    public String Message;
  }

  @InvocableMethod(category='Rollups' label='Perform rollup on records' description='Returns a single FlowOutput record with "SUCCESS" as the message if async rollup operation is enqueued successfully, and the encountered error otherwise')
  public static List<FlowOutput> performRollup(List<FlowInput> flowInputs) {
    List<FlowOutput> flowOutputReturns = new List<FlowOutput>();
    try {
      FlowOutput flowOutput = new FlowOutput();
      flowOutputReturns.add(flowOutput);
    } catch(Exception ex) {
      FlowOutput flowOutput = new FlowOutput();
      flowOutput.IsSuccess = false;
      flowOutput.Message = ex.getMessage() + '\n' + ex.getStackTraceString();
    }
    return flowOutputReturns;
  }

  public static void batch(RollupCalculator calc, RollupCalculator secondCalc) {
    batch(new List<RollupCalculator>{ calc, secondCalc });
  }

  public static void batch(RollupCalculator calc, RollupCalculator secondCalc, RollupCalculator thirdCalc) {
    batch(new List<RollupCalculator>{ calc, secondCalc, thirdCalc });
  }

  public static void batch(List<RollupCalculator> calcs) {
    RollupCalculator batchCalculator = new RollupCalculator();
    for (RollupCalculator calc : calcs) {
      loadCalculators(calc, batchCalculator);
    }
    batchCalculator.runCalc();
  }

  public static RollupCalculator sumFromTrigger(
    SObjectField sumFieldOnCalcItem,
    SObjectField lookupFieldOnCalcItem,
    SObjectField lookupFieldOnOpObject,
    SObjectField sumFieldOnOpOject) {
      return sumFromTrigger(sumFieldOnCalcItem, lookupFieldOnCalcItem, lookupFieldOnOpObject, sumFieldOnOpOject, null);
  }

  public static RollupCalculator sumFromTrigger(
    SObjectField sumFieldOnCalcItem,
    SObjectField lookupFieldOnCalcItem,
    SObjectField lookupFieldOnOpObject,
    SObjectField sumFieldOnOpOject,
    Evaluator eval
  ) {
    return rollupFromTrigger(sumFieldOnCalcItem, lookupFieldOnCalcItem, lookupFieldOnOpObject, sumFieldOnOpOject, Op.SUM.name(), eval, null);
  }

  public static void runFromTrigger() {
    if (shouldRunFromTrigger() == false) {
      return;
    }

    DescribeSObjectResult describeForSObject = getTriggerRecords().getSObjectType().getDescribe();
    List<Rollup__mdt> rollupOperations = [
      SELECT CalcItem__c, RollupFieldOnCalcItem__c, LookupObject__c, LookupFieldOnCalcItem__c, RollupFieldOnLookupObject__c, RollupType__c
      FROM Rollup__mdt
      WHERE CalcItem__c = :describeForSObject.getName()
    ];

    if (rollupOperations.isEmpty()) {
      return;
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

      // NB - this SHOULD work even for SObjects part of managed packages
      DescribeSObjectResult lookupObjectDescribe = getDescribeFromSObjectName(rollupMetadata.LookupObject__c);
      Map<String, SObjectField> lookupFieldNameToLookupFields = lookupObjectDescribe.fields.getMap();
      SObjectField lookupFieldOnOpObject = lookupFieldNameToLookupFields.get(
        getParedFieldName(rollupMetadata.LookupFieldOnLookupObject__c, lookupObjectDescribe)
      );
      SObjectField rollupFieldOnOpObject = lookupFieldNameToLookupFields.get(
        getParedFieldName(rollupMetadata.RollupFieldOnLookupObject__c, lookupObjectDescribe)
      );

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
    batchCalc.runCalc();
  }
  // end public-facing section

  private static Boolean shouldRunFromTrigger() {
    // this can be overridden, but only in tests
    Boolean shouldRun = shouldRunFromTrigger;
    // otherwise, there are only three allowed trigger operations that qualify
    if (
      shouldRun &&
      triggerContext != TriggerOperation.AFTER_INSERT &&
      triggerContext != TriggerOperation.AFTER_UPDATE &&
      triggerContext != TriggerOperation.BEFORE_DELETE
    ) {
      shouldRun = false;
    }
    return shouldRun;
  }

  private static List<SObject> getTriggerRecords() {
    if (triggerRecords != null) {
      return triggerRecords;
    }
    return Trigger.isDelete ? Trigger.old : Trigger.new;
  }

  private static Map<Id, SObject> getOldTriggerRecordsMap() {
    return oldTriggerRecordsMap != null ? oldTriggerRecordsMap : Trigger.oldMap;
  }

  private static DescribeSObjectResult getDescribeFromSObjectName(String sobjectName) {
    return ((SObject) Type.forName(rollupMetadata.sobjectName).newInstance()).getSObjectType().getDescribe();
  }

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

    switch on triggerContext {
      when AFTER_INSERT, AFTER_UPDATE, BEFORE_DELETE {
        calcItems = getTriggerRecords();
        if (triggerContext == TriggerOperation.AFTER_UPDATE) {
          triggerContextAndRollupOp = 'UPDATE_';
          oldCalcItems = getOldTriggerRecordsMap();
        } else if (triggerContext == TriggerOperation.BEFORE_DELETE) {
          triggerContextAndRollupOp = 'DELETE_';
        }
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
    Op rollupOp = opNameToOp.get(triggerContextAndRollupOp);

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
    return loadCalculators(calc, batchCalc);
  }

  private static RollupCalculator loadCalculators(RollupCalculator calc, RollupCalculator batchCalc) {
    if (batchCalc != null && calc != null && calc.isNoOp == false) {
      batchCalc.calculators.add(calc);
      batchCalc.isNoOp = false;
    } else if (calc != null && calc.isNoOp == false) {
      calc.calculators.add(calc);
    }
    return batchCalc != null ? batchCalc : calc;
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
    Rollup rollup = this.getRollupType(priorVal, calc.op);
    for (SObject calcItem : calcItems) {
      rollup.performRollup(calc.op, priorVal, calcItem, calc.oldCalcItems, calc.opFieldOnCalcItem);
    }
    return rollup.getReturnValue();
  }

  private Rollup getRollupType(Object priorVal, Op operationType) {
    if(operationType.name().contains(RollupCalculator.Op.COUNT_DISTINCT.name())) {
      return new CountDistinctRollup(0);
    } else if(operationType.name().contains(RollupCalculator.Op.COUNT.name())) {
      return new CountRollup(priorVal);
    } else if (priorVal instanceof Decimal) {
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
    public virtual Object getReturnValue() {
      return returnVal;
    }
    public abstract void performRollup(Op op, Object priorVal, SObject calcItem, Map<Id, SObject> oldCalcItems, SObjectField operationField);
  }

  private virtual class DecimalRollup extends Rollup {
    public DecimalRollup(Object priorVal) {
      // much as it pains me to duplicate the null check, it must be done; we can't reference instance methods till after the super() call
      super(priorVal == null ? 0 : priorVal);
    }

    protected Decimal getDecimalOrDefault(Object potentiallyUnitializedDecimal) {
      return (Decimal) (potentiallyUnitializedDecimal == null ? 0 : potentiallyUnitializedDecimal);
    }

    protected virtual Decimal getNumericValue(SObject calcItem, SObjectField operationField) {
      return this.getDecimalOrDefault(calcItem.get(operationField));
    }

    protected virtual Decimal getNumericChangedValue(SObject calcItem, SObjectfield operationField, Map<Id, SObject> oldCalcItems) {
      Decimal newVal = this.getNumericValue(calcItem, operationField);
      Decimal oldVal = this.getNumericValue(oldCalcItems.get(calcItem.Id), operationField);
      // could be negative, could be positive ... could be 0!
      return newVal - oldVal;
    }

    public override void performRollup(Op operation, Object priorVal, SObject calcItem, Map<Id, SObject> oldCalcItems, SObjectField operationField) {
      Decimal returnVal = (Decimal) this.returnVal;
      switch on operation {
        when SUM, COUNT {
          returnVal += this.getNumericValue(calcItem, operationField);
        }
        when DELETE_SUM, DELETE_COUNT {
          returnVal -= this.getNumericValue(calcItem, operationField);
        }
        when UPDATE_SUM, UPDATE_COUNT {
          returnVal += this.getNumericChangedValue(calcItem, operationField, oldCalcItems);
        }
      }
    }
  }

  private class CountDistinctRollup extends Rollup {
    public CountDistinctRollup(Object returnValue) {
      super(returnValue);
    }

    public override void performRollup(Op operation, Object priorVal, SObject calcItem, Map<Id, SObject> oldCalcItems, SObjectField operationField) {
      Integer returnInt = (Integer) this.returnVal;
      switch on operation {
        WHEN COUNT_DISTINCT {
          returnInt++;
        }
        when DELETE_COUNT_DISTINCT {
          returnInt--;
        }
      }
    }
  }

  private class CountRollup extends DecimalRollup {
    public CountRollup(Object priorVal) {
      super(priorVal);
    }

    public override Object getReturnValue() {
      return (Integer) this.returnVal;
    }

    protected override Decimal getNumericValue(SObject calcItem, SObjectField operationField) {
      Decimal potentialReturnValue = super.getNumericValue(calcItem, operationField);
      return this.getCountValue(potentialReturnValue);
    }

    protected override Decimal getNumericChangedValue(SObject calcItem, SObjectField operationField, Map<Id, SObject> oldCalcItems) {
      Decimal potentialReturnValue = super.getNumericChangedValue(calcItem, operationField, oldCalcItems);
      return this.getCountValue(potentialReturnValue);
    }

    private Decimal getCountValue(Decimal potentialReturnValue) {
      return potentialReturnValue > 0 ? 1 : potentialReturnValue;
    }
  }
}