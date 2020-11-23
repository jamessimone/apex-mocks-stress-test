public without sharing class Randomizer {

    public static Integer getNumberFromRange(Integer minValue, Integer maxValue) {
        return minValue + (Math.random() * (maxValue - minValue + 1)).intValue();
    }

    public Object[] getRandomSelection(Object[] objectList, Integer selectionNumber) {
        // hello shopkeeper, I'd like ALL your safety checks
        Boolean hasInvalidArguments = objectList == null || objectList.isEmpty() || selectionNumber > objectList.size();
        if(hasInvalidArguments) {
            throw new IllegalArgumentException(
            'Invalid arguments: ' +
            '\nObject list: ' + objectList +
            '\nSelection number: ' + selectionNumber
            );
        }
        // use clone to retain List type information
        Object[] returnList = objectList.clone();
        returnList.clear();

        Integer index = objectList.size() - 1;
        while(index > 0 && returnList.size() < selectionNumber) {
            Integer randomNumber = getNumberFromRange(0, index);
            returnList.add(objectList.get(randomNumber));
            index--;
        }
        return returnList;
    }
}