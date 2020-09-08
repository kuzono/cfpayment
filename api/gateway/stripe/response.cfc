/*
 * 	$Id$
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
*
 **/
component {
	variables.n = 0;

	public function init(number) {
		variables.n = arguments.number;
		return this;
	}

	public boolean function greaterThan(x="0") {
		return x > variables.n;
	}

	public boolean function lessThan(x="0") {
		return x < variables.n;
	}

}
