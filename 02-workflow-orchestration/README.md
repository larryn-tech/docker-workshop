# Module 2: Workflow Orchestration

[Kestra](https://kestra.io/) is an open-source data orchestration platform that allows engineers to build, schedule, and monitor complex data workflows. Pipelines can be configured to run on a fixed schedule or respond to real-time, event-based triggers. Kestra follows an Infrastructure as Code (IaC) pattern, as workflows are defined declaratively in YAML. This approach enables version control, modularity, and seamless collaboration.

In this module, we will learn how to install Kestra, review key concepts, and use Kestra to build ETL (Extract, Transform, Load) pipelines.

## Installing Kestra

Kestra can be installed using Docker. We'll add to our `docker-compose.yml` file from Module 1.

```yaml
# docker-compose.yml
volumes:
  ny_taxi_postgres_data:
    driver: local
  kestra_postgres_data:
    driver: local
  kestra_data:
    driver: local
  kestra_tmp:
    driver: local

# [services]
```

We'll set up the volumes for persisting the metadata and internal storage for Kestra.


```yaml
# docker-compose.yml

# [volumes]

services:
#  pgdatabase:
#    [...]

#  pgadmin:
#    [...]

  kestra_postgres:
    image: postgres:18
    volumes:
      - kestra_postgres_data:/var/lib/postgresql
    environment:
      POSTGRES_DB: kestra
      POSTGRES_USER: kestra
      POSTGRES_PASSWORD: k3str4
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -d $${POSTGRES_DB} -U $${POSTGRES_USER}"]
      interval: 30s
      timeout: 10s
      retries: 10

  kestra:
    image: kestra/kestra:v1.1
    pull_policy: always
    user: "root"
    command: server standalone
    volumes:
      - kestra_data:/app/storage
      - /var/run/docker.sock:/var/run/docker.sock
      - kestra_tmp:/tmp/kestra-wd
    environment:
      KESTRA_CONFIGURATION: |
        datasources:
          postgres:
            url: jdbc:postgresql://kestra_postgres:5432/kestra
            driverClassName: org.postgresql.Driver
            username: kestra
            password: k3str4
        kestra:
          server:
            basicAuth:
              username: "admin@kestra.io" # it must be a valid email address
              password: Admin1234!
          repository:
            type: postgres
          storage:
            type: local
            local:
              basePath: "/app/storage"
          queue:
            type: postgres
          tasks:
            tmpDir:
              path: /tmp/kestra-wd/tmp
          url: http://localhost:8080/
    ports:
      - "8080:8080"
      - "8081:8081"
    depends_on:
      kestra_postgres:
        condition: service_started
```

In total, we'll have four containers:
- `kestra`: Orchestration engine
- `kestra_postgres`: Database dedicated to storing Kestra data
- `pgadmin`: Allows us to view data in the Postgres databases
- `pgdatabase`: Database for storing data from our data pipelines

To start the server, use the following command:

```shell
docker compose up -d
```

Once installed, open http://localhost:8080 to access Kestra's UI and log in with the username `admin@kestra.io` and password `Admin1234!`.

## Key Concepts

| Concept           | Description |
| --                | -- |
| Flow              | Container for tasks and their orchestration logic. |
| Tasks             | The steps within a flow. |
| Inputs            | Dynamic values passed to the flow at runtime. |
| Outputs           | Lets you pass data between tasks and flows. |
| Triggers          | Mechanism that automatically starts the execution of a flow. |
| Execution         | A single run of a flow with a specific state. |
| Variables         | Key–value pairs that let you reuse values across tasks. |
| Plugin Defaults   | Default values applied to every task of a given type within one or more flows. |
| Concurrency       | Control how many executions of a flow can run at the same time. |

**Flows** serve as the blueprints for the workflows. They contain a set of tasks, their inputs and outputs, and orchestration logic. Flows specify what tasks to run, when they should run, and how they interact.

To create a flow, click on the `+ Create Flow` button in the Kestra UI. We should see a new flow generated with sample code populated. 

```yaml
id: marten_822392
namespace: company.team

tasks:
  - id: hello
    type: io.kestra.plugin.core.log.Log
    message: Hello World! 🚀
```

Every flow must have an identifier (`id`), a `namespace`, and a list of `tasks`. When we click on `Save`, the `id` and `namespace` can no longer be modified. To change them, a new flow would need to be created. `tasks`, on the other hand, can be changed as many times as we'd like.

**Tasks** are the steps, or actions, within a flow. They can process inputs and variables and produce outputs for downstream consumption. With the Documentation panel open, we can click on a task to view information about the task type, including a description of what it does, examples, and required and/or optional properties and their possible values.

![02-kc-01]

We'll replace the sample flow provided by Kestra by copying and pasting the code from the `01_hello_world.yml` file located in the `02-workflow-orchestration/flows` folder.

With **inputs**, we can pass data into our workflow at the start of an execution. This allows us to parameterize our flows and perform multiple executions of the same flow with different values. In our example, we create a string variable called `name` with a default value of `Will`.

```yaml
inputs:
  - id: name
    type: STRING
    defaults: Will
```

When we click on `Execute`, we'll be able to enter a new value for our `name` input or keep the default value.

![02-kc-02]

Inputs are accessed with `{{ inputs.parameter_name }}`. For example:

```yaml
variables:
  welcome_message: "Hello, {{ inputs.name }}!"
```

**Variables** are stored at the namespace level and can be reused across that namespace's multiple flows. Inputs are provided by the user at runtime, while variables are internal to the flow's logic. Here, we pass the `name` input into a `welcome_message` variable, allowing us to change the message. One example where chaining an input into a variable is particularly powerful is managing API endpoints. By passing a `region` or `version` input into a namespace-level URL variable, you ensure that downstream tasks always point to the correct resource without hardcoding strings into every individual flow.

We see our `welcome_message` variable be used in the `hello_message` log task.

```yaml
tasks:
  - id: hello_message
    type: io.kestra.plugin.core.log.Log
    message: "{{ render(vars.welcome_message) }}"
```

The `render()` function is used when a variable or input contains another expression that needs to be evaluated. Without `render()`, Kestra would simply print the string `"Hello, {{ inputs.name }}!"`. Using `render(vars.welcome_message)` tells Kestra to look inside the variable and resolve any internal brackets first.

Tasks can store data in Kestra’s internal storage. **Outputs** allow us to retrieve the data and pass them between tasks and flows. 

```yaml
tasks:
  - id: generate_output
    type: io.kestra.plugin.core.debug.Return
    format: I was generated during this workflow.
```

The `generate_output` task returns a string as a `value` output for debugging. Outputs are accessed using `{{ outputs.output_task_id.attribute }}`. In the task below, we log the output from `generate_output`.

```yaml
tasks:
  - id: log_output
    type: io.kestra.plugin.core.log.Log
    message: "This is an output: {{ outputs.generate_output.value }}"
```

We can view all of the outputs generated from the execution of a workflow in the **Outputs** tab of the **Executions** section.

![02-kc-03]

**Plugin defaults** allow us to apply default values to every task of a given type, helping us avoid repetition. We use a plugin default to assign an `ERROR` level to all of our logs.

```yaml
pluginDefaults:
  - type: io.kestra.plugin.core.log.Log
    values:
      level: ERROR
```

When we navigate to the **Logs** tab within our flow, we can see that the each of our three log tasks are tagged `ERROR`.

![02-kc-04]

**Triggers** are used to automatically start the execution of a flow. They can be scheduled to execute on a regular cadence or event-based. In our case, we schedule our `01_hello_world` flow to execute every day at 10 AM. We also change our `name` input from `Will` to `Sarah`. Currently, we have the trigger disabled.

```yaml
triggers:
  - id: schedule
    type: io.kestra.plugin.core.trigger.Schedule
    cron: "0 10 * * *"
    inputs:
      name: Sarah
    disabled: true
```

Lastly, we have **concurrency**. This component lets us limit the number of executions a flows can run at the same time. We can control what happens when we reach this limit, either queue, cancel, or fail.

```yaml
concurrency:
  behavior: FAIL
  limit: 2
```

## Creating Pipelines in Kestra

### ETL vs ELT

**Extract, transform, and load (ETL)** and **extract, load, and transform (ELT)** are two approaches for integrating and processing data for analysis. 

**ETL** involves extracting raw data into a staging area, where it is transformed before being loaded into a target database. In `flows/03_getting_started_data_pipeline.yaml`, we extract JSON data via an HTTP request, transform the data to keep the data we need using Python, and load the modified data into DuckDB for querying.

With **ELT**, transformations to the data occurs *after* it has been loaded into the destination storage in its raw form. `flows/04_postgres_taxi.yaml` contains the flow code for a pipeline that extracts the NYC taxi data for the month and year we select and loads the data into a Postgres staging table. From there, we transform the data by adding a unique ID and the originating filename for each row before merging them into a final main table. `flows/05_postgres_taxi_scheduled.yaml` builds on this logic by adding a schedule trigger to automate the workflow daily.

These flows implement some of the key concepts mentioned above to outline our tasks, parameterize the workflows, limit the number of concurrent executions, and automatically run the workflows. The ELT flows utilize **conditions** to determine which tasks to execute based on which inputs we entered when executing a flow.

```yaml
# 04_postgres_taxi.yaml
tasks:
  - id: if_yellow_taxi
    type: io.kestra.plugin.core.flow.If
    condition: "{{inputs.taxi == 'yellow'}}"
    then:
      # Tasks for creating tables and ELT for yellow taxi data 

  - id: if_green_taxi
    type: io.kestra.plugin.core.flow.If
    condition: "{{inputs.taxi == 'green'}}"
    then:
      # Tasks for creating tables and ELT for green taxi data 
```

### ELT with AWS

One advantage of the ELT approach is that the raw data is preserved, allowing us to interact with and transform it repeatedly without having to extract the data again. ELT also allows us to leverage the computing power of our destination data warehouse (AWS in our case) to perform the transformations.

In this section, we will adapt our ELT flow for AWS. Rather than using a local Postgres database, our updated pipeline will:
- Load the raw CSV files directly into an Amazon S3 bucket
- Query the S3 data using AWS Athena to establish staging and main tables for both yellow and green taxis
- Transform the monthly data within the staging tables by adding unique row IDs and originating filename
- Merge the modified data into the main tables, resulting in one complete dataset for each taxi type

#### Updating user group permissions

In AWS, navigate to IAM and add AmazonAthenaFullAccess to the user group's permissions.

#### KV store

Kestra's key-value (KV) store helps us add information to our flows without having to directly hardcode it there. Information is still stored as plaintext, so sensitive information or credentials **should not** be stored here. We'll use `flows/06_aws_kv.yaml` to store our region, S3 bucket name, and database name.

After we execute the flow in Kestra, we should see the key-value pairs added to the KV Store.

![02-cp-01]

#### Environment variables

Create a `.env` file in the same directory as our `docker-compose.yml`. Make sure that this file is added to `.gitignore` and is not being tracked or committed. Add the AWS credentials to the file.

```shell
# .env
AWS_ACCESS_KEY_ID=ENTER_SERVICE_ACCOUNT_ACCESS_KEY_ID_HERE
AWS_SECRET_ACCESS_KEY=ENTER_SERVICE_ACCOUNT_SECRET_ACCESS_KEY_HERE
```

We'll add these variables to our `docker-compose.yml` so that Kestra can access them.

```yaml
# docker-compose.yml

kestra:
    # [...]

    environment:
      AWS_ACCESS_KEY_ID:
      AWS_SECRET_ACCESS_KEY:
      KESTRA_CONFIGURATION: 
        # [...]
```

Restart your containers with `docker-compose down` and `docker-compose up -d` to make the environment variables available to use.

#### Create S3 bucket

In `flows/07_aws_setup.yaml`, we use a plugin to create an S3 bucket to store our raw and transformed data. We specify the bucket name and region using the values we stored in the KV store.

```yaml
id: 07_aws_setup
namespace: zoomcamp

tasks:
  - id: create_s3_bucket
    type: io.kestra.plugin.aws.s3.CreateBucket
    bucket: "{{kv('AWS_BUCKET_NAME')}}"
    region: "{{kv('AWS_REGION')}}"
```

#### Workflows

`flows/08_aws_taxi.yaml` and `flows/09_aws_taxi_scheduled.yaml` are similar to the ELT pipelines we created earlier, except we are using AWS S3 and Athena instead of Postgres. 

> **Note**: Google Gemini was used to generate the AWS version of these files (the course uses Google Cloud). While I did review the code and the flows appear to be executing as expected, there may be a more efficient way to create the flows.

When we execute one of the flows for the October 2020 taxi data, by either inputting the month and year for `08_aws_taxi` or using backfill for `09_aws_taxi_scheduled`, the Gantt chart for the execution should look something like this:

![02-cp-02]

We see that the `if_green_taxi` task took the longest (~12s), followed by merging the tables and then uploading the data to S3.

In AWS, our S3 bucket should now have the raw CSV file containing data for October 2020. 

![02-cp-03]

We can also use Athena to query our main and staging tables.

![02-cp-04]

When we query the total number of rows from `green_tripdata` and `green_tripdata_2020_10`, we'll see that each table has 95,120 rows. After executing the flow again, this time for November 2020, we get a total of 183,725 rows when we query `green_tripdata`. This difference of 88,605 matches the number of rows in `green_tripdata_2020_11`, indicating that the merge is working as expected.




[02-kc-01]: ../img/02-kc-01.png
[02-kc-02]: ../img/02-kc-02.png
[02-kc-03]: ../img/02-kc-03.png
[02-kc-04]: ../img/02-kc-04.png
[02-cp-01]: ../img/02-cp-01.png
[02-cp-02]: ../img/02-cp-02.png
[02-cp-03]: ../img/02-cp-03.png
[02-cp-04]: ../img/02-cp-04.png