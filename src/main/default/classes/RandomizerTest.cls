@isTest
private class RandomizerTest {
    @isTest
    static void shouldRandomizeElements() {
        // we'll do two things - affirm the output is sufficiently different from the starting elements
        // of the original list, and verify that two output lists don't equal each other
        List<Integer> startingList = new List<Integer>{ 1, 2, 3, 4, 5, 6, 7, 8, 9, 10 };

        Randomizer randomizer = new Randomizer();
        List<Object> twoRandomDigits = randomizer.getRandomSelection(startingList, 2);

        Type returnedListType = getType(twoRandomDigits);
        System.assertEquals(List<Integer>.class, returnedListType, 'Returned list was not strongly typed: ' + returnedListType);
        System.assertEquals(2, twoRandomDigits.size(), 'Only two elements should have been returned');
        System.assertNotEquals(startingList.get(0), twoRandomDigits.get(0), 'Random list shouldn\'t begin with same element');
        System.assertNotEquals(startingList.get(1), twoRandomDigits.get(1), 'Random list shouldn\'t use same second element');

        List<Object> secondRoundOfDigits = randomizer.getRandomSelection(startingList, 2);
        System.assertEquals(2, secondRoundOfDigits.size(), 'Only 2 elements should be returned!');
        System.assertNotEquals(twoRandomDigits, secondRoundOfDigits, 'Two random lists should rarely equal each other');
    }

    private static Type getType(Object param) {
        try {
            if(param instanceof Datetime) {
                return Type.forName('Datetime');
            } else {
                Object o = (Datetime)param;
            }
        } catch(Exception ex) {
            String message = ex.getMessage().substringAfter('Invalid conversion from runtime type ');
			return Type.forName(message.substringBefore(' to '));
        }

        return null;
    }
}