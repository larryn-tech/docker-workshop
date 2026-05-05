# Analytics Engineering

An analytics engineer is a professional who acts as a bridge between data engineers and data analysts, transforming raw data into clean, tested, and well-documented datasets for business use. They apply software engineering best practices, such as version control and data modeling, to the efforts of data analysts and data scientists using tools like dbt and SQL.

An engineer may be involved in:
- **Data loading** using tools like Fivetran and Stitch
- **Data storing** using cloud data warehouses
- **Data modeling** using tools like dbt or Dataform
- **Data presentation** using BI tools like Google Looker Studio

## Kimball dimensional modeling

**Kimball Dimensional Modeling** is a popular approach used in data warehousing and business intelligence (BI) to design databases in a way that makes it easier for users to query and analyze data. The methodology was pioneered by Ralph Kimball and focuses on prioritizing user understandability and query performance over non-redundant data (3NF).

In dimensional modeling, data is organized into facts and dimensions:
- **Facts** are the measurements, metrics or facts of a business process
- **Dimensions** are corresponds to a business entity and provides context to a business process

A central fact table connects to surrounding dimension tables in a starburst or star shape, which is where the name **star schema** comes from.

## Architecture of dimensional modeling 

Data flows through a ware house in three stages:

1. **Stage area**
    - Contains the raw data
    - Not meant to be exposed to everyone

2. **Processing area**
    - From raw data to data models
    - Focuses on efficiency
    - Ensures standards

3. **Presentation area**
    - Final presentation of the data
    - Exposure to business stakeholders

## dbt

**dbt (data build tool)** is an ELT tool that allows data engineers to transform raw data within their warehouse using software engineering best practices, such as modularity, documentation, version control, testing, and CI/CD. With dbt, pipelines are easier to maintain and are less prone to breaking in production.

Transformations are defined using SQL or Python, which dbt then compiles, runs against the warehouse, manages dependencies, and persists the results as tables or views.

The `dbt run` command will:
1. Compile your SQL (resolves `ref()` calls, `source()` calls, Jinja macros, etc.)
2. Sends the compiled SQL to your warehouse
3. Materializes the result as a table, view, incremental table, or ephemeral CTE

Rather than writing a `CREATE TABLE` statement, you just use `SELECT` and dbt handles the rest.

### Project structure

dbt projects are organized using a top-level structure. The following files and directories are automatically created when we run `dbt init`.

#### Top-level files & folders

##### `analysis/`
 - Stores ad-hoc SQL scripts
 - Serves as a way to organize analytical SQL queries, such as data quality reports or administrative checks

##### `dbt_project.yml`
- Indicates to dbt that the directory is a dbt project
- Contains information, such as:
    - Project name
    - Profile name
    - Default materializations
    - Variables
    - project-wide defaults and configurations

##### `macros/`
- Contains reusable blocks of code stored in `.sql` files
- Made possible by combining SQL with a templating language called **Jinja**, which provides a programming environment for SQL
- Common use cases:
    - Calendar conversions (e.g. converting standard dates to a company's fiscal calendar)
    - Tax rates or regulatory definitions that might change over time
    - Any reusable business logic that shouldn't be duplicated across models

##### `models/`
- Stores SQL transformation logic for turning raw data into a dataset ready for analytics or an intermediate step
- Organized as three layers (described below)

##### `seeds/`
- Stores CSV or flat files that can be loaded as dbt models
- Useful for:
    - Lookup tables
    - Quick experiments or prototypes
    - Previewing before fully committing to a data load
- Preferable to load data properly at the source instead

##### `snapshots/`
- Keeps a history of table state that can be referred to later
- Like seeds, this is a workaround and ideally handled at the source

##### `tests/`
- Stores singular tests written as SQL assertions

#### `models` subfolders

dbt suggests organizing models into three layers:

##### `staging/`
- Contains:
    - **Source definitions** - tells dbt where raw data is located in the database
    - **Staging models** - contains a 1:1 copy of each source table with only *minimal cleaning* applied
- Minimal cleaning means things like:
    - Fixing data types
    - Renaming columns
    - Filtering out clearly empty rows
    - Removing unnecessary columns
    - Standardizing values
- 1:1 copy means the model contains the same number of rows and columns as the raw source

##### `staging/`
- Intermediate between raw data and data ready for end users
- Catch-all for:
    - Complex joins
    - Heavy-duty cleaning or standardization
    - Data quality processing

##### `marts/`
- Stores final, consumption-ready tables
- Only marts should be exposed to BI tools, analysts and business stakeholders
- Typically contains:
    - Tables ready for dashboards
    - Properly modeled, clean tables
    - Often star schemas, but not necessarily

### Anatomy of a dbt model

When executing `dbt run`, we are running a model that will transform our data. Models are primarily written as a `SELECT` statment and saved as a `.sql` file.

Here, we instruct dbt to materialize `my_model.sql` as a table in the database.

```sql
-- my_model.sql

{{
    config(materialized='table')
}}

SELECT *
FROM staging.source_table
WHERE record_state = 'ACTIVE'
```

dbt takes the SQL code above, compiles it, and runs it in the data warehouse. The compiled code would look like this:

```sql
CREATE TABLE my_schema.my_model as (
    SELECT *
    FROM staging.source_table
    WHERE record_state = 'ACTIVE'
)
```

Materialization strategies include:
- Table
- View
- Incremental
- Ephemeral


### Packages

Like libraries in programming languagtes, dbt offers packages that contain models and macros that you can use in your own project, saving you time and effort. Packages are specified in the `packages.yml` file and imported by running `dbt deps`.

```yaml
# packages.yml
packages:
    - package: dbt-labs/dbt_utils
      version: 0.8.0
```

We can then use a macro from a package like so:

```sql
-- stg_green_tripdata.sql

SELECT
    {{ dbt_utils.surrogate_key(['vendorid', 'lpep_pickup_datetime]) }} as tripid,
    -- [...]
```

A list of useful packages can be found in [dbt package hub](https://hub.getdbt.com/).


### Variables

In dbt, variables allow you to create resusable pieces of code and define configurable values for your project instead of hardcoding them in SQL. We can provide data to models for compilation with variables and macros.

To use a variable, we use the `{{ var('..') }}` function:


```yaml
-- my_model.sql

SELECT *
FROM my_table

{% if var('is_test_run', default=true) %}
    limit 100
{% endif %}
```


Variables can be defined in the `dbt_project.yml` file:

```yaml
# dbt_project.yml

vars:
    is_test_run: true
```

or in the command line.

```shell
dbt build --select stg_nyc_taxi__GREEN_TAXI_TRIPS_RAW.sql --vars 'is_test_run: false'
```