import health.fhir.r4;
import ballerina/task;
import ballerina/io;
import ballerina/time;
import ballerina/log;

// Creates a job to be executed by the scheduler.
class Job {

    *task:Job;
    string jobIdentifier;

    // Executes this function when the scheduled trigger fires.
    public function execute() {
        r4:Patient[] patients = getAll();

        r4:Patient[] result = from r4:Patient entry in patients
            where self.calcDifference(<string>entry["meta"]["lastUpdated"]) >= 7200d
            select entry;

        io:println(result.forEach(function(r4:Patient p) {
            delete(<string>p.id);
            io:println(p);
        }));

    }

    isolated function calcDifference(string lastUpdated) returns decimal {

        time:Utc|error utc = time:utcFromString(lastUpdated);

        if utc is error {
            return 600d;
        } else {
            time:Utc now = time:utcNow();
            io:println("Now: " + time:utcToString(now));
            time:Seconds seconds = time:utcDiffSeconds(now, utc);
            io:println("Seconds: " + seconds.toBalString());
            return seconds;
        }
    }

    isolated function init(string jobIdentifier) {
        self.jobIdentifier = jobIdentifier;
    }
}

function init() returns error? {

    _ = check task:scheduleJobRecurByFrequency(new Job("Data clean up job"), 600);

    // This init method will read some initial patient resource from a file and initialise the internal map

    log:printDebug("Reading the patient data from resources/data.json and initialising the in memory patients map");

    json[]|error patientsArray = <json[]>check io:fileReadJson("resources/data.json");

    if patientsArray is error {
        log:printError("Something went wrong", patientsArray);

    } else {
        foreach json res in patientsArray {
            _ = check addJson(res);
        }
    }
}
