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

// Type Marks is created to represent a set of marks.
type Marks record {
    int studentId;
    int maths;
    int english;
    int science;
};

// Listener for marks service.
listener http:Listener marksServiceListener = new(9191);

// Marks data service.
@http:ServiceConfig {
    basePath: "/marks"
}

service MarksData on marksServiceListener {
    @http:ResourceConfig {
        methods: ["GET"],
        path: "/getMarks/{stuId}"
    }
    // Get marks resource used to get student's marks.
    resource function getMarks(http:Caller httpConnection, http:Request request, int stuId) {
        http:Response response = new;
        json result = findMarks(untaint stuId);
        // Pass the obtained JSON object to the requested client.
        response.setJsonPayload(untaint result);
        var resResult = httpConnection->respond(response);

        if (resResult is error) {
            log:printError("Error sending response", err = resResult);
        }
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
    var returnValue = studentDB->select(sqlString, Marks, loadToMemory = true);

    // Assigning data obtained from db to a table.
    table<Marks> dataTable = table {};

    if (returnValue is table<Marks>) {
        dataTable = returnValue;
    } else {
        log:printError("Error Detected", err = returnValue);
        status = { "Status": "Select data from student table failed: " };
        return status;
    }
    // Converting the obtained data in table format to JSON data.
    var jsonConversionValue = json.convert(dataTable);

    if (jsonConversionValue is json) {
        status = jsonConversionValue;
    } else {
        status = { "Status": "Data Not available" };
        log:printError("Error Detected", err = jsonConversionValue);
    }
    return status;
}



