import ballerina/io;
import ballerina/http;
import ballerina/test;

endpoint http:Client studentData  {
    url: "http://localhost:9292"
};


@test:Config
// Function to test GET resource 'testError'.
function testingMockError() {
    // Initialize the empty http request.
    http:Request request;
    // Send 'GET' request and obtain the response.
    http:Response response = check studentData->get("/records/testError");
    string res = check  response.getTextPayload();
    test:assertEquals(res,"Test Error made",
        msg = "Test error success");
}

@test:Config
function invalidDataDeletion() {
    http:Request request;
    // Send 'GET' request and obtain the response.
    http:Response response = check studentData->get("/records/deleteStu/9999");
    // Expected response json is as below.
    json res = check  response.getJsonPayload();
    test:assertEquals(res.toString(),"{\"Status\":\"Data Not Found\"}",
        msg = "Test error success");
}