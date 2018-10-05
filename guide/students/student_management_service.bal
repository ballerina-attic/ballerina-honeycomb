// Copyright (c) 2018 WSO2 Inc. (http://www.wso2.org) All Rights Reserved.
//
// WSO2 Inc. licenses this file to you under the Apache License,
// Version 2.0 (the "License"); you may not use this file except
// in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing,
// software distributed under the License is distributed on an
// "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
// KIND, either express or implied.  See the License for the
// specific language governing permissions and limitations
// under the License.

import ballerina/http;
import ballerina/io;
import ballerina/log;
import ballerina/mysql;
import ballerina/observe;
import ballerina/runtime;

// Type Student is created to store details of a student.
type Student record {
    int id;
    int age;
    string name;
    int mobNo;
    string address;
};

// End point for marks details client.
endpoint http:Client marksServiceEP {
    url: " http://localhost:9191"
};

// Endpoint for mysql client.
public endpoint mysql:Client databaseEP {
    host: "localhost",
    port: 3306,
    name: "testdb",
    username: "root",
    password: "",
    poolOptions: { maximumPoolSize: 5 },
    dbOptions: { useSSL: false }
};

// This service listener.
endpoint http:Listener studentServiceListener {
    port: 9292
};

// Student data service.
@http:ServiceConfig {
    basePath: "/records"
}
service<http:Service> StudentData bind studentServiceListener {

    int errors = 0;
    int requestCounts = 0;

    @http:ResourceConfig {
        methods: ["POST"],
        path: "/addStudent"
    }
    // Add Students resource used to add student records to the system.
    addStudents(endpoint httpConnection, http:Request request) {
        // Initialize an empty http response message.
        requestCounts++;
        http:Response response;

        // Accepting the Json payload sent from a request.
        json payloadJson = check request.getJsonPayload();

        //Converting the payload to Student type.
        Student studentDetails = check <Student>payloadJson;

        // Calling the function insertData to update database.
        json returnValue = insertData (studentDetails.name, studentDetails.age, studentDetails.mobNo, studentDetails.address);

        // Send the response back to the client with the returned json value from insertData function.
        response.setJsonPayload(returnValue);
        _ = httpConnection->respond(response) but { error e => log:printError("Error sending response", err = e)};

        // The below function adds tags that are to be passed as metrics in the traces. These tags are added to the default ootb system span.
        _ = observe:addTagToSpan("tot_requests", <string>requestCounts);
        _ = observe:addTagToSpan("error_counts", <string>errors);
    }

    @http:ResourceConfig {
        methods: ["POST"],
        path: "/viewAll"
    }
    // View students resource is to get all the students details and send to the requested user.
    viewStudents(endpoint httpConnection, http:Request request) {
        requestCounts++;
        int childSpanId = check observe:startSpan("Obtain details span");
        http:Response response;
        json status = {};

        int spanId2 = observe:startRootSpan("Database call span");
        var returnValue = databaseEP->select("SELECT * FROM student", Student, loadToMemory = true);
        //Sending a request to mysql endpoint and getting a response with required data table.
        _ = observe:finishSpan(spanId2);
        // A table is declared with Student as its type.
        table<Student> dataTable;

        // Match operator used to check if the response returned value with one of the types below.
        match returnValue {
            table tableReturned => dataTable = tableReturned;
            error e => io:println("Select data from student table failed: "
                    + e.message);
        }

        // Student details displayed on server side for reference purpose.
        foreach row in dataTable {
            io:println("Student:" + row.id + "|" + row.name + "|" + row.age);
        }

        // Table is converted to json.
        var jsonConversionValue = <json>dataTable;
        match jsonConversionValue {
            json jsonResult => {
                status = jsonResult;
            }
            error e => {
                status = { "Status": "Data Not available", "Error": e.message };
            }
        }
        // Sending back the converted json data to the request made to this service.
        response.setJsonPayload(untaint status);
        _ = httpConnection->respond(response) but { error e => log:printError("Error sending response", err = e) };

        _ = observe:finishSpan(childSpanId);
        // The below function adds tags that are to be passed as metrics in the traces. These tags are added to the default ootb system span.
        _ = observe:addTagToSpan("tot_requests", <string>requestCounts);
        _ = observe:addTagToSpan("error_counts", <string>errors);

    }

    @http:ResourceConfig {
        methods: ["GET"],
        path: "/testError"
    }
    // Test Error resource to make a mock error.
    testError(endpoint httpConnection, http:Request request) {
        requestCounts++;
        http:Response response;

        errors++;
        io:println(errors);
        // The below function adds tags that are to be passed as metrics in the traces. These tags are added to the default ootb system span.
        _ = observe:addTagToSpan("error_counts", <string>errors);
        _ = observe:addTagToSpan("tot_requests", <string>requestCounts);
        log:printError("error test");
        response.setTextPayload("Test Error made");
        _ = httpConnection->respond(response) but { error e => log:printError("Error sending response", err = e) };
    }

    @http:ResourceConfig {
        methods: ["GET"],
        path: "/deleteStu/{stuId}"
    }
    // Delete Students resource for deleteing a student using id.
    deleteStudent(endpoint httpConnection, http:Request request, int stuId) {
        requestCounts++;
        http:Response response;
        json status = {};

        // Calling deleteData function with id as parameter and get a return json object.
        var returnValue = deleteData(stuId);
        io:println(returnValue);

        // Pass the obtained json object to the request.
        response.setJsonPayload(returnValue);
        _ = httpConnection->respond(response) but { error e => log:printError("Error sending response", err = e) };
        // The below function adds tags that are to be passed as metrics in the traces. These tags are added to the default ootb system span.
        _ = observe:addTagToSpan("tot_requests", <string>requestCounts);
        _ = observe:addTagToSpan("error_counts", <string>errors);
    }

    @http:ResourceConfig {
        methods: ["GET"],
        path: "/getMarks/{stuId}"
    }
    // Get marks resource for obtaining marks of a particular student.
    getMarks(endpoint httpConnection, http:Request request, int stuId) {
        requestCounts++;
        http:Response response;
        json result;

        // Self defined span for observability purposes.
        int firstSpan = check observe:startSpan("First span");
        // Request made for obtaining marks of the student with the respective stuId to marks Service.
        var requestReturn = marksServiceEP->get("/marks/getMarks/" + untaint stuId);

        match requestReturn{
            http:Response response2 => {
                var msg = response2.getJsonPayload();
                // Gets the Json object.
                match msg {
                    json jsonObj => {
                        result = jsonObj;
                    }

                    error er => {
                        log:printError(er.message, err = er);
                    }
                }
            }
            error err => {
                log:printError(err.message, err = err);
            }
        }
        // Stopping the previously started span.
        _ = observe:finishSpan(firstSpan);
        //Sending the Json to the client.
        response.setJsonPayload(untaint result);
        _ = httpConnection->respond(response) but { error e => log:printError("Error sending response", err = e) };

        //  The below function adds tags that are to be passed as metrics in the traces. These tags are added to the default ootb system span.
        _ = observe:addTagToSpan("tot_requests", <string>requestCounts);
        _ = observe:addTagToSpan("error_counts", <string>errors);
    }
}

// Function to insert values to database.
  # `insertData()` is a function to add data to student records database.
  #
  # + name - This is the name of the student to be added.
  # + age -Student age.
  # + mobNo -Student mobile number.
  # + address - Student address.
  # + return - This function returns a json object. If data is added it returns json containing a status and id of student added.
  #          If data is not added , it returns the json containing a status and error message.

public function insertData(string name, int age, int mobNo, string address) returns (json) {
    json updateStatus;
    int uid;
    string sqlString = "INSERT INTO student (name, age, mobNo, address) VALUES (?,?,?,?)";
    // Insert data to SQL database by invoking update action.
    var returnValue = databaseEP->update(sqlString, name, age, mobNo, address);

    // Use match operator to check the validity of the result from database.
    match returnValue {
        int updateRowCount => {
         var result = getId(untaint mobNo);
            // Getting info of the student added
            match result {
                table dataTable => {
                    while (dataTable.hasNext()) {
                        var returnValue2 = <Student>dataTable.getNext();
                        match returnValue2 {
                            // Getting the  id of the latest student added.
                            Student student => uid = student.id;
                            error e => io:println("Error in get employee from table: " + e.message);
                        }
                    }
                }
                error er => {
                    log:printError(er.message,err = er);
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

// Function to delete student data from database.
  # `deleteData()` is a function to delete a student's data from student records database.
  #
  # + stuId - This is the id of the student to be deleted.
  # + return -This function returns a json object. If data is deleted it returns json containing a status.
  #           If data is not deleted , it returns the json containing a status and error message.

public function deleteData(int stuId) returns (json) {
    json status = {};
    string sqlString = "DELETE FROM student WHERE id = ?";

    // Delete existing data by invoking update action.
    var returnValue = databaseEP->update(sqlString, stuId);
    io:println(returnValue);
    match returnValue {
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
            log:printError(err.message,err = err);
        }
    }
    return status;
}

# `getId()` is a function to get the Id of the student added in latest.
#
# + mobNo - This is the mobile number of the student added which is passed as parameter to build up the query.
# + return -This function returns either a table which has only one row of the student details or an error.

// Function to get the generated Id of the student recently added.
public function getId(int mobNo) returns table|error {
    //Select data from database by invoking select action.
    var returnValue = databaseEP->select("Select * FROM student WHERE mobNo = " + mobNo, Student, loadToMemory = true);
    table<Student> dataTable;
    match returnValue {
        table tableReturned => dataTable = tableReturned;
        error e => io:println("Select data from student table failed: " + e.message);
    }
    return dataTable;
}



