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

type Marks record {
    int studentId;
    int maths;
    int english;
    int science;
};

// This service listener.
endpoint http:Listener marksServiceListener{
    port: 9191
};

// Marks data service.
@http:ServiceConfig {
    basePath: "/marks"
}
service<http:Service> MarksData bind marksServiceListener {
    @http:ResourceConfig {
        methods:["GET"],
        path: "/getMarks/{stuId}"
    }
    // Get marks resource used to get student's marks.
    getMarks(endpoint httpConnection, http:Request request, int stuId) {
        http:Response response = new;
        json result = findMarks(untaint stuId);
        // Pass the obtained JSON object to the requested client.
        response.setJsonPayload(untaint result);
        _ = httpConnection->respond(response) but { error e => log:printError("Error sending response", err = e) };
    }
}

 # `findMarks()`is a function to find a student's marks from the marks record database.
 #
 #  + stuId -  This is the id of the student.
 # + return - This function returns a JSON object. If data is added it returns JSON containing a status and id of student added.
 #            If data is not added , it returns the JSON containing a status and error message.

public function findMarks(int stuId) returns (json) {
    json status = {};
    string sqlString = "SELECT * FROM marks WHERE student_Id = " + stuId;
    // Getting student marks of the given ID.
    // Invoking select operation in testDB.
    var returnValue = databaseEP->select(sqlString, Marks, loadToMemory = true);

    // Assigning data obtained from db to a table.
    table<Marks> dataTable;
    match returnValue {
        table tableReturned => dataTable = tableReturned;
        error err => {
            log:printError(err.message,err= err);
            status = { "Status": "Select data from student table failed: ", "Error": err.message };
            return status;
        }
    }
    // Converting the obtained data in table format to JSON data.
    var jsonConversionValue = <json>dataTable;
    match jsonConversionValue {
        json jsonResult => {
            status = jsonResult;
        }
        error err => {
            status = { "Status": "Data Not available", "Error": err.message };
            log:printError(err.message,err = err);
        }
    }
    io:println(status);
    return status;
}



