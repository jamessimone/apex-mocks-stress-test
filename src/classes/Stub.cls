/**
 * MIT License
 * 
 * Copyright (c) 2019 Restless Labs, LLC
 * 
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 * 
 * The above copyright notice and this permission notice shall be included in all
 * copies or substantial portions of the Software.
 * 
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
 * SOFTWARE.
 */

/**
 * A configurable class/sObject instance stub that utilizes the Salesforce Stub API to return values from a method or
 * throw a specific exception.
 *
 * Because the Stub API requires one method to handle all invocations and the Reflection API does not provide a means of
 * invoking methods by name, it is not possible to stub out individual methods.
 *
 * A stub will throw a NoReturnValueException from all non-void methods not configured explicitly to avoid unexpected
 * NullPointerExceptions.
 */
@IsTest
public class Stub implements StubProvider {

	// Default mock exception
	public static final MockException MOCK_EXCEPTION = new MockException('Mock Exception');


	public Type type { get; private set; }
	public Object instance { get; private set; }
	public Set<String> invokedMethods { private get; private set; }
	public Map<String, Exception> exceptions { private get; private set; }
	public Map<String, Object> returnValues { private get; private set; }

	/**
	 * Constructor.
	 * @param typeToMock The class/SObject type that will be mocked by this stub
	 */
	public Stub(Type typeToMock) {
		this.type = typeToMock;
		this.instance = Test.createStub(typeToMock, this);
		this.invokedMethods = new Set<String>();
		this.exceptions = new Map<String, Exception>();
		this.returnValues = new Map<String, Object>();
	}


	//==================================================================================================================
	// Stub Provider
	//==================================================================================================================

	/**
	 * Handles a stubbed method call, per the StubProvider interface, by throwing an exception or returning a value, depending
	 * on what was configured for the method. If both a return value and exception have been set, the exception takes precedence.
	 * @param stubbedObject The stubbed object on which a method was invoked
	 * @param stubbedMethodName The name of the method that was invoked
	 * @param returnType The return type of the method that was invoked
	 * @param listOfParamTypes An ordered list of parameter types on the method that was invoked
	 * @param listOfParamNames An ordered list of parameter names on the method that was invoked
	 * @param listOfArgs An ordered list of arguments passed to the method
	 */
	public Object handleMethodCall(Object stubbedObject, String stubbedMethodName, Type returnType, List<Type> listOfParamTypes, List<String> listOfParamNames, List<Object> listOfArgs) {
		this.invokedMethods.add(stubbedMethodName);

		// If an exception has been configured for the invoked method, throw it
		// otherwise, if a return value has been configured for the method, return it
		if (exceptions.containsKey(stubbedMethodName)) {
			throw exceptions.get(stubbedMethodName);
		} else if (returnValues.containsKey(stubbedMethodName)) {
			return returnValues.get(stubbedMethodName);
		}

		// No result has been configured for the invoked method
		// if return type is null (void), return null
		if (String.valueOf(returnType) == 'void') {
			return null;
		}

		// Non-void method without configured response, throw an exception
		throw new NoReturnValueException(String.format(
			'No return value or exception has been configured for method \'\'{0}\'\' on stubbed class \'\'{1}\'\'',
			new String[] { stubbedMethodName, String.valueOf(type) }
		));
	}


	//==================================================================================================================
	// Configuration
	//==================================================================================================================

	/**
	 * Sets the value to be returned from a specific stubbed method.
	 * @param methodName The name of a method
	 * @param returnValue The value to return from the specified method when invoked
	 */
	public void setReturnValue(String methodName, Object returnValue) {
		returnValues.put(methodName, returnValue);
	}

	/**
	 * Configures a specified method to throw the default mock exception.
	 * @param methodName The name of a method
	 */
	public void setException(String methodName) {
		setException(methodName, MOCK_EXCEPTION);
	}

	/**
	 * Sets the exception to be thrown from a specific stubbed method.
	 * @param methodName The name of a method
	 * @param exceptionToThrow The exception to be thrown from the specified method when invoked
	 */
	public void setException(String methodName, Exception exceptionToThrow) {
		exceptions.put(methodName, exceptionToThrow);
	}


	//==================================================================================================================
	// Assertions
	//==================================================================================================================

	/**
	 * Asserts that a method with the given name has been invoked.
	 * @param methodName The name of the method in question
	 */
	public void assertInvoked(String methodName) {
		if (!invokedMethods.contains(methodName)) {
			throw new MethodNotInvokedException(String.format(
				'Method {0}.{1}() not invoked',
				new String[] { type.getName(), methodName }
			));
		}
	}

	/**
	 * Asserts that a method with the given name has not been invoked.
	 * @param methodName The name of the method in question
	 */
	public void assertNotInvoked(String methodName) {
		if (invokedMethods.contains(methodName)) {
			throw new MethodInvokedException(String.format(
				'Method {0}.{1}() invoked',
				new String[] { type.getName(), methodName }
			));
		}
	}


	//==================================================================================================================
	// Exceptions
	//==================================================================================================================

	// Default mock exception type
	public class MockException extends Exception {}

	// Exception thrown when a method without a configured mock return is invoked on a stubbed instance
	public class NoReturnValueException extends Exception {}

	// Exception thrown when a stub's invocation assertion fails
	public class MethodInvokedException extends Exception {}

	// Exception thrown when a callout is intercepted that has not been properly mocked
	public class MethodNotInvokedException extends Exception {}
}
