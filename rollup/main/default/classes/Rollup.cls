public without sharing virtual class Rollup implements Database.Batchable<SObject> {
  @testVisible
  private static Boolean shouldRun = Trigger.isExecuting || System.Request.getCurrent().getQuiddity() == Quiddity.INVOCABLE_ACTION;
  @testVisible
  private static TriggerOperation triggerContext = Trigger.operationType;
  @testVisible
  private static List<SObject> triggerRecords;
  @testVisible
  private static Map<Id, SObject> oldRecordsMap;
  @testVisible
  private static List<Rollup__mdt> rollupMetadata;

  private static final Datetime now = System.now();

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

  @testVisible
  private static DMLHelper DML {
    get {
      if (DML == null) {
        DML = new DMLHelper();
      }
      return DML;
    }
    set;
  }

  private List<Rollup> calculators {
    get {
      if (calculators == null) {
        calculators = new List<Rollup>();
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

  // TODO: average functions differently because it has to consider the whole dataset
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

  private Rollup() {
    this.isBatched = true;
    // a batch only becomes valid if other Calculators are added to it
    this.isNoOp = true;
  }

  private Rollup(
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
    this.isNoOp = this.calcItems.isEmpty();
    this.isBatched = false;
  }

  public interface Evaluator {
    Boolean matches(Object calcItem);
  }

  public class SObjectChangedFieldEvaluator implements Evaluator {
    private final List<String> changedFieldNames;
    private final Map<Id, SObject> oldRecordsMap;
    public SObjectChangedFieldEvaluator(List<String> changedFieldNames, Map<Id, SObject> oldRecordsMap) {
      this.changedFieldNames = changedFieldNames;
      this.oldRecordsMap = oldRecordsMap;
    }

    public Boolean matches(Object calcItem) {
      SObject calcSObject = (SObject) calcItem;
      SObject oldRecord = oldRecordsMap.get(calcSObject.Id);
      Boolean matches = this.changedFieldNames.isEmpty() || this.oldRecordsMap == null;
      for (String fieldName : this.changedFieldNames) {
        if (calcSObject.get(fieldName) != oldRecord.get(fieldName)) {
          matches = true;
          break;
        }
      }
      return matches;
    }
  }

  public void runCalc() {
    if (this.isNoOp == false) {
      System.enqueueJob(this);
    }
  }

  public Database.QueryLocator start(Database.BatchableContext context) {
    //TODO: infinite scaling
    return null;
  }

  public void execute(Database.BatchableContext context, List<SObject> scope) {
  }

  public void finish(Database.BatchableContext context) {
  }

  private class RollupAsyncProcessor extends Rollup implements System.Queueable {
    public RollupAsyncProcessor(
      List<SObject> calcItems,
      SObjectField opFieldOnCalcItem,
      SObjectField lookupFieldOnCalcItem,
      SObjectField lookupFieldOnLookupObject,
      SObjectField opFieldOnLookupObject,
      SObjectType lookupObj,
      Op operation,
      Map<Id, SObject> oldCalcItems,
      Evaluator eval
    ) {
      super(calcItems, opFieldOnCalcItem, lookupFieldOnCalcItem, lookupFieldOnLookupObject, opFieldOnLookupObject, lookupObj, operation, oldCalcItems, eval);
    }

    public RollupAsyncProcessor() {
      super();
    }

    public void execute(System.QueueableContext qc) {
      Map<String, SObject> updatedLookupRecords = new Map<String, SObject>();

      Map<SObjectType, Set<String>> lookupObjectToUniqueFieldNames = new Map<SObjectType, Set<String>>();
      for (Rollup calc : this.calculators) {
        String fieldName = calc.opFieldOnLookupObject.getDescribe().getName();
        if (lookupObjectToUniqueFieldNames.containsKey(calc.lookupObj)) {
          lookupObjectToUniqueFieldNames.get(calc.lookupObj).add(fieldName);
        } else {
          Set<String> fieldNames = new Set<String>();
          fieldNames.add(fieldName);
          lookupObjectToUniqueFieldNames.put(calc.lookupObj, fieldNames);
        }
      }

      for (Rollup calc : this.calculators) {
        Map<String, List<SObject>> calcItemsByLookupField = this.getCalcItemsByLookupField(calc);
        List<SObject> lookupItems = new List<SObject>();
        Set<String> lookupItemKeys = new Set<String>(calcItemsByLookupField.keySet());
        for (String key : calcItemsByLookupField.keySet()) {
          if (updatedLookupRecords.containsKey(key)) {
            lookupItemKeys.remove(key);
            // this way, the updated values are persisted for each field
            lookupItems.add(updatedLookupRecords.get(key));
          }
        }
        lookupItems.addAll(this.getLookupItems(lookupItemKeys, calc, lookupObjectToUniqueFieldNames.get(calc.lookupObj)));
        List<SObject> updatedRecords = this.getUpdatedLookupItemsByRollup(calc, calcItemsByLookupField, lookupItems);

        for (SObject updatedRecord : updatedRecords) {
          updatedLookupRecords.put(updatedRecord.Id, updatedRecord);
        }
      }

      DML.doUpdate(updatedLookupRecords.values());
    }
  }

  /**
   * public facing Rollup calculation section
   * - Trigger operations
   * - Batch (multiple Rollup operations chained into one job)
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

    @InvocableVariable(
      label='Lookup Field On Rollup Object'
      description='The API Name of the field on the SObject matching the value found in "lookupFieldOnCalcItem" where the rollup will be stored'
      required=true
    )
    public string lookupFieldOnOpObject;

    @InvocableVariable(
      label='Calc Item Changed Fields'
      description='Provide a comma-separated list of field API Names to consider prior to using records in the rollup'
    )
    public String calcItemChangedFields;
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
    if (shouldRun == false) {
      return flowOutputReturns;
    }

    try {
      Map<Id, SObject> oldRecords = new Map<Id, SObject>();
      List<SObject> calcItems = new List<SObject>();
      FlowInput firstInput = flowInputs.isEmpty() == false ? flowInputs[0] : new FlowInput();
      String rollupContext = getFlowRollupContext(firstInput);
      Boolean isFirstSObject = true;
      SObjectType recordSObjectType;
      Set<String> fieldNames;

      for (FlowInput flowInput : flowInputs) {
        FlowOutput flowOutput = new FlowOutput(flowInput);
        flowOutputReturns.add(flowOutput);

        for (SObject record : flowInput.recordsToRollup) {
          if (isFirstSObject) {
            isFirstSObject = false;
            recordSObjectType = record.getSObjectType();
            fieldNames = record.getPopulatedFieldsAsMap().keySet();
          }
          calcItems.add(record);
          oldRecords.put(record.Id, record);
        }

        Rollup__mdt rollupMetadata = new Rollup__mdt(
          RollupFieldOnCalcItem__c = flowInput.rollupFieldOnCalcItem,
          LookupObject__c = flowInput.rollupSObjectName,
          LookupFieldOnCalcItem__c = flowInput.lookupFieldOnCalcItem,
          LookupFieldOnLookupObject__c = flowInput.lookupFieldOnOpObject,
          RollupFieldOnLookupObject__c = flowInput.rollupFieldOnOpObject,
          RollupType__c = flowInput.rollupOperation,
          ChangedFieldsOnCalcItem__c = flowInput.calcItemChangedFields
        );
        rollups.add(rollupMetadata);
      }
      oldRecords = getOldFlowRecords(oldRecords.keySet(), fieldNames, recordSObjectType);
      getCalculator(rollups, recordSObjectType, rollupContext, calcItems, oldRecords, null).runCalc();
    } catch (Exception ex) {
      for (FlowOutput flowOutput : flowOutputReturns) {
        flowOutput.IsSuccess = false;
        flowOutput.Message = ex.getMessage() + '\n' + ex.getStackTraceString();
      }
    }

    return flowOutputReturns;
  }

  /**
   * Static public methods and helper methods
   */

  public static void batch(Rollup calc, Rollup secondCalc) {
    batch(new List<Rollup>{ calc, secondCalc });
  }

  public static void batch(Rollup calc, Rollup secondCalc, Rollup thirdCalc) {
    batch(new List<Rollup>{ calc, secondCalc, thirdCalc });
  }

  public static void batch(List<Rollup> calcs) {
    Rollup batchCalculator = new RollupAsyncProcessor();
    for (Rollup calc : calcs) {
      loadCalculators(calc, batchCalculator);
    }
    batchCalculator.runCalc();
  }

  public static Rollup countDistinctFromTrigger(
    SObjectField lookupFieldOnCalcItem,
    SObjectField lookupFieldOnOperationObject,
    SObjectField countDistinctFieldOnOperationObject,
    SObjectType lookupSobjectType
  ) {
    return countDistinctFromTrigger(lookupFieldOnCalcItem, lookupFieldOnOperationObject, countDistinctFieldOnOperationObject, lookupSobjectType, null);
  }

  public static Rollup countDistinctFromTrigger(
    SObjectField lookupFieldOnCalcItem,
    SObjectField lookupFieldOnOperationObject,
    SObjectField countDistinctFieldOnOperationObject,
    SObjectType lookupSobjectType,
    Evaluator eval
  ) {
    return operateFromTrigger(
      null,
      lookupFieldOnCalcItem,
      lookupFieldOnOperationObject,
      countDistinctFieldOnOperationObject,
      lookupSobjectType,
      Op.COUNT_DISTINCT,
      eval
    );
  }

  public static Rollup countFromTrigger(
    SObjectField countFieldOnCalcItem,
    SObjectField lookupFieldOnCalcItem,
    SObjectField lookupFieldOnOperationObject,
    SObjectField countFieldOnOperationObject,
    SObjectType lookupSobjectType
  ) {
    return countFromTrigger(countFieldOnCalcItem, lookupFieldOnCalcItem, lookupFieldOnOperationObject, countFieldOnOperationObject, lookupSobjectType, null);
  }

  public static Rollup countFromTrigger(
    SObjectField countFieldOnCalcItem,
    SObjectField lookupFieldOnCalcItem,
    SObjectField lookupFieldOnOperationObject,
    SObjectField sumFieldOnOpOject,
    SObjectType lookupSobjectType,
    Evaluator eval
  ) {
    return operateFromTrigger(countFieldOnCalcItem, lookupFieldOnCalcItem, lookupFieldOnOperationObject, sumFieldOnOpOject, lookupSobjectType, Op.COUNT, eval);
  }

  public static Rollup sumFromTrigger(
    SObjectField sumFieldOnCalcItem,
    SObjectField lookupFieldOnCalcItem,
    SObjectField lookupFieldOnOperationObject,
    SObjectField sumFieldOnOpOject,
    SObjectType lookupSobjectType,
    Evaluator eval
  ) {
    return operateFromTrigger(sumFieldOnCalcItem, lookupFieldOnCalcItem, lookupFieldOnOperationObject, sumFieldOnOpOject, lookupSobjectType, Op.SUM, eval);
  }

  public static Rollup sumFromTrigger(
    SObjectField sumFieldOnCalcItem,
    SObjectField lookupFieldOnCalcItem,
    SObjectField lookupFieldOnOperationObject,
    SObjectField sumFieldOnOpOject,
    SObjectType lookupSobjectType
  ) {
    return sumFromTrigger(sumFieldOnCalcItem, lookupFieldOnCalcItem, lookupFieldOnOperationObject, sumFieldOnOpOject, lookupSobjectType, null);
  }

  private static Rollup operateFromTrigger(
    SObjectField operationFieldOnCalcItem,
    SObjectField lookupFieldOnCalcItem,
    SObjectField lookupFieldOnOperationObject,
    SObjectField operationFieldOnOperationObject,
    SObjectType lookupSObjectType,
    Op rollupOperation,
    Evaluator eval
  ) {
    Rollup__mdt rollupMetadata = new Rollup__mdt(
      // operationFieldOnCalcItem can be nullable because COUNT_DISTINCT doesn't require it
      RollupFieldOnCalcItem__c = operationFieldOnCalcItem != null ? operationFieldOnCalcItem.getDescribe().getName() : '',
      LookupObject__c = String.valueOf(lookupSObjectType),
      LookupFieldOnCalcItem__c = lookupFieldOnCalcItem.getDescribe().getName(),
      LookupFieldOnLookupObject__c = lookupFieldOnOperationObject.getDescribe().getName(),
      RollupFieldOnLookupObject__c = operationFieldOnOperationObject.getDescribe().getName(),
      RollupType__c = rollupOperation.name()
    );
    return runFromTrigger(new List<Rollup__mdt>{ rollupMetadata }, eval);
  }

  public static void runFromTrigger() {
    SObjectType sObjectType = getTriggerRecords().getSObjectType();
    List<Rollup__mdt> rollupMetadata = getTriggerRollupMetadata(sObjectType);
    runFromTrigger(rollupMetadata, null).runCalc();
  }

  private static Rollup runFromTrigger(List<Rollup__mdt> rollupMetadata, Evaluator eval) {
    if (shouldRunFromTrigger() == false) {
      return new RollupAsyncProcessor();
    }

    List<SObject> calcItems = getTriggerRecords();
    SObjectType sObjectType = calcItems.getSObjectType();

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
      return new RollupAsyncProcessor();
    }

    return getCalculator(rollupMetadata, sObjectType, rollupContext, calcItems, oldCalcItems, eval);
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
          Database.query('SELECT ' + String.join(new List<String>(fieldNames), ',') + '\nFROM ' + String.valueOf(sObjectType) + '\nWHERE Id = :currentRecords')
        );
  }

  private static List<Rollup__mdt> getTriggerRollupMetadata(SObjectType sObjectType) {
    // TODO: after Spring 21 is released, can just call Rollup__mdt.getAll();
    return rollupMetadata != null
      ? rollupMetadata
      : [
          SELECT
            CalcItem__c,
            RollupFieldOnCalcItem__c,
            LookupObject__c,
            LookupFieldOnCalcItem__c,
            RollupFieldOnLookupObject__c,
            RollupType__c,
            ChangedFieldsOnCalcItem__c
          FROM Rollup__mdt
          WHERE CalcItem__c = :String.valueOf(sObjectType)
        ];
  }

  private static Rollup getCalculator(
    List<Rollup__mdt> rollupOperations,
    SObjectType sObjectType,
    String rollupContext,
    List<SObject> calcItems,
    Map<Id, SObject> oldCalcItems,
    Evaluator eval
  ) {
    if (rollupOperations.isEmpty()) {
      return new RollupAsyncProcessor();
    }

    /**
     * We have rollup operations to perform. That's great! BUT Field Definition CMDT records are stored like such: `Account.NumberOfEmployees`
     * Frustratingly, the generic "put" operation for SObjects (necessary later) doesn't support these "full length" field names
     * (nor can you retrieve them from the "fieldNameToField" map below). Let's pare them down and get ready to rollup!
     */
    Rollup batchCalc = new RollupAsyncProcessor();
    DescribeSObjectResult describeForSObject = sObjectType.getDescribe();
    Map<String, SObjectField> fieldNameToField = describeForSObject.fields.getMap();
    for (Rollup__mdt rollupMetadata : rollupOperations) {
      Op rollupOp = opNameToOp.get(rollupContext + rollupMetadata.RollupType__c);
      SObjectField rollupFieldOnCalcItem = fieldNameToField.get(getParedFieldName(rollupMetadata.RollupFieldOnCalcItem__c, describeForSObject));
      SObjectField lookupFieldOnCalcItem = fieldNameToField.get(getParedFieldName(rollupMetadata.LookupFieldOnCalcItem__c, describeForSObject));

      // NB - this SHOULD work even for SObjects part of managed packages
      SObjectType lookupSObjectType = getSObjectTypeFromName(rollupMetadata.LookupObject__c);
      DescribeSObjectResult lookupObjectDescribe = lookupSObjectType.getDescribe();
      Map<String, SObjectField> lookupFieldNameToLookupFields = lookupObjectDescribe.fields.getMap();
      SObjectField lookupFieldOnOpObject = lookupFieldNameToLookupFields.get(
        getParedFieldName(rollupMetadata.LookupFieldOnLookupObject__c, lookupObjectDescribe)
      );
      SObjectField rollupFieldOnOpObject = lookupFieldNameToLookupFields.get(
        getParedFieldName(rollupMetadata.RollupFieldOnLookupObject__c, lookupObjectDescribe)
      );

      if (eval == null && String.isNotBlank(rollupMetadata.ChangedFieldsOnCalcItem__c)) {
        eval = new SObjectChangedFieldEvaluator(rollupMetadata.ChangedFieldsOnCalcItem__c.split(','), oldCalcItems);
      }

      loadCalculators(
        rollupFieldOnCalcItem,
        lookupFieldOnCalcItem,
        lookupFieldOnOpObject,
        rollupFieldOnOpObject,
        lookupSObjectType,
        rollupOp,
        calcItems,
        oldCalcItems,
        batchCalc,
        eval
      );
    }
    return batchCalc;
  }

  private static Boolean shouldRunFromTrigger() {
    // this can be overridden, but only in tests
    Boolean shouldRun = shouldRun;
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
    return String.isBlank(fullFieldName) ? '' : fullFieldName.replace(describeForSObject.getName() + '.', '');
  }

  private static Rollup loadCalculators(
    SObjectField rollupFieldOnCalcItem,
    SObjectField lookupFieldOnCalcItem,
    SObjectField lookupFieldOnOpObject,
    SObjectField rollupFieldOnOpObject,
    SObjectType sObjectType,
    Op rollupOp,
    List<SObject> calcItems,
    Map<Id, SObject> oldCalcItems,
    Rollup batchCalc,
    Evaluator eval
  ) {
    Rollup calc = new RollupAsyncProcessor(
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

  // TODO: when calculators are added to the list, we should also compare the hash for their records/oldRecordsMap
  private static Rollup loadCalculators(Rollup calc, Rollup batchCalc) {
    if (batchCalc != null && calc != null && calc.isNoOp == false) {
      batchCalc.calculators.add(calc);
      batchCalc.isNoOp = false;
    } else if (calc != null && calc.isNoOp == false) {
      calc.calculators.add(calc);
    }
    return batchCalc != null ? batchCalc : calc;
  }

  /** End static section, begin private instance methods */

  private List<SObject> filter(List<SObject> calcItems, Evaluator eval) {
    List<SObject> applicableItems = new List<SObject>();
    for (SObject calcItem : calcItems) {
      if (eval == null || eval.matches(calcItem)) {
        applicableItems.add(calcItem);
      }
    }
    return applicableItems;
  }

  private Map<String, List<SObject>> getCalcItemsByLookupField(Rollup calc) {
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

  private List<SObject> getLookupItems(Set<String> objIds, Rollup calc, Set<String> uniqueQueryFieldNames) {
    String queryString =
      'SELECT Id, ' +
      String.join(new List<String>(uniqueQueryFieldNames), ',') +
      '\nFROM ' +
      calc.lookupObj +
      '\nWHERE ' +
      calc.lookupFieldOnLookupObject +
      ' = :objIds';
    List<SObject> lookupItems = Database.query(queryString);
    // prior to returning, we need to ensure the default value for the rollup field is set
    for (SObject lookupItem : lookupItems) {
      if (lookupItem.get(calc.opFieldOnLookupObject) == null) {
        lookupItem.put(calc.opFieldOnLookupObject, this.getDefaultValue(calc.opFieldOnLookupObject));
      }
    }
    return lookupItems;
  }

  private Object getDefaultValue(SObjectField field) {
    // not surprisingly, "getDefaultValue" on the DescribeFieldResult returns null for fields without default values
    // this is a shame - all types *should* have default values. Instead, we have the privilege of having to initialize these ourselves
    Schema.DisplayType fieldType = field.getDescribe().getType();
    Object initializedDefault;
    switch on fieldType {
      when CURRENCY, DOUBLE, INTEGER, LONG, PERCENT {
        initializedDefault = 0;
      }
      when BOOLEAN {
        initializedDefault = false;
      }
      when DATETIME {
        initializedDefault = now;
      }
      when DATE {
        initializedDefault = now.dateGmt();
      }
      when TIME {
        initializedDefault = now.timeGmt();
      }
      when STRING, PICKLIST, ID, TEXTAREA, URL, PHONE, EMAIL, MULTIPICKLIST, ENCRYPTEDSTRING {
        initializedDefault = '';
      }
      when else {
        throw new IllegalArgumentException('Field specified invalid for rollup operation: ' + fieldType.name());
      }
    }
    return initializedDefault;
  }

  private List<SObject> getUpdatedLookupItemsByRollup(Rollup calc, Map<String, List<SObject>> calcItemsByLookupField, List<SObject> lookupItems) {
    List<SObject> recordsToUpdate = new List<SObject>();
    for (SObject lookupRecord : lookupItems) {
      String key = (String) lookupRecord.get(calc.lookupFieldOnLookupObject);
      if (calcItemsByLookupField.containsKey(key)) {
        List<SObject> calcItems = calcItemsByLookupField.get(key);
        Object priorVal = lookupRecord.get(calc.opFieldOnLookupObject);
        Object newVal = this.getRollupVal(calc, calcItems, priorVal);
        lookupRecord.put(calc.opFieldOnLookupObject, newVal);
        recordsToUpdate.add(lookupRecord);
      }
    }

    return recordsToUpdate;
  }

  private Object getRollupVal(Rollup rollup, List<SObject> calcItems, Object priorVal) {
    RollupCalculator rollupCalc = this.getRollupType(priorVal, rollup.op);
    for (SObject calcItem : calcItems) {
      rollupCalc.performRollup(rollup.op, priorVal, calcItem, rollup.oldCalcItems, rollup.opFieldOnCalcItem);
    }
    return rollupCalc.getReturnValue();
  }

  private RollupCalculator getRollupType(Object priorVal, Op operationType) {
    if (operationType.name().contains(Rollup.Op.COUNT_DISTINCT.name())) {
      return new CountDistinctRollupCalculator(0);
    } else if (operationType.name().contains(Rollup.Op.COUNT.name())) {
      return new CountRollupCalculator(priorVal);
    } else if (priorVal instanceof Decimal) {
      return new DecimalRollupCalculator(priorVal);
    } else {
      throw new IllegalArgumentException('Calculation not defined for: ' + JSON.serialize(priorVal));
    }
  }

  @testVisible
  private virtual class DMLHelper {
    public virtual void doUpdate(List<SObject> recordsToUpdate) {
      update recordsToUpdate;
    }
  }

  private abstract class RollupCalculator {
    protected Object returnVal;
    public RollupCalculator(Object returnVal) {
      this.returnVal = returnVal;
    }
    public virtual Object getReturnValue() {
      return returnVal;
    }
    public abstract void performRollup(Op op, Object priorVal, SObject calcItem, Map<Id, SObject> oldCalcItems, SObjectField operationField);
  }

  private virtual class DecimalRollupCalculator extends RollupCalculator {
    public DecimalRollupCalculator(Object priorVal) {
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
      this.returnVal = returnVal;
    }
  }

  private class CountDistinctRollupCalculator extends RollupCalculator {
    public CountDistinctRollupCalculator(Object returnValue) {
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
      this.returnVal = returnInt;
    }
  }

  private class CountRollupCalculator extends DecimalRollupCalculator {
    public CountRollupCalculator(Object priorVal) {
      super(priorVal);
    }

    public override Object getReturnValue() {
      return Integer.valueOf(this.returnVal);
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
