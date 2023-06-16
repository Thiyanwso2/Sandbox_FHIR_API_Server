import health.fhir.r4;
import ballerina/task;
import ballerina/io;
import ballerina/time;

// Creates a job to be executed by the scheduler.
class Job {

    *task:Job;
    string jobIdentifier;

    // Executes this function when the scheduled trigger fires.
    public function execute() {
        io:println("Running...");
        r4:Organization[] organizations = getAll();

        r4:Organization[] result = from r4:Organization entry in organizations
            where self.calcDifference(<string>entry["meta"]["lastUpdated"]) >= 7200d
            select entry;

        io:println(result.forEach(function(r4:Organization p) {
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
}
