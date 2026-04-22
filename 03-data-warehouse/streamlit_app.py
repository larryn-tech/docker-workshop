import json

import _snowflake
import pandas as pd
import plotly.graph_objects as go
import streamlit as st
from plotly.subplots import make_subplots
from snowflake.snowpark.context import get_active_session

# ------------------- Constants -------------------
COLOR_2019 = "#6d9ced"  # Blue
COLOR_2020 = "#F6C53F"  # Yellow
COLOR_COVID = "#F8756C"  # Red

SEMANTIC_VIEW = "ZOOMCAMP_DATABASE.ANALYTICS.GREEN_TAXI_TRIPS_COVID_IMPACT_REPORT"
API_ENDPOINT = "/api/v2/cortex/analyst/message"
API_TIMEOUT = 50000  # in milliseconds


# ------------------- Streamlit Page Config -------------------
st.set_page_config(
    page_title="NYC taxi pandemic impact dashboard",
    layout="wide",
)


# ------------------- Database Connection & Data Loading -------------------
session = get_active_session()
df = session.table(SEMANTIC_VIEW).to_pandas()


# ------------------- Data Preparation -------------------
df["Date"] = pd.to_datetime(df["PICKUP_DATE"])
df["YEAR"] = df["Date"].dt.year.astype(str)
df["MONTH_NUM"] = df["Date"].dt.month
df["MONTH_NAME"] = df["Date"].dt.month_name()

date_columns = {"YEAR": "Year", "MONTH_NUM": "Month_num", "MONTH_NAME": "Month"}

taxi_columns = {
    "TRIP_COUNT": "Total Trips",
    "AVG_TRIP_DISTANCE_MILES": "Average Trip Distance (miles)",
    "TOTAL_TRIP_DISTANCE_MILES": "Total Trip Distance (miles)",
    "AVG_FARE_AMOUNT": "Average Trip Fare ($)",
    "TOTAL_FARE": "Total Fare Amount ($)",
}

covid_columns = {
    "DAILY_NEW_CASES": "New COVID Cases",
    "CUMULATIVE_COVID_CASES": "Total COVID Cases (Cumulative)",
    "DAILY_NEW_DEATHS": "New COVID Deaths",
    "CUMULATIVE_COVID_DEATHS": "Total COVID Deaths (Cumulative)",
}

agg_columns = {"AVG_TRIPS_PER_DAY": "Average Trips per Day"}

# Monthly data
monthly_df = (
    df.groupby(["YEAR", "MONTH_NUM", "MONTH_NAME"])
    .agg(
        TRIP_COUNT=("TRIP_COUNT", "sum"),
        TOTAL_FARE=("TOTAL_FARE", "sum"),
        TOTAL_TRIP_DISTANCE_MILES=("TOTAL_TRIP_DISTANCE_MILES", "sum"),
        AVG_TRIPS_PER_DAY=("TRIP_COUNT", "mean"),
    )
    .reset_index()
)

# Calculate average fare and trip distance for the month
monthly_df["AVG_FARE_AMOUNT"] = monthly_df["TOTAL_FARE"] / monthly_df["TRIP_COUNT"]
monthly_df["AVG_TRIP_DISTANCE_MILES"] = (
    monthly_df["TOTAL_TRIP_DISTANCE_MILES"] / monthly_df["TRIP_COUNT"]
)

# Round numeric values to two decimal places
monthly_df = monthly_df.round(decimals=2)

# Fix column order and names
df_columns = date_columns | taxi_columns | covid_columns
df_column_order = ["Date"] + list(df_columns)

df = df[df_column_order].rename(columns=df_columns)
df = df.sort_values(by="Date").reset_index(drop=True)

monthly_df_columns = date_columns | agg_columns | taxi_columns
monthly_df_column_order = list(monthly_df_columns)

monthly_df = monthly_df[monthly_df_column_order].rename(columns=monthly_df_columns)
monthly_df = monthly_df.sort_values(by=["Year", "Month_num"]).reset_index(drop=True)

## 2019 and 2020 dataframes
df_2019 = df[df["Year"] == "2019"]
df_2020 = df[df["Year"] == "2020"]

monthly_df_2019 = monthly_df[monthly_df["Year"] == "2019"]
monthly_df_2020 = monthly_df[monthly_df["Year"] == "2020"]


# ------------------- Header -------------------
st.title("NYC Green Taxi Performance (2019–2020)")
st.write("Analyzing the impact of COVID-19 on NYC Green Taxi Operations")


# ------------------- KPIs -------------------
with st.container(border=True):
    st.subheader("2020 Green Taxi Summary")

    cell1, cell2, cell3 = st.columns(3)

    # Total Trips
    with cell1:
        trips_2019 = df_2019["Total Trips"].sum()
        trips_2020 = df_2020["Total Trips"].sum()
        total_trip_change = trips_2020 - trips_2019
        pct_change = (total_trip_change / trips_2019 * 100) if trips_2019 else 0
        st.metric(
            "Total Trips",
            f"{trips_2020:,.0f}",
            f"{total_trip_change:,.0f} ({pct_change:.1f}%)",
        )

    # Total Fare
    with cell2:
        total_fare_2019 = df_2019["Total Fare Amount ($)"].sum()
        total_fare_2020 = df_2020["Total Fare Amount ($)"].sum()
        total_fare_change = total_fare_2020 - total_fare_2019
        pct_fare_change = (total_fare_change / total_fare_2019) * 100
        st.metric(
            "Total Fare",
            f"${total_fare_2020 / 1e6:.1f}M",
            f"{total_fare_change / 1e6:.1f}M ({pct_fare_change:.1f}%)",
        )

    # Total Trip Distance
    with cell3:
        total_dist_2019 = df_2019["Total Trip Distance (miles)"].sum()
        total_dist_2020 = df_2020["Total Trip Distance (miles)"].sum()
        total_dist_change = total_dist_2020 - total_dist_2019
        pct_dist_change = (total_dist_change / total_dist_2019) * 100
        st.metric(
            "Total Trip Distance",
            f"{total_dist_2020 / 1e6:.1f}M miles",
            f"{total_dist_change / 1e6:.1f}M ({pct_dist_change:.1f}%)",
        )

    cell4, cell5, cell6 = st.columns(3)

    # Avg Trips/Day
    with cell4:
        trips_per_day_2019 = df_2019["Total Trips"].mean()
        trips_per_day_2020 = df_2020["Total Trips"].mean()
        avg_trips_change = trips_per_day_2020 - trips_per_day_2019
        pct_avg_trips_change = (avg_trips_change / trips_per_day_2019) * 100
        st.metric(
            "Average Trips per Day",
            f"{trips_per_day_2020:.2f}",
            f"{avg_trips_change:.2f} ({pct_avg_trips_change:.1f}%)",
        )

    # Avg Fare/Trip
    with cell5:
        avg_fare_2019 = total_fare_2019 / trips_2019
        avg_fare_2020 = total_fare_2020 / trips_2020
        avg_fare_change = avg_fare_2020 - avg_fare_2019
        pct_avg_fare_change = (avg_fare_change / avg_fare_2019) * 100
        st.metric(
            "Average Fare per Trip",
            f"${avg_fare_2020:.2f}",
            f"{avg_fare_change:.2f} ({pct_avg_fare_change:.1f}%)",
        )

    # Avg Trip Distance
    with cell6:
        avg_dist_2019 = total_dist_2019 / trips_2019
        avg_dist_2020 = total_dist_2020 / trips_2020
        avg_dist_change = avg_dist_2020 - avg_dist_2019
        pct_avg_dist_change = (avg_dist_change / avg_dist_2019) * 100
        st.metric(
            "Average Distance per Trip",
            f"{avg_dist_2020:.1f} miles",
            f"{avg_dist_change:.1f} ({pct_avg_dist_change:.2f}%)",
        )


# ------------------- Chatbox -------------------
def chatbox():
    if "messages" not in st.session_state:
        st.session_state.messages = []

    user_input = st.chat_input("What is your question?")

    if user_input:
        process_user_input(user_input)


def process_user_input(prompt: str):
    new_user_message = {
        "role": "user",
        "content": [{"type": "text", "text": prompt}],
    }

    st.session_state.messages.append(new_user_message)

    with st.sidebar:
        st.subheader("Ask Cortex Analyst")

        if not st.session_state.messages:
            st.write("Your questions about the data will appear here!")

        with st.chat_message("user"):
            st.markdown(prompt)

        with st.chat_message("assistant"):
            with st.spinner("Generating response..."):
                response = send_message(new_user_message)

                if "ERROR" in response:
                    st.markdown(response["ERROR"])
                    st.stop()
                else:
                    content = response["message"]["content"]
                    display_content(content)

    st.session_state.messages.append({"role": "assistant", "content": content})


def send_message(message: dict) -> dict:
    request_body = {
        "messages": [message],
        "semantic_view": SEMANTIC_VIEW,
    }

    resp = _snowflake.send_snow_api_request(
        "POST",  # method
        API_ENDPOINT,  # path
        {},  # headers
        {},  # params
        request_body,  # body
        None,  # request_guid
        API_TIMEOUT,  # timeout in milliseconds
    )

    # Content is a string with serialized JSON object
    parsed_content = json.loads(resp["content"])

    # Check if the response is successful
    if resp["status"] < 400:
        return parsed_content
    else:
        status_code = resp["status"]
        return {"ERROR": f"ERROR {status_code}: Something went wrong!"}


def display_content(content: list):
    for item in content:
        if item["type"] == "text":
            st.markdown(item["text"])
        elif item["type"] == "sql":
            with st.expander("SQL Query", expanded=False):
                st.code(item["statement"], language="sql")
            with st.expander("Results", expanded=True):
                with st.spinner("Running SQL..."):
                    session = get_active_session()
                    df = session.sql(item["statement"]).to_pandas()
                    st.dataframe(df)
        else:
            pass


chatbox()


# ------------------- 2020 COVID-Taxi Graph -------------------
st.divider()
st.subheader("2020 Green Taxi vs COVID Data")

# Taxi & COVID Metric Choices
taxi_metric_choices = list(taxi_columns.values())
covid_metric_choices = list(covid_columns.values())

# User Controls
col1, col2 = st.columns(2)

with col1:
    selected_taxi_metric = st.selectbox("Taxi Metric (Left Axis)", taxi_metric_choices)

with col2:
    selected_covid_metric = st.selectbox(
        "COVID-19 Metric (Right Axis)", covid_metric_choices
    )

# Dual-Axis Chart
fig = make_subplots(specs=[[{"secondary_y": True}]])

# Taxi Metric (Primary Axis)
fig.add_trace(
    go.Scatter(
        x=df_2020["Date"],
        y=df_2020[selected_taxi_metric],
        name=selected_taxi_metric,
        line=dict(color=COLOR_2020, width=3),
        mode="lines",
    ),
    secondary_y=False,
)

# COVID Metric (Secondary Axis)
fig.add_trace(
    go.Scatter(
        x=df_2020["Date"],
        y=df_2020[selected_covid_metric],
        name=selected_covid_metric,
        line=dict(color=COLOR_COVID, width=3, dash="dot"),
        mode="lines",
    ),
    secondary_y=True,
)

# Chart layout
fig.update_layout(
    title_text=f"Relationship: {selected_taxi_metric} vs. {selected_covid_metric}",
    hovermode="x unified",
    legend=dict(orientation="h", yanchor="bottom", y=1.02, xanchor="right", x=1),
    template="plotly_white",
    height=600,
)

# Set y-axes titles
fig.update_yaxes(title_text=selected_taxi_metric, secondary_y=False)
fig.update_yaxes(title_text=selected_covid_metric, secondary_y=True)

# Display in Streamlit
st.plotly_chart(fig, use_container_width=True)

# Raw data
with st.expander("View Daily Analytics Data"):
    st.dataframe(df.sort_values(by=["Year", "Date"]))


# ------------------- 2019 vs 2020 Taxi Comparison -------------------
st.divider()
st.subheader("2020 vs 2019 Taxi Performance Comparison")

# Taxi Metric Choices
yoy_metric_choices = list(agg_columns.values()) + taxi_metric_choices

# User control
selected_yoy_metric = st.selectbox(
    "Taxi Metric",
    yoy_metric_choices,
)

# Figure
fig2 = go.Figure()

# 2020 data
fig2.add_trace(
    go.Scatter(
        x=monthly_df_2020["Month"],
        y=monthly_df_2020[selected_yoy_metric],
        name="2020",
        line=dict(color=COLOR_2020, width=3),
        mode="lines",
    )
)

# 2019 data
fig2.add_trace(
    go.Scatter(
        x=monthly_df_2019["Month"],
        y=monthly_df_2019[selected_yoy_metric],
        name="2019",
        line=dict(color=COLOR_2019, width=3),
        mode="lines",
    )
)

# Chart layout
fig2.update_layout(
    title_text=selected_yoy_metric,
    hovermode="x unified",
    legend=dict(orientation="h", yanchor="bottom", y=1.02, xanchor="right", x=1),
    template="plotly_white",
    height=600,
)

# Set y-axes titles
fig2.update_yaxes(title_text=selected_yoy_metric)

# Display in Streamlit
st.plotly_chart(fig2, use_container_width=True)

# Raw data
with st.expander("View Monthly Analytics Data"):
    st.dataframe(monthly_df)


# ------------------- Footer -------------------
st.divider()
st.caption(
    "Data: NYC Taxi & Limousine Commission Trip Record Data | New York Times COVID-19 Data"
)
