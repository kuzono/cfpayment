/* 
	$Id$

	Copyright 2007 Brian Ghidinelli (http://www.ghidinelli.com/)

	Licensed under the Apache License, Version 2.0 (the "License"); you
	may not use this file except in compliance with the License. You may
	obtain a copy of the License at:

		http://www.apache.org/licenses/LICENSE-2.0

	Unless required by applicable law or agreed to in writing, software
	distributed under the License is distributed on an "AS IS" BASIS,
	WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
	See the License for the specific language governing permissions and
	limitations under the License.
*/
/**
 * Base gateway to be extended by real implementations
 */
component name="base" output="false" hint="Base gateway to be extended by real implementations" {
	/* 
	Building a new gateway is straightforward.  Extend this base.cfc and then map your gateway-specific parameters to normalized cfpayment parameters.
	
	For example, we call our internal tracking ID "orderId".  However, Braintree expects "order_id" and Skipjack expects "ordernumber".
	
	To write a new gateway, you would pass in orderId to a method like purchase() and map it to whatever name your gateway requires.  When you parse the response from your gateway,
	you would map it back to orderId in the common response object.  Make sense?
	
	Check the docs for a complete list of normalized cfpayment parameter names.
	*/
	variables.cfpayment = structNew();
	variables.cfpayment.GATEWAYID = "1";
	variables.cfpayment.GATEWAY_NAME = "Base Gateway";
	variables.cfpayment.GATEWAY_VERSION = "1.0";
	variables.cfpayment.GATEWAY_TEST_URL = "http://localhost/";
	variables.cfpayment.GATEWAY_LIVE_URL = "http://localhost/";
	variables.cfpayment.PERIODICITY_MAP = StructNew();
	variables.cfpayment.MerchantAccount = "";
	variables.cfpayment.Username = "";
	variables.cfpayment.Password = "";
	variables.cfpayment.Timeout = 300;
	variables.cfpayment.TestMode = true;
	//  it's possible access to internal java objects is disabled, so we account for that 
	try {
		//  use this java object to get at the current RequestTimeout value for a given request 
		variables.rcMonitor = createObject("java", "coldfusion.runtime.RequestMonitor");
		variables.rcMonitorEnabled = true;
	} catch (any cfcatch) {
		variables.rcMonitorEnabled = false;
	}

	public any function init(required any service, struct config) output=false {
		var argName = "";
		variables.cfpayment.service = arguments.service;
		//  loop over any configuration and set parameters 
		if ( structKeyExists(arguments, "config") ) {
			for ( argName in arguments.config ) {
				if ( structKeyExists(arguments.config, argName) && structKeyExists(this, "set" & argName) ) {
					cfinvoke( method="set#argName#", component=this ) { //bug in lucee, see: https://luceeserver.atlassian.net/browse/LDEV-1110
						cfinvokeargument( name=argName, value=arguments.config[argName] );
					}
				}
			}
		}
		return this;
	}
	//  implemented base functions 

	/**
	 * 
	 */
	public any function getGatewayName() output=false {
		if ( structKeyExists(variables.cfpayment, "GATEWAY_NAME") ) {
			return variables.cfpayment.GATEWAY_NAME;
		} else {
			return "";
		}
	}

	/**
	 * 
	 */
	public any function getGatewayVersion() output=false {
		if ( structKeyExists(variables.cfpayment, "GATEWAY_VERSION") ) {
			return variables.cfpayment.GATEWAY_VERSION;
		} else {
			return "";
		}
	}

	public numeric function getTimeout() output=false {
		return variables.cfpayment.Timeout;
	}

	public void function setTimeout(required numeric Timeout) output=false {
		variables.cfpayment.Timeout = arguments.Timeout;
	}

	/**
	 * 
	 */
	public any function getTestMode() output=false {
		return variables.cfpayment.TestMode;
	}

	public any function setTestMode() output=false {
		variables.cfpayment.TestMode = arguments[1];
	}

	/**
	 * 
	 */
	public any function getGatewayURL() output=false {
		if ( getTestMode() ) {
			return variables.cfpayment.GATEWAY_TEST_URL;
		} else {
			return variables.cfpayment.GATEWAY_LIVE_URL;
		}
	}
	//  	Date: 7/6/2008  Usage: get access to the service for generating responses, errors, etc 

	/**
	 * get access to the service for generating responses, errors, etc
	 */
	private any function getService() output=false {
		return variables.cfpayment.service;
	}
	//  getter/setters for common configuration parameters like MID, Username, Password 

	package any function getMerchantAccount() output=false {
		return variables.cfpayment.MerchantAccount;
	}

	package void function setMerchantAccount(required any MerchantAccount) output=false {
		variables.cfpayment.MerchantAccount = arguments.MerchantAccount;
	}

	package any function getUsername() output=false {
		return variables.cfpayment.Username;
	}

	package void function setUsername(required any Username) output=false {
		variables.cfpayment.Username = arguments.Username;
	}

	package any function getPassword() output=false {
		return variables.cfpayment.Password;
	}

	package void function setPassword(required any Password) output=false {
		variables.cfpayment.Password = arguments.Password;
	}
	/*  the gatewayid is a value used by the transaction/HA apis to differentiate
		  the gateway used for a given payment.  The value is arbitrary and unique to
		  a particular system. */

	public any function getGatewayID() output=false {
		return variables.cfpayment.GATEWAYID;
	}

	public void function setGatewayID(required any GatewayID) output=false {
		variables.cfpayment.GatewayID = arguments.GatewayID;
	}
	/*  the current request timeout allows us to intelligently modify the overall page timeout based 
		  upon whatever the current page context or configured timeout dictate.  It's possible to have
		  acces to internal Java components disabled so we take that into account here. */

	private numeric function getCurrentRequestTimeout() output=false {
		if ( variables.rcMonitorEnabled ) {
			return variables.rcMonitor.getRequestTimeout();
		} else {
			return 0;
		}
	}
	//  manage transport and network/connection error handling; all gateways should send HTTP requests through this method 

	/**
	 * Robust HTTP get/post mechanism with error handling
	 */
	package struct function process(string url="#getGatewayURL(argumentCollection = arguments)#", string method="post", required any payload, struct headers="#structNew()#", boolean encoded="true", struct files="#structNew()#") output=false {
		//  can be xml (simplevalue) or a struct of key-value pairs 
		//  prepare response before attempting to send over wire 
		var CFHTTP = "";
		var status = "";
		var paramType = "";
		var ResponseData = { Status = getService().getStatusPending()
									,StatusCode = ""
									,Result = ""
									,Message = ""
									,RequestData = {}
									,TestMode = getTestMode()
									};
		//  TODO: NOTE: THIS INTERNAL DATA REFERENCE MAY GO AWAY, DO NOT RELY UPON IT!!!  DEVELOPMENT PURPOSES ONLY!!! 
		//  store payload for reference during development (can be simplevalue OR structure) 
		if ( getTestMode() ) {
			ResponseData.RequestData = { PAYLOAD = duplicate(arguments.payload)
												,GATEWAY_URL = arguments.url
												,HTTP_METHOD = arguments.method
												,HEADERS = arguments.headers
												};
		}
		//  enable a little extra time past the CFHTTP timeout so error handlers can run 
		cfsetting( requesttimeout=max(getCurrentRequestTimeout(), getTimeout() + 10) );
		try {
			CFHTTP = doHttpCall(url = arguments.url
										,timeout = getTimeout()
										,argumentCollection = arguments);
			//  begin result handling 
			if ( isDefined("CFHTTP") && isStruct(CFHTTP) && structKeyExists(CFHTTP, "fileContent") ) {
				//  duplicate the non-struct data from CFHTTP for our response 
				ResponseData.Result = CFHTTP.fileContent;
			} else {
				//  an unknown failure here where the response doesn't exist somehow or is malformed 
				ResponseData.Status = getService().getStatusUnknown();
			}
			//  make decisions based on the HTTP status code 
			ResponseData.StatusCode = reReplace(CFHTTP.statusCode, "[^0-9]", "", "ALL");
			/*  Errors that are thrown even when CFHTTP throwonerror = no:
				catch (COM.Allaire.ColdFusion.HTTPFailure postError) - invalid ssl / self-signed ssl / expired ssl
				catch (coldfusion.runtime.RequestTimedOutException postError) - tag timeout like cfhttp timeout or page timeout
				See http://www.ghidinelli.com/2012/01/03/cfhttp-error-handling-http-status-codes for all others (handled by HTTP status code below)
			*/
			//  implementation and runtime exceptions 
		} catch (cfpayment cfcatch) {
			//  we rethrow here to break the call as this may happen during development 
			rethrow;
		} catch (COM.Allaire.ColdFusion.HTTPFailure cfcatch) {
			//  "Connection Failure" - ColdFusion wasn't able to connect successfully.  This can be an expired, not legit, wildcard or self-signed SSL cert. 
			ResponseData.Message = "Gateway was !successfully reached && the transaction was !processed (100)";
			ResponseData.Status = getService().getStatusFailure();
			return ResponseData;
		} catch (coldfusion.runtime.RequestTimedOutException cfcatch) {
			ResponseData.Message = "The bank did !respond to our request.  Please wait a few moments && try again. (101)";
			ResponseData.Status = getService().getStatusTimeout();
			return ResponseData;
		} catch (any cfcatch) {
			//  convert the CFCATCH.message into the HTTP Status Code 
			ResponseData.StatusCode = reReplace(CFCATCH.message, "[^0-9]", "", "ALL");
			ResponseData.Status = getService().getStatusUnknown();
			ResponseData.Message = CFCATCH.Message & " (" & cfcatch.Type & ")";
			//  let it fall through so we can attempt to handle the status code 
		}
		if ( len(ResponseData.StatusCode) && ResponseData.StatusCode != "200" ) {
			switch ( ResponseData.StatusCode ) {
				case  "404,302,503":
					//  coldfusion doesn't follow 302s, so acts like a 404 
					ResponseData.Message = "Gateway was !successfully reached && the transaction was !processed";
					ResponseData.Status = getService().getStatusFailure();
					if ( structKeyExists(CFHTTP, "ErrorDetail") && len(CFHTTP.ErrorDetail) ) {
						ResponseData.Message = ResponseData.Message & " (Original message: #CFHTTP.ErrorDetail#)";
					}
					break;
				case  500:
					ResponseData.Message = "Gateway did !respond as expected && the transaction may have been processed";
					ResponseData.Status = getService().getStatusUnknown();
					if ( structKeyExists(CFHTTP, "ErrorDetail") && len(CFHTTP.ErrorDetail) ) {
						ResponseData.Message = ResponseData.Message & " (Original message: #CFHTTP.ErrorDetail#)";
					}
					break;
			}
		} else if ( !len(ResponseData.StatusCode) ) {
			ResponseData.Status = getService().getStatusUnknown();
		}
		//  return raw collection to be handled by gateway-specific code 
		return ResponseData;
	}
	/*  ------------------------------------------------------------------------------

		  PRIVATE HELPER METHODS FOR DEVELOPERS

		  ------------------------------------------------------------------------- */

	/**
	 * wrapper around the http call - improves testing
	 */
	private struct function doHttpCall(required string url, string method="get", required numeric timeout, struct headers="#structNew()#", any payload="#structNew()#", boolean encoded="true", struct files="#structNew()#") output=false {
		var CFHTTP = "";
		var key = "";
		var keylist = "";
		var skey = "";
		var paramType = "";
		if ( uCase(arguments.method) == "GET" ) {
			paramType = "url";
		} else if ( uCase(arguments.method) == "POST" ) {
			paramType = "formfield";
		} else if ( uCase(arguments.method) == "PUT" ) {
			paramType = "body";
		} else if ( uCase(arguments.method) == "DELETE" ) {
			paramType = "body";
		} else {
			throw( message="Invalid Method", type="cfpayment.InvalidParameter.Method" );
		}
		//  send request 
		cfhttp( throwonerror=false, url=arguments.url, timeout=arguments.timeout, method=arguments.method ) {
			//  pass along any extra headers, like Accept or Authorization or Content-Type 
			for ( key in arguments.headers ) {
				cfhttpparam( name=key, type="header", value=arguments.headers[key] );
			}
			//  accept nested structures including ordered structs (required for skipjack) 
			if ( isStruct(arguments.payload) ) {
				for ( key in arguments.payload ) {
					if ( isSimpleValue(arguments.payload[key]) ) {
						//  most common param is simple value 
						cfhttpparam( encoded=arguments.encoded, name=key, type=paramType, value=arguments.payload[key] );
					} else if ( isStruct(arguments.payload[key]) ) {
						//  loop over structure (check for _keylist to use a pre-determined output order) 
						if ( structKeyExists(arguments.payload[key], "_keylist") ) {
							keylist = arguments.payload[key]._keylist;
						} else {
							keylist = structKeyList(arguments.payload[key]);
						}
						for ( skey in keylist ) {
							if ( ucase(skey) != "_KEYLIST" ) {
								cfhttpparam( encoded=arguments.encoded, name=skey, type=paramType, value=arguments.payload[key][skey] );
							}
						}
					} else {
						throw( message="Invalid data type for #key#", detail="The payload must be either XML/JSON/string or a struct", type="cfpayment.InvalidParameter.Payload" );
					}
				}
			} else if ( isSimpleValue(arguments.payload) && len(arguments.payload) ) {
				//  some services may need a Content-Type header of application/xml, pass it in as part of the headers array instead 
				cfhttpparam( type="body", value=arguments.payload );
			} else {
				throw( message="The payload must be either XML/JSON/string or a struct", type="cfpayment.InvalidParameter.Payload" );
			}
			//  Handle file uploads with files that already exist on local drive/network. Note, this must be after the cfhttparam type formfield lines 
			for ( key in arguments.files ) {
				cfhttpparam( file=arguments.files[key], name=key, type="file" );
			}
		}
		return CFHTTP;
	}

	/**
	 * 
	 */
	private any function getOption(required any Options, required any Key, boolean ErrorIfNotFound="false") output=false {
		if ( isStruct(arguments.Options) && structKeyExists(arguments.Options, arguments.Key) ) {
			return arguments.Options[arguments.Key];
		} else {
			if ( arguments.ErrorIfNotFound ) {
				throw( message="Missing Option: #HTMLEditFormat(arguments.key)#", type="cfpayment.MissingParameter.Option" );
			} else {
				return "";
			}
		}
	}

	/**
	 * I verify that the passed in Options structure exists for each item in the RequiredOptionList argument.
	 */
	private void function verifyRequiredOptions(required struct options, required string requiredOptionList) output=false {
		var option="";
		for ( option in arguments.requiredOptionList ) {
			if ( !StructKeyExists(arguments.options, option) ) {
				throw( message="Missing Required Option - #option#", type="cfpayment.MissingParameter.Option" );
			}
		}
	}

	/**
	 * I validate the the given periodicity is valid for the current gateway.
	 */
	private any function isValidPeriodicity(required string periodicity) output=false {
		if ( len(getPeriodicityValue(arguments.periodicity)) ) {
			return true;
		} else {
			return false;
		}
	}

	/**
	 * I return the gateway-specific value for the given normalized periodicity.
	 */
	private any function getPeriodicityValue(required string periodicity) output=false {
		if ( structKeyExists(variables.cfpayment.PERIODICITY_MAP, arguments.periodicity) ) {
			return variables.cfpayment.PERIODICITY_MAP[arguments.periodicity];
		} else {
			return "";
		}
	}
	//  gateways may on RARE occasion need to override the response object; being generated by the base gateway allows an implementation to override this 

	/**
	 * Create a response object with status set to unprocessed
	 */
	public any function createResponse() output=false {
		return createObject("component", "cfpayment.api.model.response").init(argumentCollection = arguments, service = getService(), testMode = getTestMode());
	}
	/*  ------------------------------------------------------------------------------

		  PUBLIC API FOR USERS TO CALL AND FOR DEVELOPERS TO EXTEND


		  ------------------------------------------------------------------------- */
	//  Stub out the public functions (these must be implemented in the gateway folders) 

	/**
	 * Perform an authorization immediately followed by a capture
	 */
	public any function purchase(required any money, required any account, struct options) output=false {
		throw( message="Method not implemented.", type="cfpayment.MethodNotImplemented" );
	}

	/**
	 * Verifies payment details with merchant bank
	 */
	public any function authorize(required any money, required any account, struct options) output=false {
		throw( message="Method not implemented.", type="cfpayment.MethodNotImplemented" );
	}

	/**
	 * Confirms an authorization with direction to charge the account
	 */
	public any function capture(required any money, required any authorization, struct options) output=false {
		throw( message="Method not implemented.", type="cfpayment.MethodNotImplemented" );
	}

	/**
	 * Returns an amount back to the previously charged account.  Only for use with captured transactions.
	 */
	public any function credit(required any money, required any transactionid, struct options) output=false {
		throw( message="Method not implemented.", type="cfpayment.MethodNotImplemented" );
	}

	/**
	 * Cancels a previously captured transaction that has not yet settled
	 */
	public any function void(required any transactionid, struct options) output=false {
		throw( message="Method not implemented.", type="cfpayment.MethodNotImplemented" );
	}

	/**
	 * Find transactions using gateway-supported criteria
	 */
	public any function search(required struct options) output=false {
		throw( message="Method not implemented.", type="cfpayment.MethodNotImplemented" );
	}

	/**
	 * Reconstruct a response object for a previously executed transaction
	 */
	public any function status(required any transactionid, struct options) output=false {
		throw( message="Method not implemented.", type="cfpayment.MethodNotImplemented" );
	}

	/**
	 * 
	 */
	public any function recurring(required string mode, required any money, required any account, struct options) output=false {
		//  must be one of: add, edit, delete, get 
		throw( message="Method not implemented.", type="cfpayment.MethodNotImplemented" );
	}

	/**
	 * Directs the merchant account to close the open batch of transactions (typically run once per day either automatically or manually with this method)
	 */
	public any function settle(struct options) output=false {
		throw( message="Method not implemented.", type="cfpayment.MethodNotImplemented" );
	}

	/**
	 * Determine if gateway supports a specific card or account type
	 */
	public boolean function supports(required any type) output=false {
		throw( message="Method not implemented.", type="cfpayment.MethodNotImplemented" );
	}
	//  determine capability of this gateway 

	/**
	 * determine whether or not this gateway can accept credit card transactions
	 */
	public boolean function getIsCCEnabled() output=false {
		return false;
	}

	/**
	 * determine whether or not this gateway can accept ACH/EFT transactions
	 */
	public boolean function getIsEFTEnabled() output=false {
		return false;
	}

}
