component name="BaseStripeTest" extends="mxunit.framework.TestCase" output="false" {

	public void function setUp() {
		if ( fileExists(getDirectoryFromPath(getCurrentTemplatePath()) & "credentials.cfm") ) {
			include "credentials.cfm";
		} else {
			variables.credentials = { "CAD": {"TestSecretKey": "sk_test_Zx4885WE43JGqPjqGzaWap8a", "TestPublishableKey": ""}
											,"USD": {"TestSecretKey": "tGN0bIwXnHdwOa85VABjPdSn8nWY7G7I", "TestPublishableKey": ""}
											};
		}

		// $CAD credentials (provided by support@stripe.com)
			local.gw = {"path": "stripe.stripe", "GatewayID": 2, "TestMode": true};
			local.gw.TestSecretKey = credentials.cad.TestSecretKey;
			local.gw.TestPublishableKey = credentials.cad.TestPublishableKey;

			variables.svc = createObject("component", "cfpayment.api.core").init(local.gw);
			variables.cad = variables.svc.getGateway();
			variables.cad.currency = "cad"; // ONLY FOR UNIT TEST
			variables.cad.country = "CA"; // ONLY FOR UNIT TEST


			// $USD credentials - from PHP unit tests on github
			local.gw = {"path": "stripe.stripe", "GatewayID": 2, "TestMode": true};
			local.gw.TestSecretKey = credentials.usd.TestSecretKey;
			local.gw.TestPublishableKey = credentials.usd.TestPublishableKey;

			variables.svc = createObject("component", "cfpayment.api.core").init(local.gw);
			variables.usd = variables.svc.getGateway();
			variables.usd.currency = "usd"; // ONLY FOR UNIT TEST
			variables.usd.country = "US"; // ONLY FOR UNIT TEST

			// create default
			variables.gw = variables.usd;
			
			// for dataprovider testing
			variables.gateways = [cad, usd];
		//  if set to false, will try to connect to remote service to check these all out 
		variables.localMode = true;
		variables.debugMode = true;
	}

	private function offlineInjector() {
		if ( variables.localMode ) {
			injectMethod(argumentCollection = arguments);
		}
		//  if not local mode, don't do any mock substitution so the service connects to the remote service! 
	}

	private function standardResponseTests(required any response, required any expectedObjectName, required any expectedIdPrefix) {
		if ( variables.debugMode ) {
			debug(arguments.expectedObjectName);
			debug(arguments.response.getParsedResult());
			debug(arguments.response.getResult());
		}
		if ( isSimpleValue(arguments.response) ) {
			assertTrue(false, "Response returned a simple value: '#arguments.response#'");
		}
		if ( !isObject(arguments.response) ) {
			assertTrue(false, "Invalid: response != an object");
		} else if ( isStruct(arguments.response.getParsedResult()) && structIsEmpty(arguments.response.getParsedResult()) ) {
			assertTrue(false, "Response structure returned == empty");
		} else if ( isSimpleValue(arguments.response.getParsedResult()) ) {
			assertTrue(false, "Response == a string, expected a structure. Returned string = '#arguments.response.getParsedResult()#'");
		} else if ( arguments.response.getStatusCode() != 200 ) {
			//  Test status code and remote error messages 
			if ( structKeyExists(arguments.response.getParsedResult(), "error") ) {
				assertTrue(false, "Error From Stripe: (Type=#arguments.response.getParsedResult().error.type#) #arguments.response.getParsedResult().error.message#");
			}
			assertTrue(false, "Status code should be 200, was: #arguments.response.getStatusCode()#");
		} else {
			//  Test returned data (for object and valid id) 
			assertTrue(arguments.response.getSuccess(), "Response !successful");
			if ( arguments.expectedObjectName != "" ) {
				assertTrue(structKeyExists(arguments.response.getParsedResult(), "object") && arguments.response.getParsedResult().object == arguments.expectedObjectName, "Invalid #expectedObjectName# object returned");
			}
			if ( arguments.expectedIdPrefix != "" ) {
				assertTrue(len(arguments.response.getParsedResult().id) > len(arguments.expectedIdPrefix) && left(arguments.response.getParsedResult().id, len(arguments.expectedIdPrefix)) == arguments.expectedIdPrefix, "Invalid account ID prefix returned, expected: '#arguments.expectedIdPrefix#...', received: '#response.getParsedResult().id#'");
			}
		}
	}

	private function standardErrorResponseTests(required any response, required any expectedErrorType, required any expectedStatusCode) {
		if ( variables.debugMode ) {
			debug(arguments.expectedErrorType);
			debug(arguments.expectedStatusCode);
			debug(arguments.response.getParsedResult());
			debug(arguments.response.getResult());
		}
		if ( isSimpleValue(arguments.response) ) {
			assertTrue(false, "Response returned a simple value: '#arguments.response#'");
		}
		if ( !isObject(arguments.response) ) {
			assertTrue(false, "Invalid: response != an object");
		} else if ( isStruct(arguments.response.getParsedResult()) && structIsEmpty(arguments.response.getParsedResult()) ) {
			assertTrue(false, "Response structure returned == empty");
		} else if ( isSimpleValue(arguments.response.getParsedResult()) ) {
			assertTrue(false, "Response == a string, expected a structure. Returned string = '#arguments.response.getParsedResult()#'");
		} else if ( arguments.response.getStatusCode() != arguments.expectedStatusCode ) {
			assertTrue(false, "Status code should be #arguments.expectedStatusCode#, was: #arguments.response.getStatusCode()#");
		} else {
			if ( structKeyExists(arguments.response.getParsedResult(), "error") ) {
				if ( structKeyExists(arguments.response.getParsedResult().error, "message") && structKeyExists(arguments.response.getParsedResult().error, "type") ) {
					assertTrue(arguments.response.getParsedResult().error.type == arguments.expectedErrorType, "Received error type (#arguments.response.getParsedResult().error.type#), expected error type (#arguments.expectedErrorType#) from API");
				} else {
					assertTrue(false, "Error message from API missing details");
				}
			} else {
				assertTrue(false, "Object returned did !have an error");
			}
		}
	}

}
