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

isolated map<r4:Observation> data = {};

isolated function addJson(json observation) returns r4:FHIRError|string {
    lock {
        r4:Observation|error parsedResource = r4:parse(observation.clone(), r4:Observation).ensureType();

        if parsedResource is error {
            return r4:createFHIRError("Can't parse the resource", r4:CODE_SEVERITY_ERROR,
            r4:PROCESSING_NOT_FOUND,
            httpStatusCode = http:STATUS_BAD_REQUEST);
        } else {
            return add(parsedResource);
        }

    }
}

public isolated function add(r4:Observation observation) returns r4:FHIRError|string {
    lock {
        int|random:Error randomInteger = random:createIntInRange(100000, 1000000);

        if randomInteger is random:Error {
            return r4:createFHIRError("Something went wrong while processing the request",
                r4:ERROR,
                r4:PROCESSING);
        }
        if data.length() >= 500 {
            return r4:createFHIRError("Amount of requests have exceeded the limit. Please try again later",
                r4:ERROR,
                r4:TRANSIENT_THROTTLED);
        }

        string randomId = randomInteger.toBalString();
        observation.id = randomId;
        observation.meta.lastUpdated = time:utcToString(time:utcNow());
        data[randomId] = observation.clone();
        return <string>observation.id;
    }
}

isolated function get(string id) returns r4:FHIRError|r4:Observation {
    r4:Observation clone = {code: {}, status: "preliminary"};
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

public isolated function search(map<string[]> searchParameters) returns r4:FHIRError|r4:Observation[] {

    // Define the search params here supported by Sandbox
    string[] supportedParams = ["_id", "status", "subject"];

    //Create cloned copy of the in-memory observations map to an array 
    r4:Observation[] observations = [];
    lock {
        observations = data.clone().toArray();
    }

    // If In-memory patients map is empty skip the search process
    if observations.length() == 0 {
        return observations;
    }

    int offset = 0;
    if (searchParameters.hasKey("_offset")) {
        int|error fromString = langint:fromString(searchParameters.get("_offset")[0]);
        if fromString is int {
            offset = fromString;
        }
    }

    int count = 20;
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
        if observations.length() > offset + count {
            return observations.slice(offset, offset + count);
        } else {
            return observations.slice(offset);
        }
    }

    // If In-memory observations map is empty skip the search process
    if observations.length() == 0 {
        return observations;
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
            r4:Observation[] filteredList = [];

            if searchParam == "_id" {
                string param = "id";

                foreach var queriedValue in value {
                    r4:Observation[] result = from r4:Observation entry in observations
                        where entry[param] == queriedValue
                        select entry;
                    filteredList.push(...result);
                }
            }

            if searchParam == "status" {

                foreach var queriedValue in value {
                    r4:Observation[] result = from r4:Observation entry in observations
                        where entry["status"] == queriedValue
                        select entry;
                    filteredList.push(...result);
                }
            }

            if searchParam == "subject" {

                foreach var queriedValue in value {
                    r4:Observation[] result = [];
                    foreach r4:Observation entry in observations {

                        r4:Reference? subject = entry.subject;
                        if subject != () {
                            if subject.reference == queriedValue {
                                result.push(entry);
                            }

                        }
                    }
                    filteredList.push(...result);
                }
            }
            observations = filteredList;
            if observations.length() > offset + count {
                return observations.slice(offset, offset + count);
            }
        }
    }
    if observations.length() > offset {
        return observations.slice(offset);
    } else {
        return [];
    }
}

public isolated function getAll() returns r4:Observation[] {
    lock {
        return data.clone().toArray();
    }
}

public isolated function delete(string id) {
    lock {
        map<r4:Observation> clone = data.clone();
        _ = clone.hasKey(id) ? clone.remove(id) : "";
        data = clone.clone();
    }
}
