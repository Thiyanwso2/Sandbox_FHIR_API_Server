import ballerina/io;

isolated function loadData(string pathToJSON) returns json[]|error {
    json[]|error data = <json[]>check io:fileReadJson(pathToJSON);
    return data;
}

isolated function writeData(string pathToJSON, json[] body) returns error? {
    check io:fileWriteJson(pathToJSON, body);
}
