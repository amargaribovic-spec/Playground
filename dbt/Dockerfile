# dbt + the ClickHouse adapter, so nobody needs Python on their machine.
FROM python:3.12-slim
RUN pip install --no-cache-dir "dbt-core==1.11.17" "dbt-clickhouse==1.10.2"
WORKDIR /usr/app/meter_project
ENTRYPOINT ["dbt"]
