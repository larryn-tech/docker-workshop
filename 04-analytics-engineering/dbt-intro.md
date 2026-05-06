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
- **Dimensions** correspond to a business entity and provides context to a business process

A central fact table connects to surrounding dimension tables in a star shape, which is where the name **star schema** comes from.

## Architecture of dimensional modeling 

Data flows through a warehouse in three stages:

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

##### `intermediate/`
- Acts as the bridge between raw staging data and final business entities.
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

When executing `dbt run`, we are running a model that will transform our data. Models are primarily written as a `SELECT` statement and saved as a `.sql` file.

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

dbt takes the SQL code above, compiles it, and runs it in the data warehouse. It wraps the `SELECT` in a `CREATE VIEW` or `CREATE TABLE` depending on the config. Since dbt handles the DDL (Data Definition Language), we can focus on the logic.

The compiled code would look like this:

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
      version: [">=1.3.0", "<2.0.0"]
```

We can then use a macro from a package like so:

```sql
-- stg_green_tripdata.sql

SELECT
    {{ dbt_utils.generate_surrogate_key(['vendorid', 'lpep_pickup_datetime']) }} as tripid,
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

### dbt-codegen

`dbt-codegen` is an official dbt Labs package that helps with the generating boilerplate code for sources, base models, and documentation. Rather than having to manually write the YAML files for our sources and models, the package can auto-generate the SQL and YAML code for them. In addition to saving time and reducing errors, this helps with the testing and documentation processes described in the following sections.

To install, add the package to `packages.yml` and run `dbt deps` to install:

```yaml
# packges.yml

packages:
  - package: dbt-labs/codegen
    version: 0.12.1
```

To generate the `source.yml`, enter of the macros below into a new tab in the dbt IDE and compile the code:

```
{{ codegen.generate_source('<source_name>') }}


# Multiple arguments included
{{ codegen.generate_source(schema_name= '<schema_name>', database_name= '<database_name>') }}
```

```yaml
# Example output

version: 2

sources:
  - name: raw_jaffle_shop
    database: raw
    schema: raw_jaffle_shop
    tables:
      - name: customers
        description: ""
      - name: orders
        description: ""
      - name: payments
        description: ""
```

The output can be copied directly into your `source.yml` file.

Once the sources are defined, we can generate the SQL for a base model with:

```
{{ codegen.generate_base_model(
    source_name='<source_name>',
    table_name='<table_name>',
    materialized='table'
) }}
```

```sql
-- Example output

with source as (
    select * from {{ source('raw_jaffle_shop', 'customers') }}
),

renamed as (

    select
        id,
        first_name,
        last_name,
        email,
        _elt_updated_at

    from source

)

select * from renamed
```


Finally, we can generate the YAML for our models with:

```shell
# Generate YAML for a single model
{{ codegen.generate_model_yaml(
    model_names=['customers']
) }}

# Generate YAMLs for multiple models matching a directory and/or prefix
{% set models_to_generate = codegen.get_models(directory='<directory>', prefix='<prefix>') %}
{{ codegen.generate_model_yaml(
    model_names = models_to_generate
) }}
```
```yaml
# Example output

version: 2

models:
  - name: customers
    description: ""
    columns:
      - name: customer_id
        data_type: integer
        description: ""
      - name: customer_name
        data_type: text
        description: ""
```

### Testing

dbt tests are essentially SQL queries that return the rows that fail a certain assertion; if the query returns zero rows, the test passes.

#### Generic tests

dbt comes with four built-in "generic" tests that can be applied directly in  `.yml` files:

- `unique`: Ensures every value in a column is distinct (useful for checking primary keys)

- `not_null`: Confirms there are no missing values in a required column

- `accepted_values`: Validates that a column only contains values from a predefined list

- `relationships`: Ensures referential integrity by checking that a value in one table exists in another

Tests are defined on a column in the `.yml` file. For example:

```yaml
version: 2

models:
  - name: stg_nyc_taxi__GREEN_TAXI_TRIPS_RAW
    description: "Staged green taxi data with basic cleaning and surrogate keys."
    columns:
      - name: tripid
        description: "Primary key for the trip, generated by dbt_utils."
        tests:
          - unique:
              severity: warn
          - not_null:
              severity: warn

      - name: payment_type_description
        description: "Description of the payment_type code"
        tests:
          - accepted_values:
              values: [1, 2,3,4,5]
              severity: warn

      - name: pickup_location_id
        description: "location id where the meter was engaged"
        tests:
          - relationships:
              to: ref('dim_zones')
              field: location_id
              severity: warn
```

The compiled code of the `not_null` test for `tripid` would look like this:

```sql
SELECT *
FROM "PRODUCTION"."DBT_LNGUYEN"."stg_nyc_taxi__GREEN_TAXI_TRIPS_RAW"
WHERE tripid IS NULL
```


#### Custom tests and open-source packages

You can create your own generic tests in SQL and store them in `tests/generic`.

```sql
-- tests/generic/test_positive_values.sql

{% test positive_values(model, column_name) %}

select *
from {{ model }}
where {{ column_name }} < 0

{% endtest %}
```

We can then use them in the `schema.yml` file:

```yaml
models:
  - name: fct_trips
    columns:
      - name: fare_amount
        tests:
          - positive_values
      
      - name: trip_distance
        tests:
          - positive_values
```

Often, we can find tests in open-source packages (such as `dbt-utils` and `dbt-expectations`) rather than creating our own. Community-built tests can be found on dbt Hub, the dbt Slack, and GitHub.


#### Unit tests

dbt v1.8 introduced unit tests, which allows us to test our SQL logic without having to materialize the full model in the data warehouse. Instead, we provide a set of mock input rows and exepected output rows and dbt runs the model's SQL against those mocks and checks whether the output matches the rows specified.

Unit tests are useful for complex logic, such as:
- Regex
- Date math
- Window functions
-  `case when` statements when there are many `when`s
- Truncation

Unit tests are defined in the `models/` directory as `.yml` files.

```yaml
version: 2

unit_tests:
  - name: test_payment_type_mapping
    description: Test that payment type codes map to correct descriptions
    model: stg_green_tripdata
    given:
      - input: source('staging', 'green_tripdata')
        rows:
          - {tripid: '1', payment_type: 1}
          - {tripid: '2', payment_type: 2}
          - {tripid: '3', payment_type: 5}
    expect:
      rows:
        - {tripid: '1', payment_type_description: 'Credit card'}
        - {tripid: '2', payment_type_description: 'Cash'}
        - {tripid: '3', payment_type_description: 'Unknown'}
```


#### Running a test

We can run all tests in the project or a specific model using the following commands:

```shell
# Run all tests in the project
dbt test

# Run tests only for a specific model
dbt test --select stg_nyc_taxi__GREEN_TAXI_TRIPS_RAW
```
Warnings from the test would be displayed in the CLI.


## Documentation

Documentation is an important feature in dbt, as it ensures that every stakeholder understands where a piece of data comes from and how it was calculated. Descriptions can be embeded directly into the `.yml` files and be used by dbt to generate an interative website that serves as a single source of truth.

### Descriptions

Almost everything in dbt can be documented. The structure is the same pattern regardless of what you're documenting:

#### Sources

```yaml
version: 2

sources:
  - name: staging
    description: >
      Raw NYC taxi trip data loaded from BigQuery external tables.
      Contains both yellow and green taxi trip records for 2019-2020.
    database: production
    schema: trips_data_all
    
    tables:
      - name: green_tripdata
        description: >
          Green taxi trip records. Green taxis operate primarily in
          outer boroughs (outside Manhattan).
          
      - name: yellow_tripdata
        description: Yellow taxi trips, primarily from Manhattan
```

#### Models

```yaml
version: 2

models:
  - name: dim_zones
    description: >
      Zone lookup table containing LocationID, borough, zone name and service zone.
      One row per taxi zone in NYC.
    columns:
      - name: locationid
        description: Primary key for taxi zones
        tests:
          - unique
          - not_null
      
      - name: borough
        description: NYC borough name (Manhattan, Queens, Brooklyn, Bronx, Staten Island, EWR)
      
      - name: zone
        description: Taxi zone name/neighborhood
      
      - name: service_zone
        description: Service zone type (Yellow, Green, or Airports)
```

The following values can be listed with each column:
- `name` — Column name (must match)
- `description` — Description of the column
- `data_type` — Column type (informational, not enforced)
- `tests` — Tests to apply to column
- `meta` — Custom key-value tags 


### dbt Docs

Key components of dbt Docs include:

- **Descriptions**: You can add a `description` field to any model, column, source, or seed in your YAML files. These descriptions are then compiled into the final documentation.

- **Doc Blocks**: For complex business logic that requires longer explanations, dbt supports doc blocks using Markdown files (.md). This allows you to write detailed, formatted documentation that can be reused across multiple models.

- **The Lineage Graph**: dbt automatically generates a Directed Acyclic Graph (DAG) that visualizes your data’s journey from raw source to final analytics table.

#### Generating and serving docs

To build the documentation site, we can run the following commands:

```shell
# 1. Compile all metadata into a JSON file
dbt docs generate

# 2. Start a local web server to view the interactive site
dbt docs serve
```
