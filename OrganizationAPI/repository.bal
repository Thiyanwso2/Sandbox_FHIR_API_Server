// // Copyright (c) 2023, WSO2 LLC. (http://www.wso2.com). All Rights Reserved.

// This software is the property of WSO2 LLC. and its suppliers, if any.
// Dissemination of any information or reproduction of any material contained
// herein is strictly forbidden, unless permitted by WSO2 in accordance with
// the WSO2 Software License available at: https://wso2.com/licenses/eula/3.2
// For specific language governing the permissions and limitations under
// this license, please see the license as well as any agreement you’ve
// entered into with WSO2 governing the purchase of this software and any
// associated services.

import ballerinax/health.fhir.r4;
import ballerina/random;
import ballerina/http;
import ballerina/time;

isolated map<r4:Organization> data = {};

isolated function addJson(json organization) returns r4:FHIRError|string {
    lock {
        r4:Organization|error parsedResource = r4:parse(organization.clone(), r4:Organization).ensureType();

        if parsedResource is error {
            return r4:createFHIRError("Can't parse the resource", r4:CODE_SEVERITY_ERROR,
            r4:PROCESSING_NOT_FOUND,
            httpStatusCode = http:STATUS_BAD_REQUEST);
        } else {
            return add(parsedResource);
        }

    }
}

public isolated function add(r4:Organization organization) returns r4:FHIRError|string {
    lock {
        int|random:Error randomInteger = random:createIntInRange(100000, 1000000);

        if randomInteger is random:Error {
            return r4:createFHIRError("Something went wrong while processing the request",
                r4:ERROR,
                r4:PROCESSING);
        }
        if data.length() >= 500 {
            //return error
        }

        string randomId = randomInteger.toBalString();
        organization.id = randomId;
        organization.meta.lastUpdated = time:utcToString(time:utcNow());
        data[randomId] = organization.clone();
        return <string>organization.id;
    }
}

isolated function get(string id) returns r4:FHIRError|r4:Organization {
    r4:Organization clone = {};
    lock {

        if (data.hasKey(id)) {
            clone = data.get(id).clone();
        } else {
            return r4:createFHIRError("No resource found for the provided id", r4:CODE_SEVERITY_ERROR,
            r4:PROCESSING_NOT_FOUND,
            diagnostic = "No resource found for the provided id: " + id,
            httpStatusCode = http:STATUS_BAD_REQUEST
            );
        }

    }
    return clone;
}

public isolated function search(map<string[]> searchParameters) returns r4:FHIRError|r4:Organization[] {

    // Define the search params here supported by Sandbox
    string[] supportedParams = ["_id", "name", "address-city"];

    //Create cloned copy of the in-memory organizations map to an array 
    r4:Organization[] organizations = [];
    lock {
        organizations = data.clone().toArray();
    }

    //Check whether there any search parameters in the requested search parameter list,
    //other than _count & _offset
    string[] filteredParams = searchParameters.keys().filter(k => k != "_count").filter(k => k != "_offset");

    // If no search parameters other than _count & _offset skip the search process
    if filteredParams.length() == 0 {
        // Apply offset and count here
        return organizations;
    }

    // If In-memory organizations map is empty skip the search process
    if organizations.length() == 0 {
        return organizations;
    }
    foreach var searchParam in filteredParams {

        // Check whether the current(loop) search param is in the supported search param list
        string[] allowedsearchParam = supportedParams.filter(s => s == searchParam);

        if allowedsearchParam.length() != 1 {
            // return error saying currently, the particular search param is not supported 
            return r4:createFHIRError("Request search parameter is not implemented",
            r4:ERROR,
            r4:PROCESSING_NOT_SUPPORTED,
            diagnostic = "Request search parameter is not implemented: " + searchParam,
            httpStatusCode = http:STATUS_BAD_REQUEST);
        }

        // Retrieve the current(loop) search param values
        string[]? valuelist = searchParameters[allowedsearchParam[0]];
        string[] value = valuelist ?: [];

        if value.length() != 0 {
            r4:Organization[] filteredList = [];

            if searchParam == "_id" {
                string param = "id";

                foreach var queriedValue in value {
                    r4:Organization[] result = from r4:Organization entry in organizations
                        where entry[param] == queriedValue
                        select entry;
                    filteredList.push(...result);
                }
            }

            if searchParam == "name" {

                foreach var queriedValue in value {
                    r4:Organization[] result = from r4:Organization entry in organizations
                        where entry["name"] == queriedValue
                        select entry;
                    filteredList.push(...result);
                }
            }

            if searchParam == "address-city" {

                foreach var queriedValue in value {
                    r4:Organization[] result = [];
                    foreach r4:Organization entry in organizations {
                        r4:Address[]? addressList = entry.address;
                        if addressList != () {
                            r4:Address[] filteredAddressList = addressList.filter(address => address.city == queriedValue);
                            if filteredAddressList.length() > 0 {
                                result.push(entry);
                            }
                        }
                    }
                    filteredList.push(...result);
                }
            }
            if filteredList.length() > 20 {
                break;
            }
            organizations = filteredList;
        }
    }
    return organizations;
}

public isolated function getAll() returns r4:Organization[] {
    lock {
        return data.clone().toArray();
    }
}

public isolated function delete(string id) {
    lock {
        map<r4:Organization> clone = data.clone();
        _ = clone.hasKey(id) ? clone.remove(id) : "";
        data = clone.clone();
    }
}
