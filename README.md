[![Build Status](https://travis-ci.org/ballerina-guides/ballerina-honeycomb.svg?branch=master)](https://travis-ci.org/ballerina-guides/ballerina-honeycomb)
  
# Integration with Honeycomb

Honeycomb is a tool used to investigate how well your system works in various conditions (for example - high traffic). Through Honeycomb, you can collect data pertaining to your software that can be broken down into various entities. You can observe the performance of each of these entities specifically.
     
> This guide provides instructions on how Ballerina can be used to integrate with Honeycomb.

The following are the sections available in this guide.

- [What you'll build](#what-you’ll-build)
- [Prerequisites](#prerequisites)
- [Implementation](#implementation)
- [Testing](#testing)
- [Configuration with Honeycomb](#testing-with-honeycomb)
     - [Traces](#views-of-traces)
     - [Metrics](#metrics)

## What you’ll build
To perform this integration with Honeycomb,  a real world use case of a very simple student management system is used.
This system will illustrate the manipulation of student details in a school/college management system. The administrator will be able to perform the following actions in this service.

    - Add a student's details to the system.
    - List down all the student's details who are registered in the system.
    - Delete a student's details from the system by providing student ID.
    - Generate a mock error (for observability purposes).
    - Get a student's marks list by providing student ID.

![Honeycomb](images/ballerina-honeycomb.svg "Ballerina-Honeycomb")

- **Make Requests** : To perform actions on student management service, a console-based client program has been written in Ballerina for your ease of making requests.

## Prerequisites
 
- [Ballerina Distribution](https://ballerina.io/learn/getting-started/)
- [Honeycomb Plan](https://www.honeycomb.io/)
- A Text Editor or an IDE 
> **Tip**: For a better development experience, install one of the following Ballerina IDE plugins: [VSCode](https://marketplace.visualstudio.com/items?itemName=ballerina.ballerina), [IntelliJ IDEA](https://plugins.jetbrains.com/plugin/9520-ballerina)
- [Docker](https://docs.docker.com/engine/installation/)
- [MySQL](https://github.com/ballerina-guides/ballerina-honeycomb/blob/master/resources/testdb.sql)

## Implementation

> If you want to skip the basics, you can download the GitHub repo and continue from the [Testing](#testing) section.

### Implementing the database
 - Start MySQL server in your local machine.
 - Create a database with name `testdb` in your MySQL localhost. If you want to skip the database implementation, then directly import the [testdb.sql](https://github.com/ballerina-guides/ballerina-honeycomb/blob/master/resources/testdb.sql) file into your localhost. You can find it in the GitHub repo.
### Create the project structure
        
 For the purpose of this guide, let's use the following package structure.
        
    
    ballerina-honeycomb
           └── guide
                ├── students
                │   ├── student_management_service.bal
                │   ├── student_marks_management_service.bal
                |   └── ballerina.conf
                └── client_service
                         └── client_main.bal
               
        

- Create the above directories in your local machine, along with the empty `.bal` files.

- Add the following lines in your [ballerina.conf](https://github.com/ballerina-guides/ballerina-honeycomb/blob/master/ballerina.conf) to send the service traces to Honeycomb in Zipkin format using Opentracing.

```ballerina
[b7a.observability.tracing]
enabled=true
name="zipkin"

[b7a.observability.tracing.zipkin]
reporter.hostname="localhost"
reporter.port=9411

# Here the reporter API is set up in order to send spans. API version v1 is used as the honeycomb-opentracing supports the V1 version.
reporter.api.context="/api/v1/spans"
reporter.api.version="v1"


reporter.compression.enabled=false
```

- Open the terminal, navigate to `ballerina-honeycomb/guide`, and run Ballerina project initializing toolkit.

``
   $ ballerina init
``

- Clone and build the ballerina-zipkin-extension in the following repository [https://github.com/ballerina-platform/ballerina-observability/tree/master/tracing-extensions/modules.](https://github.com/ballerina-platform/ballerina-observability/tree/master/tracing-extensions/modules) 

- After building this extension, navigate to `ballerina-zipkin-extension/target` and extract and copy the JAR files in `distribution.zip` to your `bre/lib` folder in your Ballerina distribution.

### Development of student management and marks management services with Honeycomb

Now let us look into the implementation of the student management service with observability.

##### student_management_service.bal

``` ballerina
import ballerina/http;
import ballerina/io;
import ballerina/log;
import ballerina/mysql;
import ballerina/observe;
import ballerina/runtime;
import ballerina/sql;

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
        password: "root",
        dbOptions: { useSSL: false }
    });

// Listener of the student service port.
listener http:Listener studentServiceListener = new(9292);

// Service configuration of the student data service..
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
    resource function addStudents(http:Caller caller, http:Request request) returns error? {
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
        // The below function adds tags to be passed as metrics in the message traces. These tags are added to the default system span.
        check observe:addTagToSpan("tot_requests", string.convert(studentData.requestCounts));
        check observe:addTagToSpan("error_counts", string.convert(studentData.errors));

        // Send the response back to the client with the returned JSON value from insertData function.
        var result = caller->respond(response);
        if (result is error) {
            // Log the error for the service maintainers.
            log:printError("Error in sending response to the client", err = result);
        }
    }

    // Resource configuration for viewing details of all the students in the system.
    @http:ResourceConfig {
        methods: ["POST"],
        path: "/viewAll"
    }
    // View students resource is to get all the students details and send to the requested user.
    resource function viewStudents(http:Caller caller, http:Request request) returns error? {
        studentData.requestCounts += 1;
        int|error childSpanId = observe:startSpan("Obtain details span");
        http:Response response = new;
        json status = {};
        int spanId2 = observe:startRootSpan("Database call span");

        // Sending a request to MySQL endpoint and getting a response with required data table.
        var returnValue = studentDB->select("SELECT * FROM student", Student, loadToMemory = true);
        check observe:finishSpan(spanId2);

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
            log:printError("Error in converting the data from a tabular format to JSON.", err = jsonConversionValue);
        } else {
            status = jsonConversionValue;
        }
        // Sending back the converted JSON data to the request made to this service.
        response.setJsonPayload(untaint status);
        var result = caller->respond(response);
        if (result is error) {
            log:printError("Error in sending the response", err = result);
        }

        if (childSpanId is int) {
            check observe:finishSpan(childSpanId);
        } else {
            log:printError("Error attaching span ", err = childSpanId);
        }
        //The below function adds tags to be passed as metrics in the message traces. These tags are added to the default system span.
        check observe:addTagToSpan("tot_requests", string.convert(studentData.requestCounts));
        check observe:addTagToSpan("error_counts", string.convert(studentData.errors));
    }

    // Resource configuration for making a mock error to the system.
    @http:ResourceConfig {
        methods: ["GET"],
        path: "/testError"
    }
    // Resource to generate a mock error for testing purposes.
    resource function testError(http:Caller caller, http:Request request) returns error? {
        studentData.requestCounts += 1;
        http:Response response = new;
        studentData.errors += 1;
        io:println(studentData.errors);
        // The below function adds tags to be passed as metrics in the message traces. These tags are added to the default system span.
        check observe:addTagToSpan("tot_requests", string.convert(studentData.requestCounts));
        check observe:addTagToSpan("error_counts", string.convert(studentData.errors));
        log:printError("error test");
        response.setTextPayload("Test Error made");
        var result = caller->respond(response);
        if (result is error) {
            log:printError("Error in sending response to the client", err = result);
        }
    }

    // Resource configuration for deleting the details of a student from the system.
    @http:ResourceConfig {
        methods: ["GET"],
        path: "/deleteStu/{studentId}"
    }
    // Delete Students resource for deleteing a student using id.
    resource function deleteStudent(http:Caller caller, http:Request request, int studentId) returns error? {
        studentData.requestCounts += 1;
        http:Response response = new;
        json status = {};

        // Calling the deleteData function with the studentId as the parameter and getting a JSON object returned.
        var returnValue = deleteData(studentId);
        io:println(returnValue);

        // Pass the obtained JSON object to the request.
        response.setJsonPayload(returnValue);
        var result = caller->respond(response);
        if (result is error) {
            log:printError("Error in sending response to the client", err = result);
        }
        // The below function adds tags to be passed as metrics in the message traces. These tags are added to the default system span.
        check observe:addTagToSpan("tot_requests", string.convert(studentData.requestCounts));
        check observe:addTagToSpan("error_counts", string.convert(studentData.errors));
    }

    // Resource configuration for getting the marks of a particular student.
    @http:ResourceConfig {
        methods: ["GET"],
        path: "/getMarks/{studentId}"
    }
    // Get marks resource for obtaining marks of a particular student.
    resource function getMarks(http:Caller caller, http:Request request, int studentId) returns error? {
        studentData.requestCounts += 1;
        http:Response response = new;
        json result = {};

        // Self-defined span for observability purposes.
        int|error firstSpan = observe:startSpan("First span");
        // Request to be sent to the to marks Service for obtaining the marks of the student with the respective studentId.
        var requestReturn = marksServiceEP->get("/marks/getMarks/" + untaint studentId);
        if (requestReturn is error) {
            log:printError("Error in fetching marks from the system.", err = requestReturn);
        } else {
            var msg = requestReturn.getJsonPayload();
            if (msg is error) {
                log:printError("Error in extracting the JSON payload from the response", err = msg);
            } else {
                result = msg;
            }
        }

        // Stopping the previously started span.
        if (firstSpan is int) {
            check observe:finishSpan(firstSpan);
        } else {
            log:printError("Error attaching span ", err = firstSpan);
        }
        //Sending the JSON to the client.
        response.setJsonPayload(untaint result);
        var resResult = caller->respond(response);
        if (resResult is error) {
            log:printError("Error in sending response to the client", err = resResult);
        }
        // The below function adds tags to be passed as metrics in the message traces. These tags are added to the default system span.
        check observe:addTagToSpan("tot_requests", string.convert(studentData.requestCounts));
        check observe:addTagToSpan("error_counts", string.convert(studentData.errors));
    }
}

// Function to insert values to the database..
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
    if (returnValue is sql:UpdateResult) {
        table<Student> result = getId(untaint mobNo);
        while (result.hasNext()) {
            var returnValue2 = result.getNext();
            if (returnValue2 is Student) {
                uniqueId = returnValue2.id;
            } else {
                log:printError("Error in obtaining a student ID from the database for the added student.", 
                                err = returnValue2 is error ? returnValue2 : ());
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

# Function to delete data of a student from the database..
# `deleteData()` is a function to delete a student's data from student records database.
#
# + studentId - This is the id of the student to be deleted.
# + return -This function returns a JSON object. If data is deleted it returns JSON containing a status.
#           If data is not deleted , it returns the JSON containing a status and error message.

public function deleteData(int studentId) returns (json) {
    json status = {};
    string sqlString = "DELETE FROM student WHERE id = ?";

    // Invoking an update action to delete existing data from the database.
    var returnValue = studentDB->update(sqlString, studentId);
    io:println(returnValue);

    if (returnValue is sql:UpdateResult) {
        if (returnValue.updatedRowCount != 1) {
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
        log:printError("Error in obtaining the student ID from the database to retrieve the marks of the student.
        ", err = returnValue);
    } else {
        dataTable = returnValue;
    }
    return dataTable;
}

```

Now we will look into the implementation of obtaining the marks of the students from database through another service.

##### student_marks_management_service.bal

``` ballerina
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

// Listener for the port of the marks service.
listener http:Listener marksServiceListener = new(9191);

// Service configuration of the marks service.
@http:ServiceConfig {
    basePath: "/marks"
}
service MarksData on marksServiceListener {
    // Resource configuration for retrieving the marks of a student from the system.
    @http:ResourceConfig {
        methods: ["GET"],
        path: "/getMarks/{stuId}"
    }
    // Resource used to get student's marks.
    resource function getMarks(http:Caller caller, http:Request request, int stuId) {
        http:Response response = new;
        json result = findMarks(untaint stuId);
        // Pass the obtained JSON object to the requested client.
        response.setJsonPayload(untaint result);
        var resResult = caller->respond(response);
        if (resResult is error) {
            log:printError("Error in sending response to the client", err = resResult);
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
        log:printError("Error in fetching the data table from the database", err = returnValue);
        status = { "Status": "Select data from student table failed: " };
        return status;
    }
    // Converting the obtained data in table format to JSON data.
    var jsonConversionValue = json.convert(dataTable);

    if (jsonConversionValue is json) {
        status = jsonConversionValue;
    } else {
        status = { "Status": "Data Not available" };
        log:printError("Error in converting the fetched data from tabular format to JSON.", err = jsonConversionValue);
    }
    return status;
}
```

- Now we have completed the implementation of student management service with marks management service.


## Testing 

### Invoking the student management service

You can start both services by opening a terminal, navigating to `ballerina-honeycomb/guide`, and executing the following command.

```
$ ballerina run --config students/ballerina.conf students
```

 You need to start the honeycomb-opentracing-proxy. This can be done by using Docker. Docker is used to pull the image for honeycomb-opentracing-proxy.
 Run the following command.
 
 ```
 docker run -p 9411:9411 honeycombio/honeycomb-opentracing-proxy -k <APIKEY> -d <DATASET>
```
- -k represent the API KEY you get when you sign up to your Honeycomb account.

- -d represents the dataset to which the trace data are sent to.

 You can observe the service performance by making some HTTP requests to the above services. This is made easy for you as there is a client program implemented. You can start the client program by opening another terminal and navigating to ballerina-honeycomb/guide
 and run the below command.
 
 ```
 $ ballerina run client_service
 ``` 
### Testing with Honeycomb
 
#### Views of traces
After making HTTP requests, go to [Honeycomb website](https://honeycomb.io) then navigate to your dataset.
When you are in your dataset in Honeycomb UI you get to see a button called `New query`, and when you click on that you can write your own queries on the metrics that you have received.
 
 - You are expected to see the traces as below when you include traceId in the breakdown category.

![Honeycomb](images/traces1.png "Honeycomb")
 
 - To view a particular trace, click on the traceId column, and you will see as below
 
![Honeycomb](images/traces2.png "Honeycomb")
    
 - To view span details with metrics click on a particular span and you are expected to see as below
 
![Honeycomb](images/traces3.png "Honeycomb")
       
#### Metrics 
  You can perform some detailed queries in order to look deep in the performance of your services. Here are some examples:-
  
  - [Total requests](#total-requests)
  - [Resources with high response time](#resources-with-high-response-time)
  - [Counts of database manipulations](#counts-of-database-manipulations)
  - [Mostly hit resources](#mostly-hit-resources)
  - [Average response time](#average-response-time)
  - [Error detection](#error-detection)
  - [Percentiles of response duration](#percentiles-of-response-duration)
  - [Last 1 minute summary](#last-1-minute-summary)
  - [Last 5 minutes summary](#last-5-minutes-summary)
  - [Last 1 hour summary](#last-1-hour-summary) 
  
##### Total requests
   
###### Per resource 
   This will include self defined spans as well
   
    Query parameters use for each category:-
            
       1. BREAK DOWN - name
       2. CALCULATE PER GROUP - COUNT_DISTINCT(traceId)
       3. FILTER - name does-not-start-with ballerina/ 

    We filter out the other default ballerina resource using the filter query.
         
![Honeycomb](images/query1.png "Honeycomb") 
    
The result of the above query is as below : -
 
![Honeycomb](images/result1.png "Honeycomb")
   
   
###### Per service 
      
               
               Query parameters use for each category:-
               
                            1. BREAK DOWN - serviceName 
                            2. CALCULATE PER GROUP - COUNT_DISTINCT(traceId)
                            3. FILTER - name does-not-start-with ballerina/ 
                            4. LIMIT - 100
                            
                 We filter out the other default ballerina resource using the filter query.
            
![Honeycomb](images/query11.png "Honeycomb")
       
   The result of the above query is as below : -
    
![Honeycomb](images/result11.png "Honeycomb")
      
   
#### Resources with high response time 
   This will include self defined spans as well.
   
    Query parameters use for each category:-

      1. BREAK DOWN - name
      2. CALCULATE PER GROUP - MAX(durationMs)
      3. FILTER - name does-not-start-with ballerina/
      4. ORDER - MAX(durationMs) desc
      5. LIMIT - 100
                         
    We filter out the other default ballerina resource using the filter query.      
                         
![Honeycomb](images/query4.png "Honeycomb")
                 
The result of the above query is as follows : -
      
![Honeycomb](images/result4.png "Honeycomb")
 
#### Counts of database manipulations

      
    Query parameters use for each category:-
                
      1. BREAK DOWN - name
      2. CALCULATE PER GROUP - COUNT
      3. FILTER - db.instance = testdb
      4. ORDER - COUNT desc
      5. LIMIT - 100     
                            
![Honeycomb](images/query5.png "Honeycomb")                     
                    
The result of the above query is as follows : -
         
![Honeycomb](images/result5.png "Honeycomb")
      
#### Mostly hit resources 
 This will include self defined spans as well.
              
    Query parameters use for each category:-
            
      1. BREAK DOWN - name
      2. CALCULATE PER GROUP - COUNT_DISTINCT(traceId)
      3. FILTER - name does-not-start-with ballerina/
      4. ORDER - COUNT_DISTINCT(traceId) desc
      5. LIMIT - 100
             
    We filter out the other default ballerina resource using the filter query.
                                
![Honeycomb](images/query6.png "Honeycomb")
                    
The result of the above query is as follows : -
         
![Honeycomb](images/result6.png "Honeycomb")

#### Average response time
   
###### Per service
  
    Query parameters use for each category:-
                    
      1. BREAK DOWN - serviceName
      2. CALCULATE PER GROUP - AVG(durationMs)
      3. LIMIT - 100
  
  
![Honeycomb](images/query7.png "Honeycomb")
                      
 The result of the above query is as follows : -
         
![Honeycomb](images/result7.png "Honeycomb")
   
###### Per resource
   >This will include self defined spans as well.
               
    Query parameters use for each category:-
               
      1. BREAK DOWN - name
      2. CALCULATE PER GROUP - AVG(durationMs)
      3. FILTER - name does-not-start-with ballerina/
      4. LIMIT - 100
       
    We filter out the other default ballerina resource using the filter query.
                       
![Honeycomb](images/query8.png "Honeycomb")
                        
The result of the above query is as follows : -
             
![Honeycomb](images/result8.png "Honeycomb") 
   
#### Error detection

    Query parameters use for each category:- 
  
      1. CALCULATE PER GROUP - COUNT_DISTINCT(error_counts)
                            
![Honeycomb](images/query9.png "Honeycomb")
                          
  The result of the above query is as follows : -
               
![Honeycomb](images/result9.png "Honeycomb") 

#### Percentiles of response duration
  
###### Per service
  
    Query parameters use for each category:-
                   
      1. BREAK DOWN - serviceName 
      2. CALCULATE PER GROUP - P75(durationMs),P50(durationMs), P25(durationMs)

                           
The result of the above query is as follows : -
                
![Honeycomb](images/result10.png "Honeycomb") 
   
   
#### Last 1 minute summary
      
###### Per service
      
To find the total request count per service with average response time for the last 1 minute :-
   
   >Duration can be set on the top right corner of the query builder. You can customize the time period within which you wanted to get the metrics.
      
![Honeycomb](images/time1.png "Honeycomb")
   
 By the drop down menu you can customize the time period.
          
    Query parameters use for each category:-
                 
      1. BREAK DOWN - serviceName
      2. CALCULATE PER GROUP - AVG(durationMs), COUNT_DISTINCT(traceId)
      3. FILTER - name does-not-start-with ballerina/     
                 
    We filter out the other default ballerina resource using the filter query.
                             
![Honeycomb](images/query12.png "Honeycomb")
                           
The result of the above query is as follows : -
                
![Honeycomb](images/result12.png "Honeycomb")
   
###### Per resource
   This will include all self defined span as well when finding the number of requests per resource wit average response time.
   Set the time period to 1 minute as instructed above.
   
    Query parameters use for each category:-
            
      1. BREAK DOWN - name
      2. CALCULATE PER GROUP - COUNT_DISTINCT(traceId), AVG(durationMs)
      3. FILTER - name does-not-start-with ballerina/ 
      4. LIMIT - 100 
                  
    We filter out the other default ballerina resource using the filter query.
                          
![Honeycomb](images/query13.png "Honeycomb")
                            
  The result of the above query is as follows : -
                 
![Honeycomb](images/result13.png "Honeycomb")
  
  
#### Last 5 minutes summary
        
###### Per service
       
   To find the total request count per service with average response time for the last 5 minutes :-
  > Duration can be set on the top right corner of the query builder. You can customize the 
   time period within which you wanted to get the metrics.
        
![Honeycomb](images/time2.png "Honeycomb")
     
   By the drop down menu you can customize the time period.
            
    Query parameters use for each category:-
                   
      1. BREAK DOWN - serviceName
      2. CALCULATE PER GROUP - AVG(durationMs), COUNT_DISTINCT(traceId)
      3. FILTER - name does-not-start-with ballerina/     
                   
    We filter out the other default ballerina resource using the filter query.
                             
![Honeycomb](images/query14.png "Honeycomb")
                             
   The result of the above query is as follows : -
                  
![Honeycomb](images/result14.png "Honeycomb")

###### Per resource
   This will include all self defined span as well.
   Set the time period to 5 minutes as instructed above.
     
    Query parameters use for each category:-
              
      1. BREAK DOWN - name
      2. CALCULATE PER GROUP - COUNT_DISTINCT(traceId), AVG(durationMs)
      3. FILTER - name does-not-start-with ballerina/ 
      4. LIMIT - 100 
                         
    We filter out the other default ballerina resource using the filter query.
                            
![Honeycomb](images/query15.png "Honeycomb")
                              
   The result of the above query is as follows : -
                   
![Honeycomb](images/result15.png "Honeycomb")
   
#### Last 1 hour summary
           
###### Per service
          
   To find the total request count per service with average response time for the last 1 hour :-
  > Duration can be set on the top right corner of the query builder. You can customize the 
   time period within which you wanted to get the metrics.
           
![Honeycomb](images/time3.png "Honeycomb")
        
   By the drop down menu you can customize the time period.
               
    Query parameters use for each category:-
               
      1. BREAK DOWN - serviceName
      2. CALCULATE PER GROUP - AVG(durationMs), COUNT_DISTINCT(traceId)
      3. FILTER - name does-not-start-with ballerina/   
                             
    We filter out the other default ballerina resource using the filter query. 
                                
![Honeycomb](images/query16.png "Honeycomb")
                                
   The result of the above query is as follows : -
                     
![Honeycomb](images/result16.png "Honeycomb")
        
        
###### Per resource
   This will include all self defined span as well.
   Set the time period to 1 hour as instructed above.
        
    Query parameters use for each category:-
                 
      1. BREAK DOWN - name
      2. CALCULATE PER GROUP - COUNT_DISTINCT(traceId), AVG(durationMs)
      3. FILTER - name does-not-start-with ballerina/ 
      4. LIMIT - 100 
      
    We filter out the other default ballerina resource using the filter query.
                               
![Honeycomb](images/query17.png "Honeycomb")
                                 
   The result of the above query is as follows : -
                     
![Honeycomb](images/result17.png "Honeycomb")

##### Honeycomb UI Boards
   
   These queries can be predefined and added to the board so that the live observability can be achieved without building queries multiple times. 
   
   To add a query to a board : -
      
   - Create a board.  You can create a board when you run a query. You will see an option “Add to Board” above the query builder.
   
![Honeycomb](images/table1.png "Honeycomb") 
 
   -  After creating a board select the board. In this guide a board “Requests details” has been already created. Give a name for your query ,add description to be more clear and save the query
    
![Honeycomb](images/table2.png "Honeycomb") 
   
   - You can view your boards by clicking the “My Boards” in the team’s main menu in honeycomb UI.

![Honeycomb](images/table4.png "Honeycomb")

   -  You can click on any of the boards and run the query for that particular instant.
   
![Honeycomb](images/table5.png "Honeycomb")

## About Honeycomb
The observability is being achieved by sending traces to the honeycomb UI, in which various queries are executed in order to analyse various conditions where the service is being used by the clients. 
 
 Traces refers to the series of the flow of events that occurs when a request is being made and a response is given back. 

![Honeycomb](images/spans2.png "Honeycomb")

For example a client requesting data from the database as above.
E refers to an event.
A trace is the path from E1 to E4.

Traces are further broken down into spans. 
Spans can be defined as a single operation, i.e server requesting from database to obtain data and receiving it (E2+E3). 
Spans contain data which can be used for interpreting the performance.

These traces contains metadata (span data) which can be captured by honeycomb and be shown graphically or in raw data.

#### Honeycomb open-tracing proxy

Honeycomb works with the data collected in Zipkin format. This proxy will run in your local machine, collects the zipkin formatted trace data and sends to honeycomb. 

![Honeycomb](images/structure.png "Open tracing")
