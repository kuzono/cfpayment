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
component dislayname="transaction" output="false" hint="The core API for CFPAYMENT" {
	/*  
	NOTES:
	* This is the transaction API that wraps the core to provide persistence
	* Expects tables to have been created by install script	
	*/
	variables.instance = structNew();
	variables.core = createObject("component", "core");
	//  init 

	/**
	 * 
	 */
	public any function init(required struct config, any encryptionService) output=false {
		/*  the core service expects a structure of configuration information to be passed to it
			  telling it what gateway to use and so forth */
		getCore().init(config = arguments.config);
		if ( structKeyExists(arguments, "encryptionService") && isObject(arguments.encryptionService) ) {
			variables.instance.encryptionService = arguments.encryptionService;
			variables.instance.hasEncryptionService = true;
		} else {
			variables.instance.hasEncryptionService = false;
		}
		return this;
	}

	/**
	 * return the core cfpayment service
	 */
	private any function getCore() output=false {
		return variables.instance.core;
	}
	//  GATEWAY WRAPPERS FOR PERSISTENCE (only necessary for credits/debits, not lookups/etc) 

	/**
	 * Verifies payment details with merchant bank
	 */
	public any function authorize(required numeric amount, required any account, required struct params) output=false {
		/*  1. collect data, 
					if encryption service, 
						getEncryptedMemento()
					else
						leave the encrypted field blank and don't store CHD
					/if
			     write to database with a pending status */
		//  2. getCore().getGateway().charge(argumentCollection = arguments) 
		//  3. take normalized results and update database, return result 
	}
	/*  capture, charge, void, etc; all credit/debit routines 
	
			...
			...
			...
			...
			...
	
	*/
	//  PRIVATE ENCRYPTION WRAPPERS 

	private any function hasEncryptionService() output=false {
		return variables.instance.hasEncryptionService;
	}

	private any function getEncryptionService() output=false {
		return variables.instance.encryptionService;
	}

	private any function getEncryptedMemento(required any account) output=false {
		/*  WARNING: PCI DSS MANDATES WHAT CARDHOLDER DATA
			  		   MAY BE STORED.  CVC OR CVV2 IS NOT PERMITTED
			  		   TO BE RETAINED POST-AUTHORIZATION UNDER ANY
			  		   CIRCUMSTANCES.  DO NOT ADD IT TO THE ENCRYPTED
			  		   MEMENTO LIST!!!! 
			  		   
			  		   The CVC/CVV2 number is an anti-fraud tool but does
			  		   *NOT* change your processing rate so there is no reason
			  		   to retain it after attempting to charge a card.  There
			  		   are giant penalties for being out of compliance here
			  		   so if you feel that you need it, contact your acquiring
			  		   bank FIRST.
		*/
		var data = "";
		var key = "";
		if ( hasEncryptionService() ) {
			data = listAppend(data, arguments.account.getFirstName(), "|");
			data = listAppend(data, arguments.account.getLastName(), "|");
			data = listAppend(data, arguments.account.getAddress(), "|");
			data = listAppend(data, arguments.account.getPostalCode(), "|");
			if ( arguments.account.getIsCreditCard() ) {
				data = listAppend(data, arguments.account.getAccount(), "|");
				data = listAppend(data, arguments.account.getMonth(), "|");
				data = listAppend(data, arguments.account.getYear(), "|");
			} else if ( arguments.account.getIsEFT() ) {
				data = listAppend(data, arguments.account.getPhoneNumber(), "|");
				data = listAppend(data, arguments.account.getAccount(), "|");
				data = listAppend(data, arguments.account.getRoutingNumber(), "|");
				data = listAppend(data, arguments.account.getCheckNumber(), "|");
			}
			//  add random salt into encrypted data 
			data = listAppend(data, generateSecretKey("AES"), "|");
			return getEncryptionService().encryptData(data);
		}
		return "";
	}

	private void function setEncryptedMemento(required any account, required any data) output=false {
		var acct = "";
		if ( hasEncryptionService() ) {
			acct = getEncryptionService().decryptData(arguments.data);
			//  use settings to return object to decrypted status 
			arguments.account.setFirstName(listGetAt(acct, 1, "|"));
			arguments.account.setLastName(listGetAt(acct, 2, "|"));
			arguments.account.setAddress(listGetAt(acct, 3, "|"));
			arguments.account.setPostalCode(listGetAt(acct, 4, "|"));
			if ( arguments.account.getIsCreditCard() ) {
				arguments.account.setAccount(listGetAt(acct, 5, "|"));
				arguments.account.setMonth(listGetAt(acct, 6, "|"));
				arguments.account.setYear(listGetAt(acct, 7, "|"));
			} else if ( arguments.account.getIsEFT() ) {
				arguments.account.setPhoneNumber(listGetAt(acct, 5, "|"));
				arguments.account.setAccount(listGetAt(acct, 6, "|"));
				arguments.account.setRoutingNumber(listGetAt(acct, 7, "|"));
				arguments.account.setCheckNumber(listGetAt(acct, 8, "|"));
			}
		}
	}

}
