# Data Warehouses

## OLAP vs OLTP

**OLTP (Online Transactional Processing)** and **OLAP (Online Analytical Processing)** are different database systems optimized for distinct purposes. OLTP powers day-to-day operations with fast, real-time, row-based transactions (e.g., banking). OLAP enables complex analysis and decision-making, using columnar storage to aggregate large historical datasets.

|  | OLTP | OLAP |
| - | - | - |
| Purpose  | Control and run essential business operations in real time  |  Plan, solve problems, support decisions, discover hidden insights |   
| Data updates | Short, fast updates initiated by user | Data periodically refreshed with scheduled, long-running batch jobs |
| Database design | *Normalized* databses for efficiency | *Denormalized* databases for analysis |
| Space requirements | Generally small if historical data is archived | Generally large due to aggregating large datasets |
| Backup and recovery | Regular backups required to ensure business continuity and meet legal and governance requirements | Lost data can be reloaded from OLTP database as needed in lieu of regular backups |
| Productivity | Increases productivity of end users | Increases productivity of business managers, data analysts, and executives |
| Data view | Lists day-to-day business transactions | Multi-dimensional view of enterprise data |
| User examples | Customer-facing personnel, clerks, online shoppers | Knowledge workers, such as data analysts, business analysts, and executives |

## What is a data warehouse?

A **data warehouse** is an OLAP solution used for reporting and data analysis. It serves as a centralized repository that aggregates data from multiple sources and generally consists of raw data, meta data, and summary data.

![Data warehouse architecture](https://upload.wikimedia.org/wikipedia/commons/8/8d/Data_warehouse_architecture.jpg)

*Image courtesy of [Soha jamil via Wikimedia Commons](https://commons.wikimedia.org/wiki/File:Data_warehouse_architecture.jpg)*

A **data mart** is a focused, subset of a data warehouse, designed to serve the specific needs of a particular department or business unit (e.g., Purchasing, Sales, or Inventory). It acts as a curated repository of data, enabling faster insights, increased user performance, and easier access compared to searching a complex, enterprise-wide data warehouse.

Original data warehouses were hosted on-premises. While they do offer some advantages in improved latency and security over sensitive data and hardware, on-premise data warehouses come with high upfront costs, rigid scalability, and manual installation and maintenance. In contrast, cloud-based warehouses like Snowflake, Google BigQuery, Amazon Redshift, and Databricks allow organizations to scale operations elastically with high availability. These modern platforms follow a pay-as-you-go model and offload infrastructure maintenance, patching, and hardware management to the service provider.

## Snowflake

Snowflake is a cloud-native, data platform that brings together data storage, processing, and analysis. As a fully-managed SaaS (software as a service), Snowflake uses public cloud infrastructure (Google Cloud, Microsoft Azure, and AWS) to host virtual compute instances and persistent data storage. It handles all aspects of authentication, configuration, resource management, data protection, availability, and optimization. 

It also allows enterprises to build data pipelines, perform data analysis, create and deploy LLMs and ML models, and develop and distribute apps.

### Architecture

Snowflake uses a multi-cluster shared data architecture that is designed specifically for the cloud. The architecture features three key layers:
- Database storage
- Compute
- Cloud services

![Snowflake architecture](https://docs.snowflake.com/en/_images/architecture-overview.png)

By decoupling the storage, compute, and managment layers, each layer can be scaled independently of one another. We can scale vertically by increasing the size of our warehouse to better handle complex queries. We can also scale horizontally by adding more clusters to improve concurrency.

#### Database storage layer

Snowflake supports structured (e.g. tables), semi-structured data (e.g. JSON and XML), and unstructured data (e.g. image or audio). Data is structured in a compressed, columnar format when loaded into a Snowflake table.

Data is automatically divided into **micro-partitions** to improve efficiency. Snowflake also manages the organization, file size, structure, compression, metadata, and statistics of stored data.

#### Compute layer

Snowflake uses clusters of compute resources to process SQL statements and run code in languages, such as Java, Python, and Scala. Each cluster, referred to as a **virtual warehouse**, acts independently and doesn’t share compute resources with other clusters.

When processing a SQL statement, we select which virtual warehouse we want to use. The virtual warehouse will then make a remote call to the data storage layer, where it will retrieve the raw table data and store it on a local cache before computing our results.

Virtual warehouses can be created or dropped instantly. They can also be paused and resumed. They will only incur costs when in the resume state. They also come in various sizes.

#### Cloud services layer

The cloud services layer manages a collection of stateless services that are responsible for tasks including:
- Security, authentication, and access control
- Infrastructure management with cloud platforms
- Metadata management
- Query parsing and optimization

### Databases
Databases must have a unique identifier in an account. The identifier must start with a letter and cannot contain spaces or special characters unless enclosed in double quotes.

Databases can be created:
1. by using the following SQL statement:

```sql
CREATE DATABASE my_database;
```

2. by cloning a different database in the same account:

```sql
CREATE DATABASE my_db_clone CLONE my_test_db;
```

3. by replicating it into another account:

```sql
CREATE DATABASE mydb1
    AS REPLICA OF myorg.account1.mydb1
    DATA_RETENTION_TIME_IN_DAYS = 10;
```

4. from a shared object created by another account:

```sql
CREATE DATABASE shared_db FROM SHARE utt783.share;
```

### Schemas

Schemas must have a unique identifier in a database. The identifier must start with a letter and cannot contain spaces or special characters unless enclosed in double quotes.

Schemas can be created:
1. by using the following SQL statement:
```sql
CREATE SCHEMA my_schema;
```

2. by cloning a different schema in the same account:

```sql
CREATE SCHEMA my_schema_clone CLONE my_test_schema;
```

The database and schema names together form a namespace in Snowflake (ex. `my_database.my_schema`). Prepending the namespace to a table allows you to globally access that table.

### Tables

The various table types in Snowflake differ primarily in persistence, visibility, Time Travel, and Fail-safe capabilities. **Time Travel** allows users to query, clone, or restore deleted or modified data within a 0 - 90 day retention period (configurable by edition). **Fail-safe** refers to a 7-day emergency recovery period that occurs after Time Travel ends, accessible only by Snowflake support.

The three primary table types are permaent, temporary, and transient.

| | Permanent | Temporary | Transient |
| - | - | - | - |
| Persistence | Exists until explicitly removed | Persists for session duration | Exists until explicitly removed
| Uses | Default table type | Transitory data | Staging |
| Time Travel | 90 days | 1 day | 1 day |
| Fail safe | ✔ | | |

Other table types include:
- **External** - read-only tables whose files are stored outside of Snowflake (i.e. AWS S3 or Google Cloud Storage)
- **Hybrid** - supports OLTP and OLAP, uses a row-based storage engine that supports row locking for high concurrency, and enforces unique and referential integrity constraints
- **Iceberg** - uses Apache Iceberg table format and allows you to manage cloud data from within Snowflake

### Views

A view allows the result of a query to be accessed as if it were a table. They offer a way to simplify complex queries, restrict contents of a table, and improve performance in some cases.

A **standard view** does not store data. Instead, the underlying query runs every time the view is accessed. As a result, they do not contribute to storage cost.

```sql
CREATE VIEW as my_view AS
SELECT col1, col2 FROM my_table;
```

**Materialized views** pre-compute and store the result set for faster retrieval. They are useful for frequent, complex queries on large datasets where the results change relatively slowly. They incur storage and automatic background maintenance costs.

```sql
CREATE MATERIALIZED VIEW as my_view AS
SELECT col1, col2 FROM my_table;
```

Both standard and materialized views can be defined as **secure** to hide the underlying query logic and data structure. This is useful when working with sensitive data. Some query optimizations are bypassed to ensure security.

```sql
CREATE SECURE VIEW as my_view AS
SELECT col1, col2 FROM my_table;
```

### Virtual Warehouses

A **virtual warehouse** is a cluster of compute resources in Snowflake. It uses a Massively Parallel Processing (MPP) architecture to execute queries in parallel, dividing tasks across multiple compute nodes for high performance. With MPP, each node in the cluster locally stores a portion of the entire data set.

Virtual warehouses provide the resources needed (e.g. CPU, memory, and temporary storage) to perform:
- SQL `SELECT` statements that require compute resources (ex. retrieving rows from tables and views)
- DML operations, such as `DELETE`,`INSERT`, `UPDATE`
- loading and unloading operations, such as `COPY INTO <table>` and `COPY INTO <location>`

#### Virtual warehouse sizes

Virtual warehouses come in 6 sizes, ranging for X-Small (default) to 6X-Large. In general, query performance scales with warehouse size because larger warehouses have more compute resources available to process queries. The number of credits used per second also doubles at each warehouse size as you scale up. Credits are consumed when warehouses are in the STARTED state.

#### Virtual warehouse state

Virtual warehouses can be in one of three states: started, suspended, and resizing.
- **STARTED** - virtual warehouse is currently active and ready to process queries; currently consuming credits
- **SUSPENDED**  - virtual warehouse is shut down; not currently consuming credits
- **RESIZING** - virtual warehouse is in the process of resizing; can occur at any time without affecting currently running queries

> **NOTE**: By default, warehouses are in the STARTED state when created.

#### SQL Statements

```sql
-- Create a warehouse
CREATE WAREHOUSE my_warehouse;

-- Create a X-Large warehouse
CREATE WAREHOUSE my_xlarge_warehouse
WITH WAREHOUSE_SIZE='X-SMALL';

-- Use a warehouse
USE WAREHOUSE my_warehouse;

-- Suspend a warehouse and remove all its compute nodes
ALTER WAREHOUSE my_warehouse SUSPEND;

-- Specify seconds of inactivity before automatically suspending warehouse
CREATE WAREHOUSE my_warehouse
AUTO_SUSPEND=300; --600 by default (10 minutes)

-- Specify whether submitting a SQL statement automatically resumes a warehouse 
CREATE WAREHOUSE my_warehouse
AUTO_RESUME=TRUE; --TRUE by default

-- Specify whether to start the warehouse in the SUSPENDED state when created
CREATE WAREHOUSE my_warehouse
INITIALLY_SUSPENDED=TRUE; --FALSE by default

-- Resume a warehouse
ALTER WAREHOUSE my_warehouse RESUME;

-- Show warehouses with information about their state, type, and size
SHOW WAREHOUSES;
```

## Resources
- [Snowflake key concepts and architecture](https://docs.snowflake.com/en/user-guide/intro-key-concepts) - Snowflake Documentation
- [Learn Snowflake – Full 1-Hour Crash Course for Complete Beginners](https://www.youtube.com/watch?v=2t-ls6ekA8E) - YouTube video from [Tom Bailey](https://www.youtube.com/@tombaileycourses)