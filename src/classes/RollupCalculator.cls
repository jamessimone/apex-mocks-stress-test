public without sharing class RollupCalculator implements System.Queueable, System.Schedulable {
  @testVisible
  private static Boolean shouldRunFromTrigger = Trigger.isExecuting;
  @testVisible
  private static TriggerOperation triggerContext = Trigger.operationType;
  @testVisible
  private static List<SObject> triggerRecords;
  @testVisible
  private static Map<Id, SObject> oldRecordsMap;

  // TODO: perform caching on these; no need to duplicate the references for every rollup calculator if they're all using the same underyling dataset
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
      if (opNameToOp == null) {
        opNameToOp = new Map<String, Op>();
        for (Op operation : Op.values()) {
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

  public void execute(System.SchedulableContext sc) {
    // TODO: Scheduled invocations
  }

  /**
   * public facing Rollup calculation section
   * - Trigger operations
   * - Batch
   * - Invocable
   */

  public class FlowInput {
    @InvocableVariable(label='Records to rollup' description='Records to rollup to parent/related item(s)' required=true)
    public List<SObject> recordsToRollup;

    @InvocableVariable(label='Rollup target\'s SObject Name' description='The API Name of the SObject where the rollup value will be stored.' required=true)
    public String rollupSObjectName;

    @InvocableVariable(label='Rollup Operation' description='SUM, COUNT, COUNT_DISTINCT, MAX, MIN' required=true)
    public String rollupOperation;

    @InvocableVariable(label='Rollup Context' description='INSERT, UPDATE, or DELETE' required=true)
    public String rollupContext;

    @InvocableVariable(
      label='Calc Item Rollup Field'
      description='The API Name of the field on each of the records passed in to consider. Not used for COUNT_DISTINCT operations'
    )
    public String rollupFieldOnCalcItem;

    @InvocableVariable(
      label='Rollup Object Field'
      description='The API Name of the field on the target object where the rollup value will be stored'
      required=true
    )
    public String rollupFieldOnOpObject;

    @InvocableVariable(
      label='Lookup Field On Calc Item'
      description='The API Name of the field on the record to rollup that matches a field on the object where the rollup will be stored'
      required=true
    )
    public string lookupFieldOnCalcItem;
  }

  public class FlowOutput {
    public FlowOutput(FlowInput flowInput) {
      this.isSuccess = true;
      this.Message = 'SUCCESS';
      this.rollupRecords = flowInput.recordsToRollup;
    }

    @InvocableVariable(label='Is Success' description='Was rollup enqueued successfully?')
    public Boolean isSuccess;
    @InvocableVariable(label='Status Message' description='"SUCCESS" when isSuccess is true, otherwise the encountered error message')
    public String message;
    @InvocableVariable(label='Records to rollup' description='The corresponding records to rollup from the FlowInput')
    public List<SObject> rollupRecords;
  }

  @InvocableMethod(
    category='Rollups'
    label='Perform rollup on records'
    description='Returns a single FlowOutput record with "SUCCESS" as the message if async rollup operation is enqueued successfully, and the encountered error otherwise'
  )
  public static List<FlowOutput> performRollup(List<FlowInput> flowInputs) {
    List<FlowOutput> flowOutputReturns = new List<FlowOutput>();
    List<Rollup__mdt> rollups = new List<Rollup__mdt>();
    //TODO: guard clause for non-flow operations?

    try {
      Map<Id, SObject> oldRecords = new Map<Id, SObject>();
      List<SObject> calcItems = new List<SObject>();
      FlowInput firstInput = flowInputs.isEmpty() == false ? flowInputs[0] : new FlowInput();
      String targetRollupSObjectName = String.isBlank(firstInput.rollupSObjectName) ? '' : firstInput.rollupSObjectName;
      SObjectType sObjectType = getSObjectTypeFromName(targetRollupSObjectName);
      String rollupContext = getFlowRollupContext(firstInput);
      Boolean isFirstSObject = true;
      Set<String> fieldNames;

      for (FlowInput flowInput : flowInputs) {
        FlowOutput flowOutput = new FlowOutput(flowInput);
        flowOutputReturns.add(flowOutput);

        if (sObjectType == null || String.isBlank((rollupContext))) {
          throw new IllegalArgumentException('SObject type: ' + sObjectType + ', or rollup operation: ' + rollupContext + ' were empty, exiting');
        }

        for (SObject record : flowInput.recordsToRollup) {
          if (isFirstSObject) {
            isFirstSObject = false;
            fieldNames = record.getPopulatedFieldsAsMap().keySet();
          }
          calcItems.add(record);
          oldRecords.put(record.Id, record);
        }

        // TODO: you can reference CMDT in flows, but can you pass those records to Apex?
        // Either way, may want to keep this version, since it gives the Flow creator more flexibility
        Rollup__mdt rollupMetadata = new Rollup__mdt();
        rollupMetadata.RollupFieldOnCalcItem__c = flowInput.rollupFieldOnCalcItem;
        rollupMetadata.LookupObject__c = flowInput.rollupSObjectName;
        rollupMetadata.LookupFieldOnCalcItem__c = flowInput.lookupFieldOnCalcItem;
        rollupMetadata.RollupFieldOnLookupObject__c = flowInput.rollupFieldOnOpObject;
        rollupMetadata.RollupType__c = flowInput.rollupOperation;
        rollups.add(rollupMetadata);
      }
      oldRecords = getOldFlowRecords(oldRecords.keySet(), fieldNames, sObjectType);
      runOn(rollups, sObjectType, rollupContext, calcItems, oldRecords);
    } catch (Exception ex) {
      for (FlowOutput flowOutput : flowOutputReturns) {
        flowOutput.IsSuccess = false;
        flowOutput.Message = ex.getMessage() + '\n' + ex.getStackTraceString();
      }
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

  //TODO: expose other rollup methods
  public static RollupCalculator sumFromTrigger(
    SObjectField sumFieldOnCalcItem,
    SObjectField lookupFieldOnCalcItem,
    SObjectField lookupFieldOnOpObject,
    SObjectField sumFieldOnOpOject,
    SObjectType lookupSobjectType
  ) {
    return sumFromTrigger(sumFieldOnCalcItem, lookupFieldOnCalcItem, lookupFieldOnOpObject, sumFieldOnOpOject, lookupSobjectType, null);
  }

  public static RollupCalculator sumFromTrigger(
    SObjectField sumFieldOnCalcItem,
    SObjectField lookupFieldOnCalcItem,
    SObjectField lookupFieldOnOpObject,
    SObjectField sumFieldOnOpOject,
    SObjectType lookupSObjectType,
    Evaluator eval
  ) {
    Rollup__mdt rollupMetadata = new Rollup__mdt(
      RollupFieldOnCalcItem__c = sumFieldOnCalcItem.getDescribe().getName(),
      LookupObject__c = String.valueOf(lookupSObjectType),
      LookupFieldOnCalcItem__c = lookupFieldOnCalcItem.getDescribe().getName(),
      RollupFieldOnLookupObject__c = sumFieldOnOpOject.getDescribe().getName(),
      RollupType__c = Op.SUM.name()
    );
    //TODO: fixme
    return null;
    // return runOn(new List<Rollup__mdt>{ rollupMetadata }, sObjectType, rollupContext, calcItems, oldCalcItems)
    // (sumFieldOnCalcItem, lookupFieldOnCalcItem, lookupFieldOnOpObject, sumFieldOnOpOject, Op.SUM.name(), eval, null);
  }

  public static void runFromTrigger() {
    if (shouldRunFromTrigger() == false) {
      return;
    }

    List<SObject> calcItems = getTriggerRecords();
    SObjectType sObjectType = calcItems.getSObjectType();
    List<Rollup__mdt> rollupOperations = [
      SELECT CalcItem__c, RollupFieldOnCalcItem__c, LookupObject__c, LookupFieldOnCalcItem__c, RollupFieldOnLookupObject__c, RollupType__c
      FROM Rollup__mdt
      WHERE CalcItem__c = :String.valueOf(sObjectType)
    ];

    String rollupContext;
    Boolean shouldReturn = false;
    Map<Id, SObject> oldCalcItems;

    switch on triggerContext {
      when AFTER_UPDATE {
        rollupContext = 'UPDATE_';
        oldCalcItems = getOldTriggerRecordsMap();
      }
      when BEFORE_DELETE {
        rollupContext = 'DELETE_';
      }
      when AFTER_INSERT {
        // for AFTER_INSERT, the base operation name will always be used
        rollupContext = '';
      }
      when else {
        shouldReturn = true;
      }
    }
    if (shouldReturn) {
      return;
    }

    runOn(rollupOperations, sObjectType, rollupContext, calcItems, oldCalcItems);
  }
  // end public-facing section

  private static String getFlowRollupContext(FlowInput firstInput) {
    String flowContext = String.isBlank(firstInput.rollupContext) ? 'INSERT' : firstInput.rollupContext;
    return flowContext == 'INSERT' ? '' : flowContext;
  }

  private static Map<Id, SObject> getOldFlowRecords(Set<Id> currentRecords, Set<String> fieldNames, SObjectType sObjectType) {
    return oldRecordsMap != null
      ? oldRecordsMap
      : new Map<Id, SObject>(
          Database.query('SELECT ' + String.join(new List<String>(fieldNames), ',') + 'FROM ' + String.valueOf(sObjectType) + 'WHERE Id = :currentRecords')
        );
  }

  private static void runOn(
    List<Rollup__mdt> rollupOperations,
    SObjectType sObjectType,
    String rollupContext,
    List<SObject> calcItems,
    Map<Id, SObject> oldCalcItems
  ) {
    if (rollupOperations.isEmpty()) {
      return;
    }

    /**
     * We have rollup operations to perform. That's great! BUT Field Definition CMDT records are stored like such: `Account.NumberOfEmployees`
     * Frustratingly, the generic "put" operation for SObjects (necessary later) doesn't support these "full length" field names
     * (nor can you retrieve them from the "fieldNameToField" map below). Let's pare them down and get ready to rollup!
     */
    RollupCalculator batchCalc = new RollupCalculator();
    DescribeSObjectResult describeForSObject = sObjectType.getDescribe();
    Map<String, SObjectField> fieldNameToField = describeForSObject.fields.getMap();
    for (Rollup__mdt rollupMetadata : rollupOperations) {
      Op rollupOp = opNameToOp.get(rollupContext + rollupMetadata.RollupType__c);
      SObjectField rollupFieldOnCalcItem = fieldNameToField.get(getParedFieldName(rollupMetadata.RollupFieldOnCalcItem__c, describeForSObject));
      SObjectField lookupFieldOnCalcItem = fieldNameToField.get(getParedFieldName(rollupMetadata.LookupFieldOnCalcItem__c, describeForSObject));

      // NB - this SHOULD work even for SObjects part of managed packages
      DescribeSObjectResult lookupObjectDescribe = getSObjectTypeFromName(rollupMetadata.LookupObject__c).getDescribe();
      Map<String, SObjectField> lookupFieldNameToLookupFields = lookupObjectDescribe.fields.getMap();
      SObjectField lookupFieldOnOpObject = lookupFieldNameToLookupFields.get(
        getParedFieldName(rollupMetadata.LookupFieldOnLookupObject__c, lookupObjectDescribe)
      );
      SObjectField rollupFieldOnOpObject = lookupFieldNameToLookupFields.get(
        getParedFieldName(rollupMetadata.RollupFieldOnLookupObject__c, lookupObjectDescribe)
      );

      loadCalculators(
        lookupFieldOnCalcItem,
        lookupFieldOnCalcItem,
        lookupFieldOnOpObject,
        rollupFieldOnOpObject,
        sObjectType,
        rollupOp,
        batchCalc,
        calcItems,
        oldCalcItems,
        null // eval
      );
    }
    batchCalc.runCalc();
  }

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
    return oldRecordsMap != null ? oldRecordsMap : Trigger.oldMap;
  }

  private static SObjectType getSObjectTypeFromName(String sobjectName) {
    return ((SObject) Type.forName(sobjectName).newInstance()).getSObjectType();
  }

  private static String getParedFieldName(String fullFieldName, DescribeSObjectResult describeForSObject) {
    return fullFieldName.replace(describeForSObject.getName() + '.', '');
  }

  private static RollupCalculator loadCalculators(
    SObjectField rollupFieldOnCalcItem,
    SObjectField lookupFieldOnCalcItem,
    SObjectField lookupFieldOnOpObject,
    SObjectField rollupFieldOnOpObject,
    SObjectType sObjectType,
    Op rollupOp,
    RollupCalculator batchCalc,
    List<SObject> calcItems,
    Map<Id, SObject> oldCalcItems,
    Evaluator eval
  ) {
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
    if (operationType.name().contains(RollupCalculator.Op.COUNT_DISTINCT.name())) {
      return new CountDistinctRollup(0);
    } else if (operationType.name().contains(RollupCalculator.Op.COUNT.name())) {
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
        when COUNT_DISTINCT {
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
