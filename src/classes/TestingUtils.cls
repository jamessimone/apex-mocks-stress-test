public class TestingUtils {
    private static Integer startingNumber = 1;

    public static String generateId(Schema.SObjectType sObjectType) {
        String result = String.valueOf(startingNumber++);
        return sObjectType.getDescribe().getKeyPrefix() + '0'.repeat(12-result.length()) + result;
   }

   public static SObject generateId(SObject objectInstance) {
        if(objectInstance.Id == null) {
            objectInstance.Id = generateId(objectInstance.getSObjectType());
        }
        return objectInstance;
   }

    public static void generateIds(List<SObject> records) {
        for(SObject record : records) {
            if(record.Id == null) {
                generateId(record);
            }
        }
    }

    public static void activateCustomPerm(Id userId, String permissionName) {
      PermissionSet ps = new PermissionSet(
        Name = 'CustomPermissionEnabled',
        Label = 'Custom Permisison Enabled'
        );
      insert ps;

      SetupEntityAccess sea = new SetupEntityAccess(
        ParentId = ps.Id,
        SetupEntityId = [
          SELECT Id
          FROM CustomPermission
          WHERE DeveloperName = :permissionName
          LIMIT 1
        ].Id
      );

      PermissionSetAssignment psa = new PermissionSetAssignment(
        AssigneeId = userId,
        PermissionSetId = ps.Id
      );

      insert new List<SObject>{ sea, psa };
    }
}