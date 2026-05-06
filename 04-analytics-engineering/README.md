# dbt

**dbt (data build tool)** is a framework that allows data engineers to transform data directly within their warehouse using software engineering best practices like modularity, version control, and automated testing. By combining SQL with Jinja templating, dbt enables the creation of reusable, maintainable, and self-documenting data pipelines.

In this module, we implement an ELT workflow to convert raw NYC Green Taxi records into a structured Star Schema. Our process involves:

- Staging: Cleaning and standardizing raw Snowflake data

- Macro Development: Creating reusable Jinja logic to handle complex business rules

- Dimensional Modeling: Utilizing dbt Seeds to ingest taxi zone metadata and performing  joins to create the final Fact and Dimension tables

![04-db-01]

## Snowflake setup

To begin, we will create the resources needed for dbt to connect to Snowflake and access our databases. This includes a:
- Database
- Schema
- Warehouse
- Role with permissions
- User account with role assigned

In **Snowflake**, run the following code:

```sql
CREATE OR REPLACE DATABASE DBT_ANALYTICS;
CREATE OR REPLACE SCHEMA DBT_ANALYTICS.TRANSFORMATIONS;

CREATE OR REPLACE WAREHOUSE DBT_WH 
  WITH WAREHOUSE_SIZE = 'XSMALL' 
  AUTO_SUSPEND = 60 
  AUTO_RESUME = TRUE 
  COMMENT = 'Warehouse for DBT transformations';

CREATE OR REPLACE ROLE dbt_transformer;
GRANT USAGE ON WAREHOUSE DBT_WH TO ROLE dbt_transformer;
GRANT OPERATE ON WAREHOUSE DBT_WH TO ROLE dbt_transformer;

GRANT USAGE ON DATABASE DBT_ANALYTICS TO ROLE dbt_transformer;
GRANT MODIFY ON DATABASE DBT_ANALYTICS TO ROLE dbt_transformer;
GRANT MONITOR ON DATABASE DBT_ANALYTICS TO ROLE dbt_transformer;
GRANT CREATE SCHEMA ON DATABASE DBT_ANALYTICS TO ROLE dbt_transformer;

GRANT USAGE ON DATABASE ZOOMCAMP_DATABASE TO ROLE dbt_transformer;
GRANT USAGE ON SCHEMA ZOOMCAMP_DATABASE.RAW TO ROLE dbt_transformer;
GRANT SELECT ON ALL TABLES IN SCHEMA ZOOMCAMP_DATABASE.RAW TO ROLE dbt_transformer;

CREATE USER dbt_user PASSWORD='P@ssw0rd123!'
  DEFAULT_ROLE = dbt_transformer
  DEFAULT_WAREHOUSE = DBT_WH
  DEFAULT_NAMESPACE = DBT_ANALYTICS.TRANSFORMATIONS;
GRANT ROLE dbt_transformer TO USER dbt_user;
```


### Setup verification

To verify that the user was correctly set up and has the correct permissions, sign in as `dbt_user` and run the following sql statements:

```sql
USE WAREHOUSE DBT_WH;

USE DATABASE DBT_ANALYTICS;
CREATE OR REPLACE SCHEMA TEST_SCHEMA;
CREATE OR REPLACE TABLE TEST_TABLE AS (
    SELECT * FROM ZOOMCAMP_DATABASE.RAW.GREEN_TAXI_TRIPS_RAW LIMIT 10
);

SELECT * FROM TEST_TABLE;
```

After verifying our permissions, we can drop the test schema and table with:

```sql
DROP SCHEMA TEST_SCHEMA;
```


## dbt cloud setup

For this step, you will need your Snowflake account identifier. The identifier is in the format `<ORGNAME>-<ACCOUNT_NAME>`. It can be found in the Snowsight URL after signing in:

`https://app.snowflake.com/<ORGNAME>/<ACCOUNT_NAME>/#/homepage`

It can also be found by: 
- Clicking on your account name in the bottom-left corner
- Hovering over **Account**
- Clicking on **View account details** in the menu that appears
- Copying the value for "Account identifier"

When you first sign into dbt Cloud, you'll be prompted to create a new project.

1. Provide a project name
2. Click on **Add new connection** from the drop-down menu, which will open a new tab
3. Select **Snowflake** for the connection type
4. Enter your Snowflake account identifier, and the database and warehouse we created in the previous section. For example:
    - **Account**: `ABCDEFG-HIJ012345`
    - **Database**: `DBT_ANALYTICS`
    - **Warehouse**: `DBT_WH`
5. Under optional settings, enter the `dbt_transformer` role we created
6. Click **Save** on the upper-right corner and close the tab
7. Back in the welcome tab, select **Snowflake** from the drop-down menu
8. In the **Development credentials** section, enter the username and password for the user we created:
    - **Username**: `dbt_user`
    - **Password**: `P@ssw0rd123!`
9. We can keep the default values for the other fields
10. Click on **Test connection**
11. Once the test has completed, click on **Save**
12. Select the **Managed** option for setting up a repository and provide a repository name
13. Click on `Start developing in the Studio`


## Initialize dbt project

In the **dbt Cloud IDE**, click on **Initialize dbt project** in the left window pane. This will automatically create a folder structure for the project.

In the `dbt_project.yml` file, we will update the project name and models.

```yaml
# dbt_project.yml

name: 'nyc_green_taxi'
version: '1.0.0'
config-version: 2

# [...]

models:
  nyc_green_taxi:
    staging:
      +materialized: view
```

## Source configuration

Right-click on the `models/` folder and create a file called `nyc_sources.yml`.

In the file, we will specify the database, schema, and table that is storing our green taxi data.

```yaml
# nyc_sources.yml

version: 2

sources:
  - name: nyc_taxi
    database: ZOOMCAMP_DATABASE
    schema: RAW

    tables:
      - name: GREEN_TAXI_TRIPS_RAW
```

After saving, a `Generate model` button should appear above `- name: GREEN_TAXI_TRIPS_RAW`. You may need to reload the page for the button to appear.

Clicking on the button should generate a CTE using the `GREEN_TAXI_TRIPS_RAW` table. 

```sql
with source as (
    select * from {{ source('nyc_taxi', 'GREEN_TAXI_TRIPS_RAW') }}
),

renamed as (

    select
        -- unique_row_id,       <=== Will replace
        filename,
        vendorid,
        pickup_datetime,
        dropoff_datetime,
        store_and_fwd_flag,
        rate_code_id,
        pu_location_id,
        do_location_id,
        passenger_count,
        trip_distance,
        fare_amount,
        extra,
        mta_tax,
        tip_amount,
        tolls_amount,
        ehail_fee,
        improvement_surcharge,
        total_amount,
        payment_type,
        trip_type,
        congestion_surcharge,
        loaded_at

    from source

)

select * from renamed
```

Since we will be creating our own row identifier later, we can remove `unique_row_id` from the view.

Clicking `Save` will automatically create a `models/staging/nyc_taxi` path containing the `stg_nyc_taxi__GREEN_TAXI_TRIPS_RAW.sql` file. We'll also remove the `example` folder in the `models/` folder.
```
models/
│   ├── staging
│   │   └── nyc_taxi
│   │       └── stg_nyc_taxi__GREEN_TAXI_TRIPS_RAW
│   └── nyc_sources.yml    
```

## Create macro for getting payment type description

Our taxi dataset features a `PAYMENT_TYPE` column, which uses a numeric code to identify how the passenger paid for the trip.
- 0 = Flex Fare trip
- 1 = Credit card
- 2 = Cash
- 3 = No charge
- 4 = Dispute
- 5 = Unknown
- 6 = Voided trip

We'll create a macro using Jinja templating to return the description based on the numeric code.

In the `macros` folder, create a file called `get_payment_type_description.sql` and enter in the following code:

```sql
--  get_payment_type_description.sql

{% macro get_payment_type_description(payment_type) -%}
    case cast( {{ payment_type }} as integer)
        when 0 then 'Flex Fare trip'
        when 1 then 'Credit card'
        when 2 then 'Cash'
        when 3 then 'No charge'
        when 4 then 'Dispute'
        when 5 then 'Unknown'
        when 6 then 'Voided trip'
        else 'EMPTY'
    end

{%- endmacro %}
```
The macro expects the column name (`payment_type`) as a string and will try to cast it as an integer. Using the `CASE` expression, the macro will return the payment type description based on the value of `payment_type`.

Click **Save**.

We'll add a payment type description column to our `stg_nyc_taxi__GREEN_TAXI_TRIPS_RAW.sql` model using the macro.

```sql
-- stg_nyc_taxi__GREEN_TAXI_TRIPS_RAW.sql

with source as (
    select * from {{ source('nyc_taxi', 'GREEN_TAXI_TRIPS_RAW') }}
),

renamed as (

    select
        filename,
        vendorid,
        pickup_datetime,
        dropoff_datetime,
        store_and_fwd_flag,
        rate_code_id,
        pu_location_id,
        do_location_id,
        passenger_count,
        trip_distance,
        fare_amount,
        extra,
        mta_tax,
        tip_amount,
        tolls_amount,
        ehail_fee,
        improvement_surcharge,
        total_amount,
        payment_type,
        {{ get_payment_type_description('payment_type') }} as payment_type_description, -- <=== Add column
        trip_type,
        congestion_surcharge,
        loaded_at

    from source

)

select * from renamed
```

We can see what the compiled code looks like by clicking on **Compile** (or pressing ⌘ + ⇧ + Enter).

```sql
-- Compiled code

-- [...]
        payment_type,
        case cast( payment_type as integer)
        when 0 then 'Flex Fare trip'
        when 1 then 'Credit card'
        when 2 then 'Cash'
        when 3 then 'No charge'
        when 4 then 'Dispute'
        when 5 then 'Unknown'
        when 6 then 'Voided trip'
        else 'EMPTY'
    end as payment_type_description, -- <=== Add column
```

## Create surrogate key using macro from dbt-utils package

The [dbt-utils package](https://hub.getdbt.com/dbt-labs/dbt_utils/latest/) is a collection of reusable macros and helper functions for that simplify common transformations, testing, and data modeling tasks across projects.

Here, we will import the package and utilize the `generate_surrogate_key` macro to generate a hashed surrogate key. A hashed surrogate key is a unique identifier that acts as a primary key in data warehouses and helps facilitate efficient joins and lookups.

In the root folder, create a `packages.yml` file and add the following code:

```yaml
# packages.yml

packages:
  - package: dbt-labs/dbt_utils
    version: [">=1.3.0", "<2.0.0"]
```

Click on **Save** and install the package by running the following code in the IDE console:

```shell
dbt deps
```

Next, we'll add a new identifier column to `stg_nyc_taxi__GREEN_TAXI_TRIPS_RAW.sql` using the package's `generate_surrogate_key` macro.

```sql
-- stg_nyc_taxi__GREEN_TAXI_TRIPS_RAW.sql

with source as (
    select * from {{ source('nyc_taxi', 'GREEN_TAXI_TRIPS_RAW') }}
),

renamed as (

    select
        {{ dbt_utils.generate_surrogate_key(['pickup_datetime', 'dropoff_datetime']) }} as tripid, -- <=== Add column
        filename,
        vendorid,
        pickup_datetime,
        dropoff_datetime,
        store_and_fwd_flag,
        rate_code_id,
        pu_location_id,
        do_location_id,
        passenger_count,
        trip_distance,
        fare_amount,
        extra,
        mta_tax,
        tip_amount,
        tolls_amount,
        ehail_fee,
        improvement_surcharge,
        total_amount,
        payment_type,
        {{ get_payment_type_description('payment_type') }} as payment_type_description,
        trip_type,
        congestion_surcharge,
        loaded_at

    from source

)

select * from renamed
```

After compilation, the `generate_surrogate_key` macro produces the following SQL:

```sql
-- Compiled code

-- [...]
select
        md5(cast(coalesce(cast(pickup_datetime as TEXT), '_dbt_utils_surrogate_key_null_') || '-' || coalesce(cast(dropoff_datetime as TEXT), '_dbt_utils_surrogate_key_null_') as TEXT)) as tripid, -- <=== Add column
        filename,
--      [...]
```

We can see how macros can simplify complex SQL logic and make models more readable and maintainable.

## Build model and query view in Snowflake

To run our model and create our view in our `DBT_ANALYTICS` database in Snowflake, run the following command in **dbt**.

```
dbt build
```

Once complete, switch to **Snowflake**, and sign in as `dbt_user`. Open a SQL file and run the following command:

```sql
SELECT tripid, filename, pickup_datetime, payment_type, payment_type_description
from DBT_ANALYTICS.DBT_LNGUYEN.stg_nyc_taxi__GREEN_TAXI_TRIPS_RAW 
LIMIT 10;
```
- Replace `DBT_LNGUYEN` with the schema provided during the dbt project setup (default is `dvt_<first_name_initial + last_name>`)

We should see our green taxi dataset with the two added columns.

![04-db-02]

## Clean data

We'll continue preparing our staging data by renaming, reordering, and casting the columns to their appropriate data types.

```sql
-- stg_nyc_taxi__GREEN_TAXI_TRIPS_RAW.sql

with source as (
    select * from {{ source('nyc_taxi', 'GREEN_TAXI_TRIPS_RAW') }}
),

renamed as (

    select
        -- identifiers
        {{ dbt_utils.generate_surrogate_key(['pickup_datetime','dropoff_datetime']) }} as tripid,
        try_cast(vendorid as integer) as vendor_id,
        try_cast(rate_code_id as integer) as rate_code_id,
        cast(pu_location_id as integer) as pickup_location_id,
        cast(do_location_id as integer) as dropoff_location_id,

        -- timestamps
        cast(pickup_datetime as timestamp) as pickup_datetime,
        cast(dropoff_datetime as timestamp) as dropoff_datetime,
        
        -- trip info
        cast(passenger_count as integer) as passenger_count,
        cast(trip_distance as numeric) as trip_distance,
        try_cast(trip_type as integer) as trip_type,

        -- payment info
        cast(fare_amount as numeric) as fare_amount,
        cast(extra as numeric) as extra,
        cast(mta_tax as numeric) as mta_tax,
        cast(tip_amount as numeric) as tip_amount,
        cast(tolls_amount as numeric) as tolls_amount,
        try_cast(improvement_surcharge as numeric) as improvement_surcharge,
        try_cast(congestion_surcharge as numeric) as congestion_surcharge,
        cast(total_amount as numeric) as total_amount,
        cast(payment_type as integer) as payment_type,
        {{ get_payment_type_description('payment_type') }} as payment_type_description,

        -- metadata
        cast(loaded_at as timestamp) as loaded_at_ts,
        filename

    from source
    -- Filter out records with null vendor_id (data quality requirement)
    where vendor_id is not null

)

select * from renamed

-- Sample records for dev environment using deterministic date filter
{% if target.name == 'dev' %}
where pickup_datetime >= '2019-01-01' and pickup_datetime < '2019-02-01'
{% endif %}

-- Limit results for testing
{% if var('is_test_run', default=true) %}
    limit 100
{% endif %}
```

We can build the model with `is_test_run=true` to limit the output to 100 rows. This is useful for quickly previewing transformations in Snowflake while reducing query time and cost.

Once we are happy with the changes, we can run the following command in the console:

```shell
dbt build --select stg_nyc_taxi__GREEN_TAXI_TRIPS_RAW.sql --vars 'is_test_run: false'
```

## Dimensional modeling

In this section, we'll organize our data into a star schema. We'll build a dimension table that holds the zone/location attributes, as well as a fact table that will contain one row per trip.

### Create dimension table (Seeds)

dbt seeds are CSV files located in a dbt project's `seeds/` directory that can be loaded into a data warehouse as tables. This is ideal for static metadata like the Taxi Zone Lookup, which doesn't change frequently but is essential for dimensional joins.

Download the [taxi_zone_lookup.csv](https://github.com/DataTalksClub/data-engineering-zoomcamp/blob/main/04-analytics-engineering/taxi_rides_ny/seeds/taxi_zone_lookup.csv) file from the DataTalksClub Github and add the file to the `seeds/` folder.

In the console, run the following code to load the CSV file:

```shell
dbt seed
```

In Snowflake, we'll see that a `TAXI_ZONE_LOOKUP` table has been added to the `DBT_ANALYTICS` database.

![04-db-03]

We'll prepare the lookup table to be merged with our taxi data.

Create a new folder called `models/core` and add a `dim_zones.sql` file.

```sql
-- dim_zones.sql

select
    locationid as location_id,
    borough,
    zone,
    replace(service_zone, 'Boro', 'Green') as service_zone
from {{ ref('taxi_zone_lookup') }}
```

Click on **Build** to create our `dim_zones` model.

## Create fact table (Joins)

If you loaded the Yellow taxi data as well, you would union the two datasets in this section. More information about that can be found in DTC's [Github repo](https://github.com/DataTalksClub/data-engineering-zoomcamp/tree/main/04-analytics-engineering/taxi_rides_ny/models/intermediate) and [Youtube video](https://youtu.be/ueVy2N54lyc?si=sFJfiLVLWkU_pRq4&t=2480).

This project only works with the Green taxi data, so the union step is excluded here. Instead, we will just join the Green taxi data with the taxi zone lookup table.

Add another file called `fct_trips.sql` to the `core/` folder.

```sql
-- fct_trips.sql

{{
    config(
        materialized='table'
    )
}}

with green_tripdata as (
    select * 
    from {{ ref('stg_nyc_taxi__GREEN_TAXI_TRIPS_RAW') }}
),

dim_zones as (
    select *
    from {{ ref('dim_zones') }}
    where borough != 'Unknown'
)

select 
    trips.tripid,
    trips.vendor_id,
    trips.rate_code_id,

    trips.pickup_location_id,
    pu_zones.borough as pickup_borough,
    pu_zones.zone as pickup_zone_name,

    trips.dropoff_location_id,
    do_zones.borough as dropoff_borough,
    do_zones.zone as dropoff_zone_name,

    trips.pickup_datetime,
    trips.dropoff_datetime,

    trips.store_and_fwd_flag,
    trips.passenger_count,
    trips.trip_distance,
    trips.trip_type,

    trips.fare_amount,
    trips.extra,
    trips.mta_tax,
    trips.tip_amount,
    trips.ehail_fee,
    trips.improvement_surcharge,
    trips.congestion_surcharge,
    trips.total_amount,
    trips.payment_type,
    trips.payment_type_description

from green_tripdata as trips
inner join dim_zones as pu_zones 
    on trips.pickup_location_id = pu_zones.location_id
inner join dim_zones as do_zones 
    on trips.dropoff_location_id = do_zones.location_id
```

Click on **Build** to create our `fact_trips` model.

In Snowflake, we are now able to query the `fct_trips` table and see the pickup and dropoff boroughs and zones for each trip.

![04-db-04]

## Create Monthly Revenue Mart

In this section, we build a **Mart**, which represents the final, consumption-ready layer of our project. While staging models focus on cleaning and fact tables focus on individual events, a mart focuses on a specific business process or entity.

We will create a monthly revenue summary that aggregates data by pickup zone and month.

Create a folder called `models/marts` and add a `fct_monthly_zone_revenue.sql` file.

```sql
-- fct_monthly_zone_revenue.sql

with trips_data as (
    select * from {{ ref('fct_trips') }}
)

    select 
        pickup_zone_name as revenue_zone,
        {{ dbt.date_trunc("month", "pickup_datetime") }} as revenue_month,
        sum(fare_amount) as total_monthly_fare,
        sum(extra) as total_monthly_extra,
        sum(mta_tax) as total_monthly_mta_tax,
        sum(tip_amount) as total_monthly_tip_amount,
        sum(improvement_surcharge) as total_monthly_improvement_surcharge,
        sum(total_amount) as total_monthly_revenue,
        count(tripid) as total_monthly_trips,
        avg(passenger_count) as avg_monthly_passenger_count,
        avg(trip_distance) as avg_monthly_trip_distance

    from trips_data
    group by 1,2
```

The `dbt.date_trunc` macro allows us to standardize all pickup timestamps to the first day of their respective month. This provides a clean way to perform the monthly grouping.

After clicking **Build**, we can query this table in Snowflake and analyze the monthly revenue for each zone:

![04-db-05]


[04-db-01]: ../img/04-db-01.png
[04-db-02]: ../img/04-db-02.png
[04-db-03]: ../img/04-db-03.png
[04-db-04]: ../img/04-db-04.png
[04-db-05]: ../img/04-db-05.png