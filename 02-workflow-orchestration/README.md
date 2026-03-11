# Module 2: Workflow Orchestration

[Kestra](https://kestra.io/) is an open-source data orchestration platform that allows engineers to build, schedule, and monitor complex data workflows. Pipelines can be configured to run on a fixed schedule or respond to real-time, event-based triggers. Kestra follows an Infrastructure as Code (IaC) pattern, as workflows are defined declaratively in YAML. This approach enables version control, modularity, and seamless collaboration.

In this module, we will learn how to install Kestra, review key concepts, and use Kestra to build ETL (Extract, Transform, Load) pipelines.

## Installing Kestra

Kestra can be installed using Docker. We'll add to our `docker-compose.yml` file from Module 1.

```dockerfile
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


```dockerfile
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
| Concurrency       | Ccontrol how many executions of a flow can run at the same time. |

**Flows** serve as the blueprints for the workflows. They contain a set of tasks, their inputs and outputs, and orchestration logic. Flows specify what tasks to run, when they should run, and how they intereact.

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

**Variables** are stored at the namespace level and can be reused across that namespace's multiple flows. Here, we pass the `name` input into a `welcome_message` variable, allowing us to change the message. One example where chaining an input into a variable is particularly powerful is managing API endpoints. By passing a `region` or `version` input into a namespace-level URL variable, you ensure that downstream tasks always point to the correct resource without hardcoding strings into every individual flow.

We see our `welcome_message` variable be used in the `hello_message` log task.

```yaml
tasks:
  - id: hello_message
    type: io.kestra.plugin.core.log.Log
    message: "{{ render(vars.welcome_message) }}"
```

The `render()` function is used when a variable or input contains another expression that needs to be evaluated. Here, our `welcome_message` variable is wrapped in `render()`, which ensures that `{{ inputs.name }}` is evaluated before `welcome_message` is. 

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

**Plugins defaults** allow us to apply default values to every task of a given type, helping us avoid repetition. We use a plugin default to assign an `ERROR` level to all of our logs.

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


[02-kc-01]: ../img/02-kc-01.png
[02-kc-02]: ../img/02-kc-02.png
[02-kc-03]: ../img/02-kc-03.png
[02-kc-04]: ../img/02-kc-04.png