import ballerina/io;
import ballerina/mysql;
import ballerina/http;
import ballerina/runtime;
import ballerina/observe;
import ballerina/log;


// type Student is created to store details of a student
documentation {
  `Student` is a user defined record type in Ballerina program. Used to represent a student entity
}

type Student record {
    int id,
    int age,
    string name,
    int mobNo,
    string address,
};
//End point for marks details client
endpoint http:Client marksService {
    url: " http://localhost:9191"
};

//Endpoint for mysql client
endpoint mysql:Client testDB {
    host: "localhost",
    port: 3306,
    name: "testdb",
    username: "root",
    password: "",
    poolOptions: { maximumPoolSize: 5 },
    dbOptions: { useSSL: false }
};

//This service listener
endpoint http:Listener listener1 {
    port: 9292
};


// Service for the Student data service
@http:ServiceConfig {
    basePath: "/records"
}
service<http:Service> StudentData bind listener1 {

    int errors = 0;
    int req_count = 0;

    @http:ResourceConfig {
        methods: ["POST"],
        path: "/addStudent"
    }
    // addStudents service used to add student records to the system
    addStudents(endpoint httpConnection, http:Request request) {
        // Initialize an empty http response message
        req_count++;
        http:Response response;
        Student stuData;


        var payloadJson = check request.getJsonPayload();
        // Accepting the Json payload sent from a request
        stuData = check <Student>payloadJson;
        //Converting the payload to Student type


        // Calling the function insertData to update database
        // int spanId3 = check observe:startSpan("Update database span", tags = mp);
        json ret = insertData(stuData.name, stuData.age, stuData.mobNo,
            stuData.address);

        // Send the response back to the client with the returned json value from insertData function
        response.setJsonPayload(ret);
        _ = httpConnection->respond(response);

        _ = observe:addTagToSpan(spanId = -1, "tot_requests", <string>req_count);
        _ = observe:addTagToSpan(spanId = -1, "error_counts", <string>errors);
    }

    @http:ResourceConfig {
        methods: ["POST"],
        path: "/viewAll"
    }
    //viewStudent service to get all the students details and send to the requested user
    viewStudents(endpoint httpConnection, http:Request request) {
        req_count++;
        int chSpanId = check observe:startSpan("Check span 1");
        http:Response response;
        json status = {};

        int spanId2 = observe:startRootSpan("Database call span");
        var selectRet = testDB->select("SELECT * FROM student", Student, loadToMemory = true);
        //sending a request to mysql endpoint and getting a response with required data table
        _ = observe:finishSpan(spanId2);

        table<Student> dt;
        // a table is declared with Student as its type
        //match operator used to check if the response returned value with one of the types below
        match selectRet {
            table tableReturned => dt = tableReturned;
            error e => io:println("Select data from student table failed: "
                    + e.message);
        }

        //student details displayed on server side for reference purpose
        io:println("Iterating data first time:");
        foreach row in dt {
            io:println("Student:" + row.id + "|" + row.name + "|" + row.age);
        }

        // table is converted to json
        var jsonConversionRet = <json>dt;
        match jsonConversionRet {
            json jsonRes => {
                status = jsonRes;
            }
            error e => {
                status = { "Status": "Data Not available", "Error": e.message };
            }
        }
        //Sending back the converted json data to the request made to this service
        response.setJsonPayload(untaint status);
        _ = httpConnection->respond(response);

        _ = observe:finishSpan(chSpanId);
        _ = observe:addTagToSpan(spanId = -1, "tot_requests", <string>req_count);
        _ = observe:addTagToSpan(spanId = -1, "error_counts", <string>errors);

    }

    @http:ResourceConfig {
        methods: ["GET"],
        path: "/testError"
    }
    //viewStudent service to get all the students details and send to the requested user
    testError(endpoint httpConnection, http:Request request) {
        req_count++;
        http:Response response;

        errors++;
        io:println(errors);
        _ = observe:addTagToSpan(spanId = -1, "error_counts", <string>errors);
        _ = observe:addTagToSpan(spanId = -1, "tot_requests", <string>req_count);
        log:printError("error test");
        response.setTextPayload("Test Error made");
        _ = httpConnection->respond(response);
    }

    @http:ResourceConfig {
        methods: ["GET"],
        path: "/deleteStu/{stuId}"
    }
    //deleteStudents service for deleteing a student using id
    deleteStudent(endpoint httpConnection, http:Request request, int stuId) {
        req_count++;
        http:Response response;
        json status = {};

        //calling deleteData function with id as parameter and get a return json object
        var ret = deleteData(stuId);
        io:println(ret);
        //Pass the obtained json object to the request
        response.setJsonPayload(ret);
        _ = httpConnection->respond(response);
        _ = observe:addTagToSpan(spanId = -1, "tot_requests", <string>req_count);
        _ = observe:addTagToSpan(spanId = -1, "error_counts", <string>errors);
    }

    @http:ResourceConfig {
        methods: ["GET"],
        path: "/getMarks/{stuId}"
    }
    // get marks resource for obtaining marks of a particular student
    getMarks(endpoint httpConnection, http:Request request, int stuId) {
        req_count++;
        http:Response response;
        json result;

        int firstsp = check observe:startSpan("First span");
        //Self defined span for observability purposes
        var requ = marksService->get("/marks/getMarks/" + untaint stuId);
        //Request made for obtaining marks of the student with the respective stuId to marks Service.
        match requ {
            http:Response response2 => {
                var msg = response2.getJsonPayload();
                // Gets the Json object
                match msg {
                    json js => {
                        result = js;
                    }

                    error er => {
                        log:printError(er.message, err = er);
                    }                }
            }
            error err => {
                log:printError(err.message, err = err);
                // Print any error caused
            }
        }
        _ = observe:finishSpan(firstsp);   // Stopping the previously started span.

            response.setJsonPayload(untaint result);    //Sending the Json to the client.
        _ = httpConnection->respond(response);

        _ = observe:addTagToSpan(spanId = -1, "tot_requests", <string>req_count);
        _ = observe:addTagToSpan(spanId = -1, "error_counts", <string>errors);
    }
}

// Function to insert values to database


documentation {
  `insertData` is a function to add data to student records database
   P{{name}} This is the name of the student to be added.
   P{{age}} Student age
   P{{mobNo}} Student mobile number
   P{{address}} Student address.
   R{{}} This function returns a json object. If data is added it returns json containing a status and id of student added.
            If data is not added , it returns the json containing a status and error message.
  }


public function insertData(string name, int age, int mobNo, string address) returns (json) {
    json updateStatus;
    int uid;
    string sqlString =
    "INSERT INTO student (name, age, mobNo, address) VALUES (?,?,?,?)";
    // Insert data to SQL database by invoking update action
    //  int spanId = check observe:startSpan("update Database");
    var ret = testDB->update(sqlString, name, age, mobNo, address);

    // Use match operator to check the validity of the result from database
    match ret {
        int updateRowCount => {
         var result = getId(untaint mobNo);
            // Getting info of the student added
            match result {
                table dt => {
                    while (dt.hasNext()) {
                        var ret2 = <Student>dt.getNext();
                        match ret2 {
                            Student stu => uid = stu.id;     // Getting the  id of the latest student added
                            error e => io:println("Error in get employee from table: "
                                    + e.message);
                        }
                    }
                }
                error er => {
                    io:println(er.message);
                }
            }

            updateStatus = { "Status": "Data Inserted Successfully", "id": uid };
        }
        error err => {
            updateStatus = { "Status": "Data Not Inserted", "Error": err.message };
        }
    }
    return updateStatus;
}


documentation {
  `deleteData` is a function to delete a student's data from student records database
    P{{stuId}} This is the id of the student to be deleted.
    R{{}} This function returns a json object. If data is deleted it returns json containing a status.
            If data is not deleted , it returns the json containing a status and error message.
}

// Function to delete a student record with id
public function deleteData(int stuId) returns (json) {
    json status = {};
    string sqlString = "DELETE FROM student WHERE id = ?";

    // Delete existing data by invoking update action
    var ret = testDB->update(sqlString, stuId);
    io:println(ret);
    match ret {
        int updateRowCount => {
            if (updateRowCount != 1){
                status = { "Status": "Data Not Found" };
            }
            else {
                status = { "Status": "Data Deleted Successfully" };
            }
        }
        error err => {
            status = { "Status": "Data Not Deleted", "Error": err.message };
            io:println(err.message);
        }
    }
    return status;
}

documentation {
  `getId` is a function to get the Id of the student added in latest.
   P{{mobNo}} This is the mobile number of the student added which is passed as parameter to build up the query.
   R{{}} This function returns either a table which has only one row of the student details or an error.
}

// Function to get the generated Id of the student recently added
public function getId(int mobNo) returns (table|error) {
    //Select data from database by invoking select action
    var ret2 = testDB->select("Select * FROM student WHERE mobNo = " + mobNo, Student, loadToMemory = true);
    table<Student> dt;
    match ret2 {
        table tableReturned => dt = tableReturned;
        error e => io:println("Select data from student table failed: "
                + e.message);
    }
    return dt;
}



