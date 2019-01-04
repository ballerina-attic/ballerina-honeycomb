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

// Host name of the server hosting the student administration system.
http:Client studentService = new("http://localhost:9292");

public function main() {
    http:Request req = new;
    int operation = 0;
    while (operation != 6) {
        // Print options menu to choose from.
        io:println("Select operation.");
        io:println("1. Add student");
        io:println("2. View all students");
        io:println("3. Delete a student");
        io:println("4. Make a mock error");
        io:println("5: Get a student's marks");
        io:println("6. Exit \n");

        // Read user's choice.
        string choice = io:readln("Enter choice 1 - 5: ");
        if (!isInteger(choice)) {
            io:println("Choice must be of a number");
            io:println();
            continue;
        }
        var intOperation = int.convert(choice);
        if (intOperation is int) {
            io:println(intOperation);
            operation = intOperation;
        } else {
            log:printError("Error in converting the option selected by the user to an integer.", err = intOperation);
        }
        // Program runs until the user inputs 6 to terminate the process.
        match operation {
            1 => addStudent(req);
            2 => viewAllStudents();
            3 => deleteStudent();
            4 => makeError();
            5 => getMarks();
            6 => break;
            _ => io:println("Invalid choice");
        }
    }
}

// Function to check if the input is an integer.
function isInteger(string input) returns boolean {
    string regEx = "\\d+";
    boolean|error isInt = input.matches(regEx);
    if (isInt is error) {
        log:printError("Error in checking if the type of the input variable is integer", err = isInt);
        return false;
    } else {
        return isInt;
    }

}

// Function to add details of a student to the database.
function addStudent(http:Request req) {
    // Get student name, age mobile number, address.
    var name = io:readln("Enter Student name: ");
    var age = io:readln("Enter Student age: ");
    var mobile = io:readln("Enter mobile number: ");
    var add = io:readln("Enter Student address: ");
    var ageAsInt = int.convert(age);
    var mobNoAsInt = int.convert(mobile);

    if (ageAsInt is int && mobNoAsInt is int) {
        // Create the request as JSON message.
        json jsonMsg = { "name": name, "age": ageAsInt, "mobNo": mobNoAsInt, "address": add, "id": 0 };
        req.setJsonPayload(jsonMsg);

    } else {
        log:printError("Error in converting the age and the mobile number to integers.", err = ageAsInt);
        return;
    }

    // Sending the request to the students service and getting the response from it.
    var resp = studentService->post("/records/addStudent", req);

    if (resp is http:Response) {
        // Extracting data from the received JSON object..
        var jsonMsg = resp.getJsonPayload();
        if (jsonMsg is json) {
            string message = "Status: " + jsonMsg["Status"] .toString() + " Added Student Id :- " +
                jsonMsg["id"].toString();
            io:println(message);
        } else {
            log:printError("Error in extracting the JSON payload from the response.", err = jsonMsg);
        }
    } else {
        log:printError("Error in the obtained response", err = resp);
    }
}

// Function to view details of all the students.
function viewAllStudents() {
    // Sending a request to list down all students and get the response from it.
    var response = studentService->post("/records/viewAll", null);
    if (response is http:Response) {
        var jsonMsg = response.getJsonPayload();

        if (jsonMsg is json) {
            string message = "";

            if (jsonMsg.length() >= 1) {
                int i = 0;
                while (i < jsonMsg.length()) {

                    message = "Student Name: " + jsonMsg[i]["name"] .toString() + ", " + " Student Age: " +
                        jsonMsg[i]["age"] .toString();

                    io:println(message);
                    i += 1;
                }
            } else {
                // Notify user if no records are available.
                message = "\n Student record is empty";
                io:println(message);
            }

        } else {
            log:printError("Error in extracting JSON from response", err = jsonMsg);
        }

    } else {
        log:printError("Error in obtained response", err = resp);
    }
}

// Function to delete a student's data from the system.
function deleteStudent() {
    // Get student id.
    string id = io:readln("Enter student id: ");

    // Request made to find the student with the given id and get the response from it.
    var resp = studentService->get("/records/deleteStu/" + id);

    if (resp is http:Response) {
        var jsonMsg = resp.getJsonPayload();
        if (jsonMsg is json) {
            string message = jsonMsg["Status"].toString();
            io:println("\n" + message + "\n");
        } else {
            log:printError("Error in extracting JSON from response", err = jsonMsg);
        }
    } else {
        log:printError("Error in obtained response", err = resp);
    }

}

// Function to generate a mock error in the system for observability purposes.
function makeError() {
    var response = studentService->get("/records/testError");
    if (response is http:Response) {
        var msg = response.getTextPayload();
        if (msg is string) {
            io:println("\n" + msg + "\n");
        } else {
            log:printError("Error in fetching text from the response", err = msg);
        }
    } else {
        log:printError("Error in the obtained response", err = response);
    }
}

// Function to fetch marks of a student from the system.
function getMarks() {
    // Gets the student ID.
    var id = io:readln("Enter student id: ");
    // Request made to get the marks of the student with given id and get the response from it.
    var response = studentService->get("/records/getMarks/" + id);
    if (response is http:Response) {
        var jsonMsg = response.getJsonPayload();
        if (jsonMsg is json) {
            string message = "";
            // Validate to check if student with given ID exist in the system.
            if (jsonMsg.length() >= 1) {
                message = "Maths: " + jsonMsg[0]["maths"] .toString() + " English: " + jsonMsg[0]["english"] .toString()
                    +
                    " Science: " + jsonMsg[0]["science"] .toString();
            } else {
                message = "Data not available. Check if student's mark is added or student might not be in our system.";
            }
            io:println("\n" + message + "\n");
        } else {
            log:printError("Error in extracting the JSON payload from the response.", err = jsonMsg);
        }
    } else {
        log:printError("Error in the obtained response ", err = response);
    }
}
