import ballerina/io;
import ballerina/mysql;
import ballerina/http;
import ballerina/runtime;
import ballerina/observe;
import ballerina/log;

type Marks record {
    int student_Id,
    int maths,
    int english,
    int science,

};

endpoint mysql:Client testDB1 {
    host: "localhost",
    port: 3306,
    name: "testdb",
    username: "root",
    password: "",
    poolOptions: { maximumPoolSize: 5 },
    dbOptions: { useSSL: false }
};

// This service listener
endpoint http:Listener listener {
    port: 9191
};

// Service for the Student data service
@http:ServiceConfig {
    basePath: "/marks"
}
service<http:Service> MarksData bind listener {
    @http:ResourceConfig {
        methods:["GET"],
        path: "/getMarks/{stuId}"
    }
    // getMarks resource used to get student's marks
    getMarks(endpoint httpConnection, http:Request request, int stuId) {
        http:Response response = new;
        json result = findMarks(untaint stuId);


        //Pass the obtained json object to the requested client
        response.setJsonPayload(untaint result);
        _ = httpConnection->respond(response);
    }
}

documentation {
  `findMarks` is a function to find a student's marks from the marks record database
   P{{stuId}} This is the id of the student.
   R{{}} This function returns a json object. If data is found it returns json containing a table of data which is converted to json format.
            If data is not added , it returns the json containing a status and error message.
}

public function findMarks(int stuId) returns (json) {
    json status = {};
    io:println("reached");
    int spanId = check observe:startSpan("Select Data");
    // Self defined span for observability purpose
    string sqlString = "SELECT * FROM marks WHERE student_Id = " + stuId;
    // Getting student marks of the given ID
    io:println(stuId);
    var ret = testDB1->select(sqlString, Marks, loadToMemory = true);
    //Invoking select operation in testDB
    _ = observe:finishSpan(spanId);
    // Stopping the previously started span

    //Assigning data obtained from db to a table
    table<Marks> datatable;
    match ret {
        table tableReturned => datatable = tableReturned;
        error e => {
            io:println("Select data from student table failed: "
                    + e.message);

            status = { "Status": "Select data from student table failed: ", "Error": e.message };
            return status;
        }
    }
    //converting the obtained data in table format to json data
    var jsonConversionRet = <json>datatable;
    match jsonConversionRet {
        json jsonRes => {
            status = jsonRes;
        }
        error e => {
            status = { "Status": "Data Not available", "Error": e.message };
        }
    }
    io:println(status);
    return status;
}



