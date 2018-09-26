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

import ballerina/io;
import ballerina/http;
import ballerina/log;

endpoint http:Client studentData {
    url: " http://localhost:9292"
};

function main(string... args) {
    http:Request req = new;
    int operation = 0;
    while (operation != 6) {
        // print options menu to choose from
        io:println("Select operation.");
        io:println("1. Add student");
        io:println("2. View all students");
        io:println("3. Delete a student");
        io:println("4. Make a mock error");
        io:println("5: Get a student's marks");
        io:println("6. Exit");
        io:println();

        string choice = io:readln("Enter choice 1 - 5: ");   // read user's choice
        if (!isInteger(choice)){
            io:println("Choice must be of a number");
            io:println();
            continue;
        }

        operation = check <int>choice;
        // Program runs until the user inputs 7 to terminate the process
        if (operation == 6) {
            break;
        }
        //user chooses to add a student
        if (operation == 1) {
            addStudent(req);
        }
        //user chooses to list down all the students
        else if (operation == 2) {
            viewAllStudents();
        }
        // User chooses to delete a student by Id
        else if (operation == 3) {
            deleteStudent();
        }
        //User chooses to make a mock error
        else if (operation == 4) {
            makeError();
        }
        else if (operation == 5){
          getMarks();
        }
        else {
            io:println("Invalid choice");
        }
    }
}

function isInteger(string input) returns boolean {
    string regEx = "\\d+";
    boolean isInt = check input.matches(regEx);
    return isInt;
}

function addStudent(http:Request req) {
    //get student name, age mobile number, address
    var name = io:readln("Enter Student name: ");
    var age = io:readln("Enter Student age: ");
    var mobile = io:readln("Enter mobile number: ");
    var add = io:readln("Enter Student address: ");

    //create the request as json message
    json jsonMsg = { "name": name, "age": check <int>age, "mobNo": check <int>mobile, "address": add };
    req.setJsonPayload(jsonMsg);

    //send the request to students service and get the response from it
    var resp = studentData->post("/records/addStudent", req);
    match resp {
        http:Response response => {
            var msg = response.getJsonPayload();
            //obtaining the result from the response received
            match msg {
                json jsonPL => {
                    string message = "Status: " + jsonPL["Status"] .toString() + " Added Student Id :- " +
                        jsonPL["id"].toString();
                    //Extracting data from json received and displaying
                    io:println(message);
                }

                error err => {
                    log:printError(err.message, err = err);
                    //Print error
                }
            }
        }
        error err => {
            log:printError(err.message, err = err);
            //Print error
        }
    }
}

function viewAllStudents() {
    //sending a request to list down all students and get the response from it
    var requ = studentData->post("/records/viewAll", null);
    match requ {
        http:Response response => {
            var msg = response.getJsonPayload();
            //obtaining the result from the response received
            match msg {
                json jsonPL => {
                    string message;
                    if (lengthof jsonPL >= 1) {            //validate to check if records are available
                        int i;
                        io:println();
                        // Loop through the received json array and display data
                        while (i < lengthof jsonPL) {

                            message = "Student Name: " + jsonPL[i]["name"] .toString() + ", " + " Student Age: "
                                +
                                jsonPL[i]["age"] .toString();
                            io:println(message);
                            i++;
                        }
                        io:println();
                    }
                    else {
                        // Notify user if no records are available
                        message = "Student record is empty";
                        io:println(message);
                    }
                }
                error err => {
                    log:printError(err.message, err = err);
                    //Print any error caused
                }
            }
        }
        error err => {
            log:printError(err.message, err = err);
            //Print any error caused
        }
    }
}

function deleteStudent(){
    // Get student id
    var id = io:readln("Enter student id: ");
    // Request made to find the student with the given id and get the response from it
    var requ = studentData->get("/records/deleteStu/" + check <int>id);
    match requ {
        http:Response response => {
            var msg = response.getJsonPayload();
            //obtaining the result from the response received
            match msg {
                json jsonPL => {
                    string message;
                    message = jsonPL["Status"].toString();

                    io:println();
                    io:println(message);
                    io:println();
                }

                error err => {
                    log:printError(err.message, err = err);
                    //Print any error caused
                }
            }
        }
        error er => {
            io:println(er.message);
        }
    }
}

function makeError() {
    var requ = studentData->get("/records/testError");
    match requ {
        http:Response response => {
            var msg = response.getTextPayload();
            //obtaining the result from the response received
            match msg {
                string message => {

                    io:println();
                    io:println(message);
                    io:println();
                }
                error err => {
                    log:printError(err.message, err = err);
                    //Print any error caused
                }
            }
        }
        error er => {
            io:println(er.message);
        }
    }
}

function getMarks(){
    // Get student id
    var id = io:readln("Enter student id: ");
    // Request made to get the marks of the student with given id and get the response from it
    var requ = studentData->get("/records/getMarks/" + check <int>id);

    match requ {
        http:Response response => {
            var msg = response.getJsonPayload();
            //obtaining the result from the response received
            match msg {
                json jsonPL => {
                    string message;

                    if (lengthof jsonPL >= 1) {
                        // Validate to check if student with given ID exist in the system
                        message = "Maths: " + jsonPL[0]["maths"] .toString() + " English: " + jsonPL[0
                            ][
                            "english"] .toString() + " Science: " + jsonPL[0]["science"] .toString();
                    }
                    else {
                        message =
                        "Data not available. Check if student's mark is added or student might not be in our system."
                        ;
                    }
                    io:println();
                    io:println(message);
                    io:println();
                }

                error err => {
                    log:printError(err.message, err = err);
                    //Print any error caused
                }
            }
        }
        error err => {
            log:printError(err.message, err = err);
            // Print any error caused
        }
    }
}