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
import ballerina/test;
import ballerina/log;

http:Client studentService = new("http://localhost:9292");

@test:Config
// Function to test GET resource 'testError'.
function testingMockError() {
    // Initialize the empty HTTP request.
    http:Request request;
    // Send 'GET' request and obtain the response.
    var response = studentService->get("/records/testError");
    if (response is http:Response) {
        var res = response.getTextPayload();
        test:assertEquals(res, "Test Error made", msg = "Test error success");
    }
}

@test:Config
// Function to test GET resource 'deleteStu'.
function invalidDataDeletion() {
    http:Request request;
    // Send 'GET' request and obtain the response.
    var response = studentService->get("/records/deleteStu/9999");
    if (response is http:Response) {
        // Expected response JSON is as below.
        var resultJson = response.getJsonPayload();

        if (resultJson is json) {
            test:assertEquals(resultJson.toString(), "{\"Status\":\"Data Not Found\"}", msg = "Test error success");
        }
        else {
            log:printError("Error in fetching JSON from response", err = resultJson);
        }
    } else {
        log:printError("Error in obtained response", err = response);
    }
}
