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