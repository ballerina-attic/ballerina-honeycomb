import ballerina/io;
import ballerina/http;
import ballerina/test;
import ballerina/log;

http:Client studentService = new("http://localhost:9292",
    config = { httpVersion: "2.0" });


@test:Config
// Function to test GET resource 'testError'.
function testingMockError() {
    // Initialize the empty HTTP request.
    http:Request request;
    // Send 'GET' request and obtain the response.
    var response = studentService->get("/records/testError");
    if (response is http:Response){
        var res = response.getTextPayload();
        test:assertEquals(res,"Test Error made", msg = "Test error success");
    }

}

@test:Config
function invalidDataDeletion() {
    http:Request request;
    // Send 'GET' request and obtain the response.
    var response =  studentService->get("/records/deleteStu/9999");
    if (response is http:Response){
        // Expected response JSON is as below.
        var res = response.getJsonPayload();

        if (res is json) {
            test:assertEquals(res.toString(), "{\"Status\":\"Data Not Found\"}", msg = "Test error success");
        }
        else {
            log:printError("Error", err = res);
        }
    }
}