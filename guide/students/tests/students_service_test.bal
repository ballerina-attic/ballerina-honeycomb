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
