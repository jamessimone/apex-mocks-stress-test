@isTest
private class ApexMocksTests {
    private static Integer LARGE_NUMBER = 10000;

    @isTest
    static void fflib_should_mock_dml_statements_update() {
        // Given
        fflib_ApexMocks mocks = new fflib_ApexMocks();
        ICrud mockCrud = (ICrud)mocks.mock(Crud.class);
        Account fakeAccount = new Account();

        // When
        for(Integer i = 0; i < LARGE_NUMBER; i++) {
            mockCrud.doUpdate(fakeAccount);
        }

        // Then
        mocks.verify(mockCrud, LARGE_NUMBER);
    }

    @isTest
    static void crudmock_should_mock_dml_statements_update() {
        //Given
        ICrud mockCrud = CrudMock.getMock();
        Account fakeAccount = new Account();

        //When
        for(Integer i = 0; i < LARGE_NUMBER; i++) {
            mockCrud.doUpdate(fakeAccount);
        }

        //Then
        System.assertEquals(LARGE_NUMBER, CrudMock.Updated.size());
    }

    @isTest
    static void fflib_should_mock_multiple_crud_instances() {
        //Given
        fflib_ApexMocks mocks = new fflib_ApexMocks();
        ICrud mockCrudOne = (ICrud)mocks.mock(Crud.class);
        ICrud mockCrudTwo = (ICrud)mocks.mock(Crud.class);

        //When
        for(Integer i = 0; i < LARGE_NUMBER; i++) {
            Contact fakeCon = new Contact(LastName = '' + LARGE_NUMBER);
            mockCrudOne.doInsert(fakeCon);
            mockCrudTwo.doUpdate(fakeCon);
        }

        //Then
        mocks.verify(mockCrudOne, LARGE_NUMBER);
        mocks.verify(mockCrudTwo, LARGE_NUMBER);
    }

    @isTest
    static void crudmock_should_mock_multiple_crud_instances() {
        //Given
        ICrud mockCrudOne = new CrudMock();
        ICrud mockCrudTwo = new CrudMock();

        //When
        for(Integer i = 0; i < LARGE_NUMBER; i++) {
            Contact fakeCon = new Contact(LastName = '' + LARGE_NUMBER);
            mockCrudOne.doInsert(fakeCon);
            mockCrudTwo.doUpdate(fakeCon);
        }

        //Then
        System.assertEquals(LARGE_NUMBER, CrudMock.Inserted.size());
        System.assertEquals(LARGE_NUMBER, CrudMock.Updated.size());
    }
}