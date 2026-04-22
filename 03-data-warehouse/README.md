# Snowflake

Snowflake is a cloud-native, data platform that brings together data storage, processing, and analysis. A brief introduction to the platform can be found [here](03-data-warehouse/snowflake-intro.md). 

In this module, we will integrate AWS S3 with Snowflake to perform queries and data analysis. By using a **Storage Integration** object, we can use AWS IAM roles to allow Snowflake to access authorized S3 buckets without having to directly provide credentials.

## Prerequisites

This module picks up from the last one where we used Kestra to load the NYC taxi data into an S3 bucket. Using the `09_aws_taxi_scheduled.yaml` [flow](02-workflow-orchestration/flows/09_aws_taxi_scheduled.yaml), I retrieved the data for 2019 and 2020 using backfill.

If needed, you can recreate the bucket with Kestra using the `07_aws_setup.yaml` flow or with Terraform using the files in the `03-data-warehouse/terraform-bucket-setup` folder.

## Environment setup

We'll begin by creating a warehouse, database, and schemas in Snowflake using SQL.

In the **Snowflake** web interface (aka Snowsight), add a  SQL file using the "+" button in the top left corner. 

Run the following commands:

```sql
-- Create a dedicated compute resource for loading and transformation
CREATE OR REPLACE WAREHOUSE ZOOMCAMP_WH 
  WITH WAREHOUSE_SIZE = 'X-SMALL' 
  AUTO_SUSPEND = 60 
  AUTO_RESUME = TRUE 
  COMMENT = 'Warehouse for Zoomcamp data processing';

-- Create the main database
CREATE DATABASE IF NOT EXISTS ZOOMCAMP_DATABASE;
USE DATABASE ZOOMCAMP_DATABASE;

-- Create schemas
CREATE SCHEMA IF NOT EXISTS RAW;          -- Raw data (source of truth)
CREATE SCHEMA IF NOT EXISTS STAGING;      -- Cleaned/Standardized data
CREATE SCHEMA IF NOT EXISTS ANALYTICS;    -- Business-ready aggregates
```

## Configure secure access to AWS

Before loading the data, we must establish a secure connection to our S3 bucket. While the full guide can be found in [Snowflake's documentation](https://docs.snowflake.com/en/user-guide/data-load-s3-config-storage-integration), I will highlight some of the steps here.

### Configure S3 permissions

In the previous module, we created a flow in Kestra that transformed the NYC data by adding a `unique_row_id` and `filename` value to each row of the dataset. This data was partitioned by pickup date and saved in the `/warehouse/green_tripdata/data/` folder as parquets. 

In the **AWS Management Console**, create a policy that provides Snowflake with read-only access to the directory containing our transformed data within our S3 bucket.  

```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "s3:GetObject",
                "s3:GetObjectVersion"
            ],
            "Resource": "arn:aws:s3:::ln-zoomcamp-kestra-aws/warehouse/green_tripdata/data/*"
        },
        {
            "Effect": "Allow",
            "Action": [
                "s3:ListBucket",
                "s3:GetBucketLocation"
            ],
            "Resource": "arn:aws:s3:::ln-zoomcamp-kestra-aws",
            "Condition": {
                "StringLike": {
                    "s3:prefix": [
                        "warehouse/green_tripdata/data/*"
                    ]
                }
            }
        }
    ]
}
```
- Replace the value for the first `Resource` key with your bucket name and folder path prefix
- Replace the value for the second `Resource` key with your bucket name
- Replace the value for `s3:prefix` key with the folder path prefix

Enter a **Policy name**, such as `zoomcamp_snowflake_access`, and click on **Create policy**.

### Create IAM role

From the **IAM Dashboard**:
1. Select **Roles** from the left sidebar
2. Click on **Create role**
3. Select **AWS account** as the trusted entity type
4. Select **Another AWS account** and enter your account ID into the field below
    - This Account ID will be changed later
5. Check the **Require external ID (Best practice when a third party will assume this role)** option and enter a placeholder ID such as `0000`
    - This External ID will be changed later
6. Click **Next**
7. Add the permission we created earlier (ex. `zoomcamp_snowflake_access`)
8. Click **Next**
9. Enter a role name (ex. `zoomcamp_snowflake_role`)
10. Click **Create role**
11. Click on the newly created role and note the **ARN**, as we will be using it in the next step
    - It should look like: `arn:aws:iam::<account_id>:role/zoomcamp_snowflake_role`

### Create cloud storage integration

In **Snowflake**, execute the following SQL command as an `ACCOUNTADMIN` or a role with `CREATE INTEGRATION` privilege:

```sql
CREATE OR REPLACE STORAGE INTEGRATION s3_integration
  TYPE = EXTERNAL_STAGE
  STORAGE_PROVIDER = 'S3'
  ENABLED = TRUE
  STORAGE_AWS_ROLE_ARN = 'arn:aws:iam::<account_id>:role/zoomcamp_snowflake_role'
  STORAGE_ALLOWED_LOCATIONS = ('s3://ln-zoomcamp-kestra-aws/warehouse/green_tripdata/data/');
```

- Replace the value for `STORAGE_AWS_ROLE_ARN` with the **ARN** for the `zoomcamp_snowflake_role` created in the previous step 
- Replace the value for `STORAGE_ALLOWED_LOCATIONS` with your bucket name with path to the transformed taxi data

### Establish the Trust Relationship

Run the following SQL command in **Snowflake**:

```sql
DESC INTEGRATION s3_integration;
```

We'll use the values for `STORAGE_AWS_IAM_USER_ARN` and `STORAGE_AWS_EXTERNAL_ID` to replace the account ID and external ID placeholders we used earlier.

| Property | Description |
| - | - |
| `STORAGE_AWS_IAM_USER_ARN` | Snowflake provisions a single IAM user for your entire Snowflake account. All S3 storage integrations in your account use that IAM user. |
| `STORAGE_AWS_EXTERNAL_ID` | The external ID that Snowflake uses to establish a trust relationship with AWS. |


Back in the **AWS Management Console**:
1. Click on the **Trust relationships** tab of your created role's summary page
2. Click on **Edit trust policy**
3. Replace the value for `AWS` with the value from `STORAGE_AWS_IAM_USER_ARN`
    - Previously we used our AWS account ID
4. Replace the value for `sts:ExternalId` with the value from `STORAGE_AWS_EXTERNAL_ID`
    - Previously we used `0000`
5. Click on **Update policy** to save your changes

## Load raw data

Now that we have configured our permissions and trust relationship, we can enable the connection between Snowflake and S3.

### Create an external stage 

In **Snowflake**, we'll create a **File Format** object that instructs Snowflake how to interpret our parquet files.

```sql
-- Switch to RAW schema
USE SCHEMA RAW;

CREATE OR REPLACE FILE FORMAT nyc_parquet_format
  TYPE = 'PARQUET'
  COMPRESSION = 'AUTO'
  USE_VECTORIZED_SCANNER = TRUE;
```

We'll then create an external stage that references the storage integration using the following command:

```sql
CREATE OR REPLACE STAGE zoomcamp_s3_stage
  STORAGE_INTEGRATION = s3_integration
  URL = 's3://ln-zoomcamp-kestra-aws/warehouse/green_tripdata/data/'
  FILE_FORMAT = nyc_parquet_format;
```

We should be able to verify that connection was successful and view all of the parquet files in the bucket with the following SQL command:

```sql
LIST @zoomcamp_s3_stage
```

![03-ct-01]

### Query external stage

We can query the files in the stage directly without having to load it into a table. The following command shows the first 3 columns and the originating Parquet file for each of the first 10 rows.

```sql
-- Parquet uses key-value access ($1:column_name)
SELECT 
    $1:unique_row_id::TEXT as unique_row_id,
    $1:filename as filename,
    $1:lpep_pickup_datetime::TIMESTAMP as pickup_datetime,
    $1:trip_distance::FLOAT as trip_distance
FROM @zoomcamp_s3_stage
LIMIT 10;
```

![03-ct-02]

When we run the `COUNT` function, we'll see that there are 7,778,101 rows in the stage.

```sql
SELECT COUNT($1) FROM @zoomcamp_s3_stage;
```

## Load data into raw table

For faster performance and easier querying, we'll move the data from the external stage into a table. 

To create the table, we'll refer to the [NYC Green Trips Data Dictionary](https://www.nyc.gov/assets/tlc/downloads/pdf/data_dictionary_trip_records_green.pdf) for the list of columns. We will load everything as `TEXT` first to prevent the `COPY` command from failing due to minor formatting issues.

```sql
CREATE OR REPLACE TABLE RAW.green_taxi_trips_raw (
    unique_row_id TEXT,
    filename TEXT,
    vendor_id TEXT,
    pickup_datetime TEXT,
    dropoff_datetime TEXT,
    store_and_fwd_flag TEXT,
    rate_code_id TEXT,
    pu_location_id TEXT,
    do_location_id TEXT,
    passenger_count TEXT,
    trip_distance TEXT,
    fare_amount TEXT,
    extra TEXT,
    mta_tax TEXT,
    tip_amount TEXT,
    tolls_amount TEXT,
    ehail_fee TEXT,
    improvement_surcharge TEXT,
    total_amount TEXT,
    payment_type TEXT,
    trip_type TEXT,
    congestion_surcharge TEXT,
    loaded_at TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
);
```

We can then load the data from our external stage to the table with:

```sql
COPY INTO RAW.green_taxi_trips_raw
FROM (
  SELECT
    $1:unique_row_id,
    $1:filename,
    $1:VendorID,
    $1:lpep_pickup_datetime,
    $1:lpep_dropoff_datetime,
    $1:store_and_fwd_flag,
    $1:RatecodeID,
    $1:PULocationID,
    $1:DOLocationID,
    $1:passenger_count,
    $1:trip_distance,
    $1:fare_amount,
    $1:extra,
    $1:mta_tax,
    $1:tip_amount,
    $1:tolls_amount,
    $1:ehail_fee,
    $1:improvement_surcharge,
    $1:total_amount,
    $1:payment_type,
    $1:trip_type,
    $1:congestion_surcharge,
    CURRENT_TIMESTAMP()
  FROM @zoomcamp_s3_stage
)
FILE_FORMAT = nyc_parquet_format;
```

### Query table data

We'll view the first 10 rows of the `RAW.green_taxi_trips_raw` table with:

```sql
SELECT * 
FROM RAW.green_taxi_trips_raw
LIMIT 10;
```

![03-ct-03]

Running the `COUNT` function shows that there are 7,778,101 rows in the table, indicating that all of the data from `zoomcamp_s3_stage` was copied over.

### Clean up

With our raw data copied into Snowflake, we can delete our S3 bucket to minimize costs. In a production environment, this bucket is typically retained (or moved to a Cold Storage tier like S3 Glacier) to serve as an immutable backup for disaster recovery and auditing.

## Clean and standardize

Now, we transform the raw text data into a clean, typed table in the STAGING schema. Our first table will try to cast the columns into the appropriate type so that we can more easily perform exploratory data analysis (EDA).

```sql
CREATE OR REPLACE TABLE STAGING.green_taxi_trips AS
SELECT
    unique_row_id,
    vendor_id,
    TRY_CAST(pickup_datetime AS TIMESTAMP_NTZ) AS pickup_datetime,
    TRY_CAST(dropoff_datetime AS TIMESTAMP_NTZ) AS dropoff_datetime,
    store_and_fwd_flag,
    rate_code_id, 
    pu_location_id,
    do_location_id,
    TRY_CAST(passenger_count AS INT) AS passenger_count,
    TRY_CAST(trip_distance AS FLOAT) AS trip_distance,
    TRY_CAST(fare_amount AS DECIMAL(10,2)) AS fare_amount,
    TRY_CAST(extra AS DECIMAL(10,2)) AS extra,
    TRY_CAST(mta_tax AS DECIMAL(10,2)) AS mta_tax,
    TRY_CAST(tolls_amount AS DECIMAL(10,2)) AS tolls_amount,
    TRY_CAST(ehail_fee AS DECIMAL(10,2)) AS ehail_fee,
    TRY_CAST(improvement_surcharge AS DECIMAL(10,2)) AS improvement_surcharge,
    TRY_CAST(total_amount AS DECIMAL(10,2)) AS total_amount,
    TRY_CAST(payment_type AS INT) AS payment_type,
    trip_type,
    TRY_CAST(congestion_surcharge AS INT) AS congestion_surcharge,
    filename,
    loaded_at
FROM RAW.green_taxi_trips_raw;
```

With the focus of the project being on designing pipelines, a quick, very basic EDA was performed on the `STAGING.green_taxi_trips` table to identify outliers. The analysis and SQL queries used can be found in `taxi_eda.html`. Here, we will copy the data from the `STAGING.green_taxi_trips` table with rows that have an out-of-range pickup or dropoff dates, negative travel distance, or negative total amount charged filtered out.

```sql
CREATE OR REPLACE TABLE STAGING.green_taxi_trips_cleaned AS
SELECT *
FROM STAGING.green_taxi_trips
WHERE
    YEAR(pickup_datetime) BETWEEN 2019 AND 2020
    AND YEAR(dropoff_datetime) BETWEEN 2019 AND 2020
    AND trip_distance >= 0
    AND fare_amount >= 0;
```

Running `COUNT` on `STAGING.green_taxi_trips_cleaned` shows that there are now 7,734,249 rows with the outliers removed.

## Create analytics table

To analyze the pandemic's impact on NYC's transportation landscape, we'll integrate our taxi records with the New York Times COVID-19 dataset. This dataset provides a daily record of coronavirus cases and deaths at the state and county levels and is accessible directly via the Snowflake Marketplace.

By performing a join on the trip date, we can correlate shifting mobility patterns with the progression of the virus. We'll filter the data specifically for `New York City` (covering the five boroughs) between 2019 and 2020 since Green Taxis are specifically authorized to serve Brooklyn, Queens, Bronx, Staten Island, and Northern Manhattan.

We'll create our final analytics-ready table using the following SQL command:

```sql
CREATE OR REPLACE TABLE ANALYTICS.GREEN_TAXI_TRIPS_COVID_IMPACT AS
WITH nyc_covid_daily AS (
    SELECT
        date,
        cases,
        deaths,
        cases_since_prev_day,
        deaths_since_prev_day
    FROM COVID19_EPIDEMIOLOGICAL_DATA.PUBLIC.NYT_US_COVID19
    WHERE 
        STATE = 'New York' 
        AND COUNTY = 'New York City'
        AND YEAR(DATE) BETWEEN 2019 AND 2020
)
SELECT 
    -- Taxi data
    DATE(taxi.pickup_datetime) AS pickup_date,
    COUNT(taxi.unique_row_id) AS trip_count,
    SUM(taxi.trip_distance) AS total_trip_distance_miles,
    AVG(taxi.trip_distance) AS avg_trip_distance_miles,
    SUM(taxi.fare_amount) AS total_fare,
    ROUND(AVG(taxi.fare_amount), 2) AS avg_fare_amount,
    
    -- COVID metrics
    MAX(covid.cases) as cumulative_covid_cases,
    MAX(covid.deaths) as cumulative_covid_deaths,
    MAX(covid.cases_since_prev_day) as daily_new_cases,
    MAX(covid.deaths_since_prev_day) as daily_new_deaths
FROM STAGING.GREEN_TAXI_TRIPS_CLEANED AS taxi
LEFT JOIN nyc_covid_daily AS covid
    ON DATE(taxi.pickup_datetime) = covid.date
GROUP BY 1
ORDER BY 1;
```

## Semantic views and Cortex Analyst

In this section, we will generate a specialized **semantic view** to integrate with Snowflake **Cortex Analyst**. Cortex Analyst allows non-technical stakeholders to ask questions in natural language (e.g., "How did ride volume change when COVID cases peaked?") and receive accurate SQL-generated answers.

1. In the left menu bar, navigate to **AI & ML** > **Analyst** to bring up the **Cortex Analyst** page
2. Select the database and schema containing our `GREEN_TAXI_TRIPS_COVID_IMPACT` table (`ZOOMCAMP_DATABASE.ANALYTICS`)
3. Click on `Create semantic view`
4. We can provide examples of SQL queries that would be used on `GREEN_TAXI_TRIPS_COVID_IMPACT` to perform our analysis to provide context to Cortex Analyst. We'll skip this for now
5. Provide a name for the semantic view and choose to store the view in the `ANALYTICS` schema
6. Select `GREEN_TAXI_TRIPS_COVID_IMPACT` table
7. Select all columns and leave the `Add sample values` and `Add descriptions` boxes checked
8. Click `Create`

Once created, we can review (and edit) the context that Snowflake has provided to our table and columns. In the right panel, we'll also see a chatbox where we can ask questions about the data in the semantic view and have Cortex Analyst run the queries to find our answers.

![03-sv-01]

If we ask "What is the total fare amount for March 2019 compared to March 2020?", Cortex Analyst generates the following response:

> This is our interpretation of your question:
>
> What is the total fare amount for green taxi trips in March 2019 compared to March 2020?
>
> | Month | Total_fare_amount | 
> | - | - |
> | 2019-03-01 | 8511725.48 |
> | 2020-03-01 | 3161404.47 |

It also provides the query performed to retrieve the data:

```sql
SELECT
  DATE_TRUNC('MONTH', pickup_date) AS month,
  SUM(total_fare) AS total_fare_amount
FROM
  green_taxi_trips_covid_impact
WHERE
  (
    DATE_PART('YEAR', pickup_date) = 2019
    AND DATE_PART('MONTH', pickup_date) = 3
  )
  OR (
    DATE_PART('YEAR', pickup_date) = 2020
    AND DATE_PART('MONTH', pickup_date) = 3
  )
GROUP BY
  DATE_TRUNC('MONTH', pickup_date)
ORDER BY
  month ASC
  /* Generated by Cortex Analyst (request_id: 502fb080-7e6b-465a-83ff-8971b1f76c63) */
```

## Streamlit in Snowflake

To visualize the correlation between NYC taxi and public health data and highlight key metrics, we will develop an interactive dashboard using Streamlit in Snowflake.

1. In the left menu bar, navigate to **Projects** > **Streamlit** to bring up the **Streamlit Apps** page
2. Click on the **+ Streamlit App** button
3. In the popup window,
    - Provide a title for the app
    - Select `ZOOMCAMP_DATABASE` and `ANALYTICS` for the app location
    - Choose **Run on warehouse** for the Python environment
    - Select `ZOOMCAMP_WH` for the app warehouse
4. Click **Create**
5. Click on the **Packages** drop-down menu button on the top of the page and add the following packages:
    - pandas
    - plotly
    - snowflake-ml-python

6. Replace the example code in `streamlit_app.py` with code from `03-data-warehouse/streamlit_app.py`
7. Click on **Run** to build the dashboard

### Dashboard

The dashboard features various key performance indicators (KPIs) and customizable charts comparing taxi data with COVID data and 2019 metrics with 2020 metrics.

![03-db-01]

Besides identifying trends and relationships, visualizations can also help detect anomalies. For instance, the **Average Trip Distance (miles)** comparison reveals significant spikes in July and November 2020 that deviate sharply from the 2019 baseline. Because these averages surged while total volume remained low, it signals the presence of extreme upper-bound outliers This may signal a need for further analysis, data cleaning, and/or a review of the ELT pipeline.

### Cortex Analyst chatbot

At the bottom of the screen, there is a chat input widget where users can ask questions about the dataset and have Cortex Analyst translate them into SQL queries.

![03-db-02]

Cortex Analyst used the following SQL query to generate the table in its answer:

```sql
WITH __green_taxi_trips_covid_impact AS (
  SELECT
    daily_new_cases,
    trip_count,
    pickup_date,
    total_fare
  FROM ZOOMCAMP_DATABASE.ANALYTICS.GREEN_TAXI_TRIPS_COVID_IMPACT
), first_case AS (
  SELECT
    MIN(pickup_date) AS first_case_date
  FROM __green_taxi_trips_covid_impact
  WHERE
    daily_new_cases > 0
), month_before AS (
  SELECT
    AVG(trip_count) AS avg_daily_trips,
    SUM(total_fare) AS total_fare,
    'Month Before First COVID Case' AS period
  FROM __green_taxi_trips_covid_impact, first_case
  WHERE
    pickup_date >= DATE_TRUNC('MONTH', DATEADD(MONTH, -1, first_case_date))
    AND pickup_date < DATE_TRUNC('MONTH', first_case_date)
), month_after AS (
  SELECT
    AVG(trip_count) AS avg_daily_trips,
    SUM(total_fare) AS total_fare,
    'Month After First COVID Case' AS period
  FROM __green_taxi_trips_covid_impact, first_case
  WHERE
    pickup_date >= DATE_TRUNC('MONTH', DATEADD(MONTH, 1, first_case_date))
    AND pickup_date < DATE_TRUNC('MONTH', DATEADD(MONTH, 2, first_case_date))
)
SELECT
  period,
  avg_daily_trips,
  total_fare
FROM month_before
UNION ALL
SELECT
  period,
  avg_daily_trips,
  total_fare
FROM month_after
 -- Generated by Cortex Analyst (request_id: 760c7b10-546e-4ec7-90e5-210d1969236b)
;
```

With Cortex Analyst, we can more easily and quickly analyze data. Rather than constructing a complex and nested SQL statement, we can ask the AI agent a question and have it handle the technical logic behind the scenes.

[03-ct-01]: ../img/03-ct-01.png
[03-ct-02]: ../img/03-ct-02.png
[03-ct-03]: ../img/03-ct-03.png
[03-sv-01]: ../img/03-sv-01.png
[03-db-01]: ../img/03-db-01.png
[03-db-02]: ../img/03-db-02.png