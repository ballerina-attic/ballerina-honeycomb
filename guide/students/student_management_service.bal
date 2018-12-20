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

// Endpoint for marks details client.
http:Client marksServiceEP = new("http://localhost:9191");

// Endpoint for MySQL client.
mysql:Client studentDB = new({
        host: "localhost",
        port: 3306,
        name: "testdb",
        username: "root",
        password: "",
        dbOptions: { useSSL: false }
    });

// Port listener for the student service.
listener http:Listener studentServiceListener = new(9292);

// Service configuration for student data service.
@http:ServiceConfig {
    basePath: "/records"
}
service studentData on studentServiceListener {
    int errors = 0;
    int requestCounts = 0;

    // Resource configuration for adding students to the system.
    @http:ResourceConfig {
        methods: ["POST"],
        path: "/addStudent"
    }
    // Add Students resource used to add student records to the system.
    resource function addStudents(http:Caller caller, http:Request request) {
        // Initialize an empty HTTP response message.
        studentData.requestCounts += 1;
        http:Response response = new;

        // Accepting the JSON payload sent from a request.
        json|error payloadJson = request.getJsonPayload();

        if (payloadJson is json) {
            //Converting the payload to Student type.
            Student|error studentDetails = Student.convert(payloadJson);

            if (studentDetails is Student) {
                io:println(studentDetails);
                // Calling the function insertData to update database.
                json returnValue = insertData(untaint studentDetails.name, untaint studentDetails.age, untaint studentDetails.mobNo, untaint studentDetails.address);
                response.setJsonPayload(untaint returnValue);
            } else {
                log:printError("Error in converting JSON payload to student type", err = studentDetails);
            }
        } else {
            log:printError("Error obtaining the JSON payload", err = payloadJson);
        }
        // The below function adds tags that are to be passed as metrics in the traces. These tags are added to the default system span.
        _ = observe:addTagToSpan("tot_requests", <string>studentData.requestCounts);
        _ = observe:addTagToSpan("error_counts", <string>studentData.errors);

        // Send the response back to the client with the returned JSON value from insertData function.
        var result = caller->respond(response);
        if (result is error) {
            // Log the error for the service maintainers.
            log:printError("Error sending response", err = result);
        }
    }

    // Resource configuration for viewing all the student's details in the system.
    @http:ResourceConfig {
        methods: ["POST"],
        path: "/viewAll"
    }
    // View students resource is to get all the students details and send to the requested user.
    resource function viewStudents(http:Caller caller, http:Request request) {
        studentData.requestCounts += 1;
        int|error childSpanId = observe:startSpan("Obtain details span");
        http:Response response = new;
        json status = {};
        int spanId2 = observe:startRootSpan("Database call span");

        //Sending a request to MySQL endpoint and getting a response with required data table.
        var returnValue = studentDB->select("SELECT * FROM student", Student, loadToMemory = true);
        _ = observe:finishSpan(spanId2);

        // A table is declared with Student as its type.
        table<Student> dataTable = table{};

        if (returnValue is error) {
           log:printError("Error in fetching students data from the database", err = returnValue);
        } else {
            dataTable = returnValue;
        }

        // Student details displayed on server side for reference purpose.
        foreach var row in dataTable {
            io:println("Student:" + row.id + "|" + row.name + "|" + row.age);
        }

        // Table is converted to JSON.
        var jsonConversionValue = json.convert(dataTable);
        if (jsonConversionValue is error) {
            log:printError("Error in converting the data table from database to JSON", err = jsonConversionValue);
        } else {
            status = jsonConversionValue;
        }
        // Sending back the converted JSON data to the request made to this service.
        response.setJsonPayload(untaint status);
        var result = caller->respond(response);
        if (result is error) {
            log:printError("Error in sending response", err = result);
        }

        if (childSpanId is int) {
            _ = observe:finishSpan(childSpanId);
        } else {
            log:printError("Error attaching span ", err = childSpanId);
        }
        // The below function adds tags that are to be passed as metrics in the traces. These tags are added to the default system span.
        _ = observe:addTagToSpan("tot_requests", <string>studentData.requestCounts);
        _ = observe:addTagToSpan("error_counts", <string>studentData.errors);
    }

    // Resource configuration for making a mock error to the system.
    @http:ResourceConfig {
        methods: ["GET"],
        path: "/testError"
    }
    // Test Error resource to make a mock error.
    resource function testError(http:Caller caller, http:Request request) {
        studentData.requestCounts += 1;
        http:Response response = new;
        studentData.errors += 1;
        io:println(studentData.errors);
        // The below function adds tags that are to be passed as metrics in the traces. These tags are added to the default system span.
        _ = observe:addTagToSpan("tot_requests", <string>studentData.requestCounts);
        _ = observe:addTagToSpan("error_counts", <string>studentData.errors);
        log:printError("error test");
        response.setTextPayload("Test Error made");
        var result = caller->respond(response);
        if (result is error) {
            log:printError("Error sending response", err = result);
        }
    }

    // Resource configuration for deleting a students detail's from the system.
    @http:ResourceConfig {
        methods: ["GET"],
        path: "/deleteStu/{studentId}"
    }
    // Delete Students resource for deleteing a student using id.
    resource function deleteStudent(http:Caller caller, http:Request request, int studentId) {
        studentData.requestCounts += 1;
        http:Response response = new;
        json status = {};

        // Calling deleteData function with id as parameter and get a return json object.
        var returnValue = deleteData(studentId);
        io:println(returnValue);

        // Pass the obtained JSON object to the request.
        response.setJsonPayload(returnValue);
        var result = caller->respond(response);
        if (result is error) {
            log:printError("Error sending response", err = result);
        }
        // The below function adds tags that are to be passed as metrics in the traces. These tags are added to the default system span.
        _ = observe:addTagToSpan("tot_requests", <string>studentData.requestCounts);
        _ = observe:addTagToSpan("error_counts", <string>studentData.errors);
    }

    // Resource configuration for getting marksa of a particular student.
    @http:ResourceConfig {
        methods: ["GET"],
        path: "/getMarks/{studentId}"
    }
    // Get marks resource for obtaining marks of a particular student.
    resource function getMarks(http:Caller caller, http:Request request, int studentId) {
        studentData.requestCounts += 1;
        http:Response response = new;
        json result = {};

        // Self defined span for observability purposes.
        int|error firstSpan = observe:startSpan("First span");
        // Request made for obtaining marks of the student with the respective studentId to marks Service.
        var requestReturn = marksServiceEP->get("/marks/getMarks/" + untaint studentId);
        if (requestReturn is error) {
            log:printError("Error in fetching marks from the marks system", err = requestReturn);
        } else {
            var msg = requestReturn.getJsonPayload();
            if (msg is error) {
                log:printError("Error in extracting JSON from the response", err = msg);
            } else {
                result = msg;
            }
        }

        // Stopping the previously started span.
        if (firstSpan is int) {
            _ = observe:finishSpan(firstSpan);
        } else {
            log:printError("Error attaching span ", err = firstSpan);
        }
        //Sending the JSON to the client.
        response.setJsonPayload(untaint result);
        var resResult = caller->respond(response);
        if (resResult is error) {
            log:printError("Error sending response", err = resResult);
        }
        //  The below function adds tags that are to be passed as metrics in the traces. These tags are added to the default system span.
        _ = observe:addTagToSpan("tot_requests", <string>studentData.requestCounts);
        _ = observe:addTagToSpan("error_counts", <string>studentData.errors);
    }
}

// Function to insert values to database.
# `insertData()` is a function to add data to student records database.
#
# + name - This is the name of the student to be added.
# + age -Student age.
# + mobNo -Student mobile number.
# + address - Student address.
# + return - This function returns a JSON object. If data is added it returns JSON containing a status and id of student
#            added. If data is not added , it returns the JSON containing a status and error message.

public function insertData(string name, int age, int mobNo, string address) returns (json) {
    json updateStatus = { "Status": "Data Inserted " };
    int uniqueId = 0;
    string sqlString = "INSERT INTO student (name, age, mobNo, address) VALUES (?,?,?,?)";

    // Insert data to SQL database by invoking update action.
    var returnValue = studentDB->update(sqlString, name, age, mobNo, address);
    if (returnValue is int) {
        table<Student> result = getId(untaint mobNo);
        while (result.hasNext()) {
            var returnValue2 = result.getNext();
            if (returnValue2 is Student) {
                uniqueId = returnValue2.id;
            } else {
                log:printError("Error in obtaining student ID from the database", err = returnValue2);
            }
        }

        if (uniqueId != 0) {
            updateStatus = { "Status": "Data Inserted Successfully", "id": uniqueId };
        } else {
            updateStatus = { "Status": "Data Not inserted" };
        }
    } else {
        log:printError("Error in adding the data to the database", err = returnValue);
    }
    return updateStatus;
}

# Function to delete student data from database.
# `deleteData()` is a function to delete a student's data from student records database.
#
# + studentId - This is the id of the student to be deleted.
# + return -This function returns a JSON object. If data is deleted it returns JSON containing a status.
#           If data is not deleted , it returns the JSON containing a status and error message.

public function deleteData(int studentId) returns (json) {
    json status = {};
    string sqlString = "DELETE FROM student WHERE id = ?";

    // Delete existing data by invoking update action.
    var returnValue = studentDB->update(sqlString, studentId);
    io:println(returnValue);

    if (returnValue is int) {
        if (returnValue != 1) {
            status = { "Status": "Data Not Found" };
        } else {
            status = { "Status": "Data Deleted Successfully" };
        }

    } else {
        log:printError("Error in removing data from the database", err = returnValue);
        status = { "Status": "Data Not Deleted" };
    }
    return status;
}

# `getId()` is a function to get the Id of the student added in latest.
#
# + mobNo - This is the mobile number of the student added which is passed as parameter to build up the query.
# + return -This function returns a table with Student type.

// Function to get the generated Id of the student recently added.
public function getId(int mobNo) returns table<Student> {
    //Select data from database by invoking select action.

    string sqlString = "SELECT * FROM student WHERE mobNo = ?";
    // Retrieve student data by invoking select remote function defined in ballerina sql client
    var returnValue = studentDB->select(sqlString, Student, mobNo);

    table<Student> dataTable = table{};
    if (returnValue is error) {
        log:printError("Error obtaining student ID from the database", err = returnValue);
    } else {
        dataTable = returnValue;
    }
    return dataTable;
}
