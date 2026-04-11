# Data Warehouses

## OLAP vs OLTP

**OLTP (Online Transactional Processing)** and **OLAP (Online Analytical Processing)** are different database systems optimized for distinct purposes. OLTP powers day-to-day operations with fast, real-time, row-based transactions (e.g., banking). OLAP enables complex analysis and decision-making, using columnar storage to aggregate large historical datasets.

|  | OLTP | OLAP |
| - | - | - |
| Purpose  | Control and run essential business operations in real time  |  Plan, solve problems, support decisions, discover hidden insights |   
| Data updates | Short, fast updates initiated by user | Data periodically refreshed with scheduled, long-running batch jobs |
| Database design | *Normalized* databases for efficiency | *Denormalized* databases for analysis |
| Space requirements | Generally small if historical data is archived | Generally large due to aggregating large datasets |
| Backup and recovery | Regular backups required to ensure business continuity and meet legal and governance requirements | Lost data can be reloaded from OLTP database as needed in lieu of regular backups |
| Productivity | Increases productivity of end users | Increases productivity of business managers, data analysts, and executives |
| Data view | Lists day-to-day business transactions | Multi-dimensional view of enterprise data |
| User examples | Customer-facing personnel, clerks, online shoppers | Knowledge workers, such as data analysts, business analysts, and executives |

## What is a data warehouse?

A **data warehouse** is an OLAP solution used for reporting and data analysis. It serves as a centralized repository that aggregates data from multiple sources and generally consists of raw data, metadata, and summary data.

![Data warehouse architecture](https://upload.wikimedia.org/wikipedia/commons/8/8d/Data_warehouse_architecture.jpg)

*Image courtesy of [Soha jamil via Wikimedia Commons](https://commons.wikimedia.org/wiki/File:Data_warehouse_architecture.jpg)*

A **data mart** is a focused subset of a data warehouse, designed to serve the specific needs of a particular department or business unit (e.g., Purchasing, Sales, or Inventory). It acts as a curated repository of data, enabling faster insights, increased user performance, and easier access compared to searching a complex, enterprise-wide data warehouse.

Original data warehouses were hosted on-premises. While they do offer some advantages in improved latency and security over sensitive data and hardware, on-premises data warehouses come with high upfront costs, rigid scalability, and manual installation and maintenance. In contrast, cloud-based warehouses like Snowflake, Google BigQuery, Amazon Redshift, and Databricks allow organizations to scale operations elastically with high availability. These modern platforms follow a pay-as-you-go model and offload infrastructure maintenance, patching, and hardware management to the service provider.

## Snowflake

Snowflake is a cloud-native, data platform that brings together data storage, processing, and analysis. A brief introduction into the platform can be found [here](03-data-warehouse/snowflake-intro.md). 

In this module, we will integrate AWS S3 with Snowflake to perform queries and data analysis. By using a **Storage Integration** object, we can use AWS IAM roles to allow Snowflake to access authorized S3 buckets without having to directly provide credentials.

### Prerequisites

This module picks up from the last one where we used Kestra to load the NYC taxi data into a S3 bucket. Using the `09_aws_taxi_scheduled.yaml` [flow](02-workflow-orchestration/flows/09_aws_taxi_scheduled.yaml), I retrieved the data for 2019 and 2020 using backfill.

### Configure secure access to AWS

While the full guide can be found in [Snowflake's documentation](https://docs.snowflake.com/en/user-guide/data-load-s3-config-storage-integration), I will highlight some of the steps here.

#### Configure S3 permissions

In the AWS Management Console, create a policy that provides Snowflake with read-only access to the S3 bucket.  

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
            "Resource": "arn:aws:s3:::ln-zoomcamp-kestra-aws/raw/green/*"
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
                        "raw/green/*"
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

#### Create IAM role

From the IAM Dashboard:
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

#### Create cloud storage integration

In Snowflake, execute the following SQL command as an `ACCOUNTADMIN` or a role with `CREATE INTEGRATION` privilege:

```sql
CREATE STORAGE INTEGRATION s3_integration
  TYPE = EXTERNAL_STAGE
  STORAGE_PROVIDER = 'S3'
  ENABLED = TRUE
  STORAGE_AWS_ROLE_ARN = 'arn:aws:iam::<account_id>:role/zoomcamp_snowflake_role'
  STORAGE_ALLOWED_LOCATIONS = ('s3://ln-zoomcamp-kestra-aws/raw/green/');
```

- Replace the value for `STORAGE_AWS_ROLE_ARN` with the **ARN** for the `zoomcamp_snowflake_role` created in the previous step. 
- Replace the value for `STORAGE_ALLOWED_LOCATIONS` with your bucket name

#### Establish the Trust Relationship

Run the following SQL command in Snowflake:

```sql
DESC INTEGRATION s3_integration;
```

We'll use the values for `STORAGE_AWS_IAM_USER_ARN` and `STORAGE_AWS_EXTERNAL_ID` to replace the account ID and external ID placeholders we used earlier.

| Property | Description |
| - | - |
| `STORAGE_AWS_IAM_USER_ARN` | Snowflake provisions a single IAM user for your entire Snowflake account. All S3 storage integrations in your account use that IAM user. |
| `STORAGE_AWS_EXTERNAL_ID` | The external ID that Snowflake uses to establish a trust relationship with AWS. |


Back in the AWS Management Console:
1. Click on the **Trust relationships** tab of your created role's summary page
2. Click on **Edit trust policy**
3. Replace the value for `AWS` with the value from `STORAGE_AWS_IAM_USER_ARN`
    - Previously we used our AWS account ID
4. Replace the value for `sts:ExternalId` with the value from `STORAGE_AWS_EXTERNAL_ID`
    - Previously we used `0000`
5. Click on **Update policy** to save your changes

### Create an external stage 
Back in Snowflake, we'll create a **File Format** object that instructs Snowflake how to interpret our CSV files.

```sql
CREATE OR REPLACE FILE FORMAT nyc_csv_format 
  TYPE = 'CSV' 
  FIELD_DELIMITER = ',' 
  SKIP_HEADER = 1;
```

We'll then create an external stage that references the storage integration using the following command:

```sql
CREATE OR REPLACE STAGE zoomcamp_s3_stage
  STORAGE_INTEGRATION = s3_integration
  URL = 's3://ln-zoomcamp-kestra-aws/raw/green/'
  FILE_FORMAT = nyc_csv_format;
```

We should be able to verify that connection was successful and view all of the CSV files in the bucket with the following SQL command:

```sql
List @zoomcamp_s3_stage
```

![03-ct-01]

#### Query external stage

We can query the files in the stage directly without having to load it into a table. The following command shows the first 3 columns and the originating CSV file for each of the first 10 rows.

```sql
SELECT 
    $1::INT as vendor_id,
    $2::TIMESTAMP as pickup_datetime,
    $3::TIMESTAMP  as dropoff_datetime,
    metadata$filename
FROM @zoomcamp_s3_stage
LIMIT 10;
```

![03-ct-02]

When we run the `COUNT` function, we'll see that there are 6,835,902 rows in the stage.

```sql
SELECT COUNT($1) FROM @zoomcamp_s3_stage
```

### Create table and load data

For faster performance and easier querying, we'll move the data from the external stage into a table.

To create the table, we'll refer to the [NYC Green Trips Data Dictionary](https://www.nyc.gov/assets/tlc/downloads/pdf/data_dictionary_trip_records_green.pdf) and use the following command:

```sql
CREATE OR REPLACE TABLE stg_nyc_taxi_raw (
    VendorID TEXT,
    lpep_pickup_datetime TIMESTAMP_NTZ,
    lpep_dropoff_datetime TIMESTAMP_NTZ,
    store_and_fwd_flag TEXT,
    RatecodeID TEXT,
    PULocationID TEXT,
    DOLocationID TEXT,
    passenger_count INTEGER,
    trip_distance DOUBLE PRECISION,
    fare_amount DOUBLE PRECISION,
    extra DOUBLE PRECISION,
    mta_tax DOUBLE PRECISION,
    tip_amount DOUBLE PRECISION,
    tolls_amount DOUBLE PRECISION,
    ehail_fee DOUBLE PRECISION,
    improvement_surcharge DOUBLE PRECISION,
    total_amount DOUBLE PRECISION,
    payment_type TEXT,
    trip_type TEXT,
    congestion_surcharge DOUBLE PRECISION,
    source_file_name TEXT
);
```

We can then load the data with:

```sql
COPY INTO stg_nyc_taxi_raw
FROM (
  SELECT 
    $1,$2,$3,$4,$5,$6,$7,$8,$9,$10,                -- Select all 20 columns from stage
    $11,$12,$13,$14,$15,$16,$17,$18,$19,$20,
    metadata$filename                              -- Include the filename metadata
  FROM @zoomcamp_s3_stage
)
FILE_FORMAT = nyc_csv_format;
```

#### Query table data

We'll view the first 10 rows of the `stg_nyc_taxi_raw` table with:

```sql
SELECT * 
FROM stg_nyc_taxi_raw 
LIMIT 10;
```

![03-ct-03]

Running the `COUNT` function shows that there are 6,835,902 rows in the table, indicating that all of the data from `zoomcamp_s3_stage` was copied over.





[03-ct-01]: ../img/03-ct-01.png
[03-ct-02]: ../img/03-ct-02.png
[03-ct-03]: ../img/03-ct-03.png