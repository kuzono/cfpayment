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
 * The core API for CFPAYMENT
 */
component name="core" output="false" displayname="CFPAYMENT Core" hint="The core API for CFPAYMENT" {
	/* 
	NOTES:
	* This is the main object that will be invoked
	* Create the object and init() it with a configuration object

	USAGE:
		requires a configuration object that looks like:

			.path (REQUIRED, to gateway cfc, could be "itransact.itransact_cc" or "bogus.gateway")
			.id (a unique id you give your gateways.  If only ever have one, use 1)
			.mid (merchant account number)
			.username
			.password
			...
			(these are arbitrary keys passed to the gateway on init so if not using l/p, pass here)

	*/
	//  pseudo-constructor 
	variables.instance = structNew();
	variables.instance.VERSION = "@VERSION@";

	/**
	 * Initialize the core API and return a reference to it
	 */
	public any function init(required struct config) output=false {
		variables.instance.config = arguments.config;
		/*  the core service expects a structure of configuration information to be passed to it
			  telling it what gateway to use and so forth */
		try {
			//  instantiate gateway and initialize it with the passed configuration 
			variables.instance.gateway = createObject("component", "gateway.#lCase(variables.instance.config.path)#").init(config = variables.instance.config, service = this);
		} catch (template cfcatch) {
			//  these are errors in the gateway itself, need to bubble them up for debugging 
			rethrow;
		} catch (application cfcatch) {
			throw( message="Invalid Gateway Specified", type="cfpayment.InvalidGateway" );
		} catch (any cfcatch) {
			rethrow;
		}
		return this;
	}
	//  PUBLIC METHODS 

	/**
	 * return the gateway or throw an error
	 */
	public any function getGateway() output=false {
		return variables.instance.gateway;
	}
	//  getters and setters 

	public string function getVersion() output=false {
		if ( isNumeric(variables.instance.version) ) {
			return variables.instance.version;
		} else {
			return "SVN";
		}
	}

	/**
	 * return a credit card object for population
	 */
	public any function createCreditCard() output=false {
		return createObject("component", "model.creditcard").init(argumentCollection = arguments);
	}

	/**
	 * create an electronic funds transfer (EFT) object for population
	 */
	public any function createEFT() output=false {
		return createObject("component", "model.eft").init(argumentCollection = arguments);
	}

	/**
	 * create a representation for OAuth credentials to perform actions on behalf of someone
	 */
	public any function createOAuth() output=false {
		return createObject("component", "model.oauth").init(argumentCollection = arguments);
	}

	/**
	 * create a remote storage token for population
	 */
	public any function createToken() output=false {
		return createObject("component", "model.token").init(argumentCollection = arguments);
	}

	/**
	 * Create a money component for amount and currency conversion and formatting
	 */
	public any function createMoney() output=false {
		return createObject("component", "model.money").init(argumentCollection = arguments);
	}

	public any function getAccountType(required any Account) output=false {
		return lcase(listLast(getMetaData(arguments.account).fullname, "."));
	}
	//  statuses to determine success and failure 

	/**
	 * This status is used to denote the transaction wasn't performed
	 */
	public any function getStatusUnprocessed() output=false {
		return -1;
	}

	/**
	 * This status indicates success
	 */
	public any function getStatusSuccessful() output=false {
		return 0;
	}

	/**
	 * This status indicates when we have sent a request to the gateway and are awaiting response (Transaction API or delayed settlement like ACH)
	 */
	public any function getStatusPending() output=false {
		return 1;
	}

	/**
	 * This status indicates a declined transaction
	 */
	public any function getStatusDeclined() output=false {
		return 2;
	}

	/**
	 * This status indicates something went wrong like the gateway threw an error but we believe the transaction was not processed
	 */
	public any function getStatusFailure() output=false {
		return 3;
	}

	/**
	 * This status indicates the remote server doesn't answer meaning we don't know if transaction was processed
	 */
	public any function getStatusTimeout() output=false {
		return 4;
	}

	/**
	 * This status indicates an exception we don't know how to handle (yet)
	 */
	public any function getStatusUnknown() output=false {
		return 99;
	}

	/**
	 * This defines which statuses are errors
	 */
	public any function getStatusErrors() output=false {
		return "3,4,99";
	}

}
