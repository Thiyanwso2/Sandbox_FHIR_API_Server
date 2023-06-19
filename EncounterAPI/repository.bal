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
import ballerina/lang.'int as langint;

isolated map<r4:Encounter> data = {};

isolated function addJson(json encounter) returns r4:FHIRError|string {
    lock {
        r4:Encounter|error parsedResource = r4:parse(encounter.clone(), r4:Encounter).ensureType();

        if parsedResource is error {
            return r4:createFHIRError("Can't parse the resource", r4:CODE_SEVERITY_ERROR,
            r4:PROCESSING_NOT_FOUND,
            httpStatusCode = http:STATUS_BAD_REQUEST);
        } else {
            return add(parsedResource);
        }

    }
}

public isolated function add(r4:Encounter encounter) returns r4:FHIRError|string {
    lock {
        int|random:Error randomInteger = random:createIntInRange(MIN_RANDOM_INT, MAX_RANDOM_INT);

        if randomInteger is random:Error {
            return r4:createFHIRError("Something went wrong while processing the request",
                r4:ERROR,
                r4:PROCESSING);
        }
        if data.length() >= MAX_DATA_ITEMS {
            return r4:createFHIRError("Amount of requests have exceeded the limit. Please try again later",
                r4:ERROR,
                r4:TRANSIENT_THROTTLED);
        }

        string randomId = randomInteger.toBalString();
        encounter.id = randomId;
        encounter.meta.lastUpdated = time:utcToString(time:utcNow());
        data[randomId] = encounter.clone();
        return <string>encounter.id;
    }
}

isolated function get(string id) returns r4:FHIRError|r4:Encounter {
    r4:Encounter clone = {'class: {}, status: "in-progress"};
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

public isolated function search(map<string[]> searchParameters) returns r4:FHIRError|r4:Encounter[] {

    // Define the search params here supported by Sandbox
    string[] supportedParams = ["_id", "status", "class"];

    //Create cloned copy of the in-memory encounters map to an array 
    r4:Encounter[] encounters = [];
    lock {
        encounters = data.clone().toArray();
    }

    // If In-memory patients map is empty skip the search process
    if encounters.length() == 0 {
        return encounters;
    }

    int offset = DEFAULT_OFFSET_VALUE;
    if (searchParameters.hasKey("_offset")) {
        int|error fromString = langint:fromString(searchParameters.get("_offset")[0]);
        if fromString is int {
            offset = fromString;
        }
    }

    int count = DEFAULT_COUNT_VALUE;
    if (searchParameters.hasKey("_count")) {
        int|error fromString = langint:fromString(searchParameters.get("_count")[0]);
        if fromString is int {
            count = fromString;
        }
    }

    //Check whether there any search parameters in the requested search parameter list,
    //other than _count & _offset
    string[] filteredParams = searchParameters.keys().filter(k => k != "_count").filter(k => k != "_offset");

    // If no search parameters other than _count & _offset skip the search process
    if filteredParams.length() == 0 {
        // Apply offset and count here
        if encounters.length() > offset + count {
            return encounters.slice(offset, offset + count);
        } else {
            return encounters.slice(offset);
        }
    }

    // If In-memory encounters map is empty skip the search process
    if encounters.length() == 0 {
        return encounters;
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
            r4:Encounter[] filteredList = [];

            if searchParam == "_id" {
                string param = "id";

                foreach var queriedValue in value {
                    r4:Encounter[] result = from r4:Encounter entry in encounters
                        where entry[param] == queriedValue
                        select entry;
                    filteredList.push(...result);
                }
            }

            if searchParam == "status" {

                foreach var queriedValue in value {
                    r4:Encounter[] result = from r4:Encounter entry in encounters
                        where entry["status"] == queriedValue
                        select entry;
                    filteredList.push(...result);
                }
            }

            if searchParam == "class" {
                foreach var queriedValue in value {
                    r4:Encounter[] result = from r4:Encounter entry in encounters
                        where entry["class"].code == queriedValue
                        select entry;
                    filteredList.push(...result);
                }
            }
            encounters = filteredList;
        }
    }
    if encounters.length() > offset {
        return encounters.slice(offset);
    } else {
        return [];
    }
}

public isolated function getAll() returns r4:Encounter[] {
    lock {
        return data.clone().toArray();
    }
}

public isolated function delete(string id) {
    lock {
        map<r4:Encounter> clone = data.clone();
        _ = clone.hasKey(id) ? clone.remove(id) : "";
        data = clone.clone();
    }
}
