import logging
import os

from azure.core import MatchConditions
from azure.core.exceptions import (
    AzureError,
    ResourceExistsError,
    ResourceModifiedError,
    ResourceNotFoundError,
)
from azure.data.tables import TableServiceClient, UpdateMode
from azure.identity import DefaultAzureCredential
from flask import Flask, jsonify

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

table_service = TableServiceClient(
    endpoint=f"https://{os.environ['TABLE_ACCOUNT']}.table.core.windows.net",
    credential=DefaultAzureCredential(),
)
table_client = table_service.get_table_client(os.environ["TABLE_NAME"])
app = Flask(__name__)


def increment_access_count():
    for _ in range(12):
        try:
            entity = table_client.get_entity(
                partition_key="site",
                row_key="access-count",
            )
        except ResourceNotFoundError:
            try:
                table_client.create_entity(
                    {
                        "PartitionKey": "site",
                        "RowKey": "access-count",
                        "count": 1,
                    }
                )
                return 1
            except ResourceExistsError:
                continue

        count = int(entity["count"]) + 1
        entity["count"] = count
        try:
            table_client.update_entity(
                entity=entity,
                mode=UpdateMode.REPLACE,
                etag=entity.metadata["etag"],
                match_condition=MatchConditions.IfNotModified,
            )
            return count
        except ResourceModifiedError:
            continue

    raise RuntimeError("Could not increment the access counter after repeated conflicts.")


@app.post("/api/access")
def record_access():
    try:
        return jsonify(count=increment_access_count())
    except AzureError:
        logger.exception("Could not update the Azure Table Storage access counter.")
        return jsonify(error="The access counter is temporarily unavailable."), 503
