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


## Resources
- [Snowflake key concepts and architecture](https://docs.snowflake.com/en/user-guide/intro-key-concepts) - Snowflake Documentation
- [Learn Snowflake – Full 1-Hour Crash Course for Complete Beginners](https://www.youtube.com/watch?v=2t-ls6ekA8E) - YouTube video from [Tom Bailey](https://www.youtube.com/@tombaileycourses)