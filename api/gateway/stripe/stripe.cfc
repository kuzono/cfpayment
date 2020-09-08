/*
    Converts tag based CFML to CFML script
*/
/*
	Original code from Phil Cruz's Stripe.cfc from https://github.com/philcruz/Stripe.cfc/blob/master/stripe/Stripe.cfc
	Added Stripe Connect/Marketplace support in 2015 by Chris Mayes & Brian Ghidinelli (http://www.ghidinelli.com)

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
 * Stripe Gateway
 */
component displayname="Stripe Gateway" extends="cfpayment.api.gateway.base" hint="Stripe Gateway" output="false" {
	variables.cfpayment.GATEWAY_NAME = "Stripe";
	variables.cfpayment.GATEWAY_VERSION = "xx.xx.xx";
	variables.cfpayment.API_VERSION = "2020-08-27";
	//  stripe test mode uses different credentials instead of different urls
	variables.cfpayment.GATEWAY_URL = "https://api.stripe.com/v1";

	public string function getSecretKey() output=false {
		if ( getTestMode() ) {
			return variables.cfpayment.TestSecretKey;
		} else {
			return variables.cfpayment.LiveSecretKey;
		}
	}

	public string function getLiveSecretKey() output=false {
		return variables.cfpayment.LiveSecretKey;
	}

	public void function setLiveSecretKey(required string LiveSecretKey) output=false {
		variables.cfpayment.LiveSecretKey = arguments.LiveSecretKey;
	}

	public string function getTestSecretKey() output=false {
		return variables.cfpayment.TestSecretKey;
	}

	public void function setTestSecretKey(required string TestSecretKey) output=false {
		variables.cfpayment.TestSecretKey = arguments.TestSecretKey;
	}

	public string function getPublishableKey() output=false {
		if ( getTestMode() ) {
			return variables.cfpayment.TestPublishableKey;
		} else {
			return variables.cfpayment.LivePublishableKey;
		}
	}

	public string function getLivePublishableKey() output=false {
		return variables.cfpayment.LivePublishableKey;
	}

	public void function setLivePublishableKey(required string LivePublishableKey) output=false {
		variables.cfpayment.LivePublishableKey = arguments.LivePublishableKey;
	}

	public string function getTestPublishableKey() output=false {
		return variables.cfpayment.TestPublishableKey;
	}

	public void function setTestPublishableKey(required string TestPublishableKey) output=false {
		variables.cfpayment.TestPublishableKey = arguments.TestPublishableKey;
	}

	public string function getApiVersion() output=false {
		return variables.cfpayment.API_VERSION;
	}

	public void function setApiVersion() output=false {
		variables.cfpayment.API_VERSION = arguments[1];
	}

	/**
	 * Authorize but don't capture a credit card
	 */
	public any function authorize(required any money, any account, struct options="#structNew()#") output=false {
		arguments.options["capture"] = false;
		return purchase(argumentCollection = arguments);
	}

	/**
	 * Capture a previously authorized charge
	 */
	public any function capture(required string transactionId, struct options="#structNew()#") output=false {
		return process(gatewayUrl = getGatewayUrl("/charges/#arguments.transactionId#/capture"), payload = post, options = options);
	}

	/**
	 * Authorize + Capture in one step
	 */
	public any function purchase(required any money, any account, struct options="#structNew()#") output=false {
		var post = {};
		var response = "";
		post["amount"] = arguments.money.getCents();
		post["currency"] = lCase(arguments.money.getCurrency());
		//  iso currency code must be lower case?
		if ( structKeyExists(arguments, "account") ) {
			switch ( getService().getAccountType(arguments.account) ) {
				case  "creditcard":
					post = addCreditCard(post = post, account = arguments.account);
					break;
				case  "token":
					post = addToken(post = post, account = arguments.account);
					break;
				default:
					throw( message="The account type #getService().getAccountType(arguments.account)# is not supported by this gateway.", type="cfpayment.InvalidAccount" );
					break;
			}
		}
		return process(gatewayUrl = getGatewayUrl("/charges"), payload = post, options = options);
	}

	/**
	 * Returns an amount back to the previously charged account.  Default is to refund the full amount.
	 */
	public any function refund(any money, required any transactionId, boolean refund_application_fee, boolean reverse_transfer, struct options="#structNew()#") output=false {
		local.post = structNew();
		//  default is to refund full amount
		if ( structKeyExists(arguments, "money") ) {
			post["amount"] = abs(arguments.money.getCents());
		}
		//  self-documenting
		if ( structKeyExists(arguments, "refund_application_fee") ) {
			post["refund_application_fee"] = arguments.refund_application_fee;
		}
		if ( structKeyExists(arguments, "reverse_transfer") ) {
			post["reverse_transfer"] = arguments.reverse_transfer;
		}
		return process(gatewayUrl = getGatewayURL("/charges/#arguments.transactionId#/refunds"), payload = post, options = options);
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
	public any function status(required any transactionId, struct options) output=false {
		return process(gatewayUrl = getGatewayURL("/charges/#arguments.transactionId#"), options = options, method = "GET");
	}

	/**
	 * Convert payment details to a one-time token for charging once.  To store payment details for repeat use, convert to a customer object with store().
	 */
	public any function validate(required any account, any money) output=false {
		var post = "";
		if ( getService().getAccountType(account) == "creditcard" ) {
			post = addCreditCard(post = structNew(), account = arguments.account);
		} else if ( getService().getAccountType(account) == "eft" ) {
			post = addBankAccount(post = structNew(), account = arguments.account);
		}
		return process(gatewayUrl = getGatewayURL("/tokens"), payload = post);
	}

	/**
	 * Convert a one-time token (from validate() or Stripe.js) into a Customer object for charging one or more times in the future
	 */
	public any function store(required any account, struct options="#structNew()#") output=false {
		var post = {};
		if ( getService().getAccountType(account) == "creditcard" ) {
			post = addCreditCard(post = post, account = account);
		} else if ( getService().getAccountType(account) == "eft" ) {
			post = addBankAccount(post = post, account = account);
		} else {
			post["source"] = arguments.account.getID();
		}
		//  optional things to add
		if ( structKeyExists(arguments.options, "coupon") ) {
			post["coupon"] = arguments.options.coupon;
		}
		if ( structKeyExists(arguments.options, "account_balance") ) {
			post["account_balance"] = arguments.options.account_balance;
		}
		if ( structKeyExists(arguments.options, "plan") ) {
			post["plan"] = arguments.options.plan;
		}
		if ( structKeyExists(arguments.options, "trial_end") ) {
			post["trial_end"] = dateToUTC(arguments.options.trial_end);
		}
		if ( structKeyExists(arguments.options, "quantity") ) {
			post["quantity"] = arguments.options.quantity;
		}
		return process(gatewayUrl = getGatewayURL("/customers"), payload = post, options = options);
	}

	public any function unstore(required string tokenId) output=false {
		return process(gatewayUrl = getGatewayURL("/customers/#arguments.tokenId#"), method = "DELETE");
	}

	public any function listCharges(numeric count, numeric offset, string tokenId) output=false {
		var payload = {};
		for ( key in arguments ) {
			if ( structKeyExists(arguments, key) ) {
				payload[lcase(key)] = arguments[key];
			}
		}
		return process(gatewayUrl = getGatewayUrl("/charges"), method = "GET", payload = payload);
	}

	/**
	 * Retrieve details about an application fee
	 */
	public any function getApplicationFee(required any id, struct options="#structNew()#") output=false {
		return process(gatewayUrl = getGatewayURL("/application_fees/#arguments.id#"), payload = {}, options = arguments.options, method = "GET");
	}

	/**
	 * Retrieve current Stripe account balance when automatic transfers are disabled
	 */
	public any function getBalance() output=false {
		return process(gatewayUrl = getGatewayURL("/balance"), payload = {}, method = "GET");
	}

	/**
	 * Convert a credit card or bank account into a one-time Stripe token for charging/attaching to a customer, or disbursing/attaching to a recipient (note, using this rather than Stripe.js means you are responsible for ALL PCI DSS compliance)
	 */
	public any function createToken(required any account, struct options="#structNew()#") output=false {
		var post = {};
		switch ( getService().getAccountType(arguments.account) ) {
			case  "creditcard":
				post = addCreditCard(post = post, account = arguments.account);
				break;
			case  "eft":
				post = addBankAccount(post = post, account = arguments.account);
				break;
			default:
				throw( message="The account type #getService().getAccountType(arguments.account)# is not supported by createToken()", type="cfpayment.InvalidAccount" );
				break;
		}
		return process(gatewayUrl = getGatewayURL("/tokens"), payload = post, options = options);
	}

	/**
	 * Get a token for an existing customer)
	 */
	public any function createTokenInConnectedAccount(required any customer, required any ConnectedAccount) output=false {
		return process(gatewayUrl = getGatewayURL("/tokens"), payload = {}, options = {"ConnectedAccount": arguments.ConnectedAccount, "customer": arguments.customer});
	}

	/**
	 * Retrieve details about a one-time use token
	 */
	public any function getAccountToken(required any id) output=false {
		return process(gatewayUrl = getGatewayURL("/tokens/#arguments.id#"), payload = {}, options = {}, method = "GET");
	}

	/**
	 * List Connect accounts for a platform
	 */
	public any function listConnectedAccounts() output=false {
		return process(gatewayUrl = getGatewayURL("/accounts"), payload = structNew(), method = "GET");
	}

	/**
	 * Provisions a marketplace account
	 */
	public any function createConnectedAccount(required string country, required boolean managed, string email, struct options="#structNew()#") output=false {
		//  two set-only and important fields: country, managed
		local.post = {};
		post["country"] = arguments.country;
		post["managed"] = arguments.managed;
		if ( !arguments.managed && !structKeyExists(arguments, "email") ) {
			throw( message="Stripe requires an email address when creating an unmanaged account", type="cfpayment.InvalidArguments" );
		} else if ( structKeyExists(arguments, "email") ) {
			post["email"] = arguments.email;
		}
		return process(gatewayUrl = getGatewayURL("/accounts"), payload = post, options = options);
	}

	/**
	 *
	 */
	public any function updateConnectedAccount(required any ConnectedAccount, struct options="#structNew()#") output=false {
		return process(gatewayUrl = getGatewayURL("/accounts/#arguments.ConnectedAccount.getID()#"), payload = structNew(), options = options);
	}

	/**
	 *
	 */
	public any function listBankAccounts(required any ConnectedAccount) output=false {
		return process(gatewayUrl = getGatewayURL("/accounts/#arguments.ConnectedAccount.getID()#/bank_accounts"), payload = structNew(), method = "GET");
	}

	/**
	 *
	 */
	public any function deleteBankAccount(any ConnectedAccount, any bankAccountId) output=false {
		return process(gatewayUrl = getGatewayURL("/accounts/#arguments.ConnectedAccount.getID()#/bank_accounts/#arguments.bankAccountId#"), payload = {}, method = "DELETE");
	}

	/**
	 *
	 */
	public any function createBankAccount(any ConnectedAccount, any account, required string currency) output=false {
		local.post = structNew();
		if ( getService().getAccountType(account) == "token" ) {
			post["bank_account"] = arguments.account.getID();
		} else if ( getService().getAccountType(account) == "eft" ) {
			post = addBankAccount(post = post, account = account);
			post["bank_account[currency]"] = lcase(arguments.currency);
		} else {
			throw( message="The account type #getService().getAccountType(arguments.account)# is not supported by this gateway.", type="cfpayment.InvalidAccount" );
		}
		return process(gatewayUrl = getGatewayURL("/accounts/#arguments.ConnectedAccount.getID()#/bank_accounts"), payload = local.post);
	}

	/**
	 *
	 */
	public any function setDefaultBankAccountForCurrency(any ConnectedAccount, any bankAccountId) output=false {
		local.post = {"default_for_currency": true};
		return process(gatewayUrl = getGatewayURL("/accounts/#arguments.ConnectedAccount.getID()#/bank_accounts/#arguments.bankAccountId#"), payload = local.post);
	}

	/**
	 * Stripe allows file uploads for identity verification and chargeback dispute evidence - first upload and then assign the file id to its intended object
	 */
	public any function uploadFile(any file, required string purpose, struct options="#structNew()#") output=false {
		if ( !listFind("identity_document,dispute_evidence", arguments.purpose) ) {
			throw( message="Purpose must be one of: identity_document, dispute_evidence", type="cfpayment.InvalidArguments" );
		}
		local.files = {"file": arguments.file};
		local.post = {"purpose": arguments.purpose};
		return process(gatewayUrl = "https://uploads.stripe.com/v1/files", payload = local.post, files = local.files, options = arguments.options);
	}

	/**
	 * For attaching Connect account identity documents
	 */
	public any function attachIdentityFile(required any ConnectedAccount, required any fileId, struct options="#structNew()#") output=false {
		local.post = {"legal_entity[verification][document]": arguments.fileId};
		return process(gatewayUrl = getGatewayURL("/accounts/#arguments.ConnectedAccount.getID()#"), payload = local.post, options = arguments.options);
	}

	/**
	 *
	 */
	public any function updateDispute(any transactionId, struct options="#structNew()#") output=false {
		return process(gatewayUrl = getGatewayURL("/charges/#arguments.transactionId#/disputes"), payload = structNew(), options = arguments.options);
	}

	/**
	 *
	 */
	public any function listTransfers(struct options="#structNew()#") output=false {
		return process(gatewayUrl = getGatewayURL("/transfers"), payload = {}, options = arguments.options, method = "GET");
	}

	/**
	 *
	 */
	public any function transfer(required any money, required any destination, struct options="#structNew()#") output=false {
		local.post = structNew();
		local.post["amount"] = arguments.money.getCents();
		local.post["currency"] = lCase(arguments.money.getCurrency());
		local.post["destination"] = arguments.destination.getID();
		return process(gatewayUrl = getGatewayURL("/transfers"), payload = local.post, options = arguments.options);
	}

	public any function transferReverse(required string transferId, any money, boolean refund_application_fee, struct options="#structNew()#") output=false {
		local.post = structNew();
		if ( structKeyExists(arguments, "money") ) {
			post["amount"] = abs(arguments.money.getCents());
		}
		//  self-documenting
		if ( structKeyExists(arguments, "refund_application_fee") ) {
			post["refund_application_fee"] = arguments.refund_application_fee;
		}
		return process(gatewayUrl = getGatewayURL("/transfers/#arguments.transferId#/reversals"), payload = post, options = arguments.options);
	}
	//  determine capability of this gateway

	/**
	 * determine whether or not this gateway can accept credit card transactions
	 */
	public boolean function getIsCCEnabled() output=false {
		return true;
	}
	//  process wrapper with gateway/transaction error handling

	private any function process(required string gatewayUrl, required struct payload, struct options="#structNew()#", struct headers="#structNew()#", string method="post", struct files="#structNew()#") output=false {
		var results = "";
		var response = "";
		var p = arguments.payload;
		//  shortcut (by reference)
		//  process standard and common CFPAYMENT mappings into gateway-specific values
		if ( structKeyExists(arguments.options, "description") ) {
			p["description"] = arguments.options.description;
		}
		if ( structKeyExists(arguments.options, "tokenId") ) {
			p["customer"] = arguments.options.tokenId;
		}
		//  add baseline authentication
		headers["authorization"] = "Bearer #getSecretKey()#";
		//  add connect authentication on behalf of a Connect/Marketplace customer
		if ( structKeyExists(arguments.options, "ConnectedAccount") ) {
			if ( !isObject(arguments.options.ConnectedAccount) ) {
				throw( message="ConnectedAccount must be a cfpayment token object", type="cfpayment.InvalidArguments" );
			}
			headers["Stripe-Account"] = arguments.options.ConnectedAccount.getID();
			structDelete(arguments.options, "ConnectedAccount");
		}
		//  if we want to override the stripe API version, we can set it in the config with "ApiVersion".  Using 'latest' overrides to current version
		if ( len(getApiVersion()) ) {
			//  https://groups.google.com/a/lists.stripe.com/forum/#!topic/api-discuss/V4sYRlHwalc
			headers["Stripe-Version"] = getApiVersion();
		}
		//  help track where this request was made from
		headers["User-Agent"] = "Stripe/v1 cfpayment/#variables.cfpayment.GATEWAY_VERSION#";
		//  add dynamic statement descriptors which show up on CC statement alongside merchant name: https://stripe.com/docs/api#create_charge
		if ( structKeyExists(arguments.options, "statement_descriptor") ) {
			p["statement_descriptor"] = reReplace(arguments.options.statement_descriptor, "[<>""']", "", "ALL");
			structDelete(arguments.options, "statement_descriptor");
		}
		//  application_fee is a money object, just like the amount to be charged
		if ( structKeyExists(arguments.options, "application_fee") ) {
			if ( !isObject(arguments.options.application_fee) ) {
				throw( message="application_fee must be a cfpayment money object", type="cfpayment.InvalidArguments" );
			}
			p["application_fee"] = arguments.options.application_fee.getCents();
			structDelete(arguments.options, "application_fee");
		}
		//  if a card is converted to a customer, you can optionally pass a customer to many requests to charge their default account instead
		if ( structKeyExists(arguments.options, "customer") ) {
			if ( !isObject(arguments.options.customer) ) {
				throw( message="Customer must be a cfpayment token object", type="cfpayment.InvalidArguments" );
			}
			p = addCustomer(post = p, customer = arguments.options.customer);
			structDelete(arguments.options, "customer");
		}
		if ( structKeyExists(arguments.options, "destination") ) {
			if ( !isObject(arguments.options.destination) ) {
				throw( message="Destination must be a cfpayment token object", type="cfpayment.InvalidArguments" );
			}
			p["destination"] = arguments.options.destination.getID();
			structDelete(arguments.options, "destination");
		}
		//  finally, copy in any additional keys like customer, destination, etc, stripe always wants lower-case
		for ( local.key in arguments.options ) {
			p[lcase(key)] = arguments.options[key];
		}
		//  Stripe returns errors with http status like 400,402 or 404 (https://stripe.com/docs/api#errors)
		response = createResponse(argumentCollection = super.process(url = arguments.gatewayUrl, payload = payload, headers = headers, method = arguments.method, files = files));
		if ( isJSON(response.getResult()) ) {
			results = deserializeJSON(response.getResult());
			response.setParsedResult(results);
			//  take object-specific IDs like tok_*, ch_*, re_*, etc and always put it as the transaction id
			if ( structKeyExists(results, "id") ) {
				response.setTransactionID(results.id);
			}
			//  the available 'types': list, customer, charge, token, card, bank_account, refund, application_fee, transfer, transfer_reversal, account, file_upload
			if ( structKeyExists(results, "object") ) {
				switch ( results.object ) {
					case  "account":
						response.setTokenID(results.id);
						break;
					case  "bank_account":
						response.setTokenID(results.id);
						break;
					case  "charge":
						response.setCVVCode(normalizeCVV(results.source));
						response.setAVSCode(normalizeAVS(results.source));
						//  if you authorize without capture, you use the charge id to capture it later, which is the same as the transaction id, but for normality, put it here
						if ( structKeyExists(results, "captured") && !results.captured && structKeyExists(results, "id") ) {
							response.setAuthorization(results.id);
						}
						break;
					case  "customer":
						/*  customers have a "sources" key with, by default, one card on file
							  you can add more cards to a customer using the card api, but otherwise
							  adding a new one actually replaces the previous one on file.
							  we make the assumption today that we only have one until someone needs more
						*/
						response.setCVVCode(normalizeCVV(results.sources.data[1]));
						response.setAVSCode(normalizeAVS(results.sources.data[1]));
						response.setTokenID(results.id);
						break;
					case  "token":
						//  stripe does not check AVS/CVV at the token stage - only once converted to a customer or in a charge
						//  could be results.source.object EQ card or bank_account
						response.setTokenID(results.id);
						break;
				}
			}
		}
		//  now add custom handling of status codes for Stripe which overrides base.cfc
		handleHttpStatus(response = response);
		return response;
	}

	private string function normalizeCVV(required any source) output=false {
		//  translate to normalized cfpayment CVV codes
		if ( structKeyExists(arguments.source, "cvc_check") && arguments.source.cvc_check == "pass" ) {
			return "M";
		} else if ( structKeyExists(arguments.source, "cvc_check") && arguments.source.cvc_check == "fail" ) {
			return "N";
		} else if ( structKeyExists(arguments.source, "cvc_check") && arguments.source.cvc_check == "unchecked" ) {
			return "U";
		} else if ( !structKeyExists(arguments.source, "cvc_check") ) {
			//  indicates it wasn't checked
			return "";
		} else {
			return "P";
		}
	}

	private string function normalizeAVS(required any source) output=false {
		//  translate to normalized cfpayment AVS codes.  Options are pass, fail, unavailable and unchecked.  Watch out that either address_line1_check or address_zip_check can be null OR "unchecked"; null throws error trying to access
		if ( structKeyExists(arguments.source, "address_zip_check") && arguments.source.address_zip_check == "pass"
			  && structKeyExists(arguments.source, "address_line1_check") && arguments.source.address_line1_check == "pass" ) {
			return "M";
		} else if ( structKeyExists(arguments.source, "address_zip_check") && arguments.source.address_zip_check == "pass" ) {
			return "P";
		} else if ( structKeyExists(arguments.source, "address_line1_check") && arguments.source.address_line1_check == "pass" ) {
			return "B";
		} else if ( (structKeyExists(arguments.source, "address_zip_check") && arguments.source.address_zip_check == "unchecked")
				  || (structKeyExists(arguments.source, "address_line1_check") && arguments.source.address_line1_check == "unchecked") ) {
			if ( arguments.source.country == "US" ) {
				return "S";
			} else {
				return "G";
			}
		} else if ( !structKeyExists(arguments.source, "address_zip_check") && !structKeyExists(arguments.source, "address_line1_check") ) {
			//  indicates it wasn't checked
			return "";
		} else {
			return "N";
		}
	}
	/*
	//Stripe returns errors with http status like 400, 402 or 404 (https://stripe.com/docs/api#errors)
	//so we need to override http status handling in base.cfc process()
	 */

	/**
	 * Override base HTTP status code handling with Stripe-specific results
	 */
	private any function handleHttpStatus(required any response) output=false {
		/*
			HTTP Status Code Summary
			200 OK - Everything worked as expected.
			400 Bad Request - Often missing a required parameter.
			401 Unauthorized - No valid API key provided.
			402 Request Failed - Parameters were valid but request failed.
			404 Not Found - The requested item doesn't exist.
			500, 502, 503, 504 Server errors - something went wrong on Stripe's end.

			Errors
			Invalid Request Errors
			Type: invalid_request_error

			API Errors
			Type: api_error

			Card Errors
			Type: card_error

			Code	Details
			incorrect_number	The card number is incorrect
			invalid_number	The card number is not a valid credit card number
			invalid_expiry_month	The card's expiration month is invalid
			invalid_expiry_year	The card's expiration year is invalid
			invalid_cvc	The card's security code is invalid
			expired_card	The card has expired
			incorrect_cvc	The card's security code is incorrect
			card_declined	The card was declined.
			missing	There is no card on a customer that is being charged.
			processing_error	An error occurred while processing the card.
		*/

		var status = response.getStatusCode();
			var res = response.getParsedResult();

			switch(status)
			{
				case "200": // OK - Everything worked as expected.
					response.setStatus(getService().getStatusSuccessful());
					break;

				case "401": // Unauthorized - No valid API key provided.
					response.setMessage("There is a configuration error preventing the transaction from completing successfully. (Original issue: Invalid API key)");
					response.setStatus(getService().getStatusFailure());
					break;

				case "402": //  Request Failed - Parameters were valid but request failed. e.g. invalid card, cvc failed, etc.
					response.setStatus(getService().getStatusDeclined());
					break;

				case "400": // Bad Request - Often missing a required parameter, includes parameter not allowed or params not lowercase
				case "404": // Not Found - The requested item doesn't exist.  i.e. no charge for that id
					response.setStatus(getService().getStatusFailure());
					break;

				case "500": // Server errors - something went wrong on Stripe's end.
				case "502":
				case "503":
				case "504":
					response.setStatus(getService().getStatusFailure());
					break;
			}

			if (response.hasError() AND isStruct(res) AND structKeyExists(res, "error"))
			{
				if (structKeyExists(res.error, "message"))
					response.setMessage(res.error.message);

				if (structKeyExists(res.error, "code"))
				{
					switch (res.error.code)
					{
						case "incorrect_number":
						case "invalid_number":
						case "invalid_expiry_month":
						case "invalid_expiry_year":
						case "invalid_cvc":
						case "expired_card":
						case "incorrect_cvc":
						case "card_declined":
						case "missing":
						case "processing_error":
							// can do more involved translation to human-speak here
							response.setMessage(response.getMessage() & " [#res.error.code#]");
							break;
						default:
							response.setMessage(response.getMessage() & " [#res.error.code#]");
					}
				}
				else
				{
					response.setMessage("Gateway returned unknown response: #status#");
				}
			}
		return response;
	}

	/**
	 * Append to Gateway URL to return the appropriate url for the API endpoint
	 */
	public any function getGatewayURL(string endpoint="") output=false {
		return variables.cfpayment.GATEWAY_URL & arguments.endpoint;
	}
	//  HELPER FUNCTIONS

	/**
	 * Add payment source fields to the request object
	 */
	private any function addCreditCard(required struct post, required any account) output=false {

		post["card[number]"] = arguments.account.getAccount();
			post["card[exp_month]"] = arguments.account.getMonth();
			post["card[exp_year]"] = arguments.account.getYear();
			post["card[cvc]"] = arguments.account.getVerificationValue();
			post["card[name]"] = arguments.account.getName();
			post["card[address_line1]"] = arguments.account.getAddress();
			post["card[address_line2]"] = arguments.account.getAddress2();
			post["card[address_zip]"] = arguments.account.getPostalCode();
			post["card[address_state]"] = arguments.account.getRegion();
			post["card[address_country]"] = arguments.account.getCountry();
		return post;
	}

	/**
	 * Add payment source fields to the request object
	 */
	private any function addBankAccount(required struct post, required any account) output=false {

		post["bank_account[country]"] = arguments.account.getCountry();
			post["bank_account[routing_number]"] = arguments.account.getRoutingNumber();
			post["bank_account[account_number]"] = arguments.account.getAccount();
		return post;
	}

	/**
	 * Add payment source fields to the request object
	 */
	private any function addToken(required struct post, required any account) output=false {
		arguments.post["source"] = arguments.account.getID();
		return arguments.post;
	}

	/**
	 * Add payment source fields to the request object
	 */
	private any function addCustomer(required struct post, required any customer) output=false {
		arguments.post["customer"] = arguments.customer.getID();
		return arguments.post;
	}

	/**
	 * Take a date and return the number of seconds since the Unix Epoch
	 */
	public any function dateToUTC(required any date) output=false {
		return dateDiff("s", dateConvert("utc2Local", "January 1 1970 00:00"), arguments.date);
	}

	/**
	 * Take a UTC timestamp and convert it to a ColdFusion date object
	 */
	public date function UTCToDate(required utcdate) output=false {
		return dateAdd("s", arguments.utcDate, dateConvert("utc2Local", "January 1 1970 00:00"));
	}
	//  stripe createResponse() overrides the getSuccess/hasError() responses

	/**
	 * Create a Stripe response object with status set to unprocessed
	 */
	public any function createResponse() output=false {
		return createObject("component", "response").init(argumentCollection = arguments, service = getService());
	}

}
