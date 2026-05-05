import json
import os
from pathlib import Path
from pymongo import MongoClient

DATASET_PATH = Path("dataset/users.json")
MONGODB_URI = os.getenv(
    "MONGODB_URI",
    "mongodb://localhost:27017/?directConnection=true"
)

DATABASE_NAME = "dynamic_user_store"
COLLECTION_NAME = "users"
BATCH_SIZE = 1000


def main():
    if not DATASET_PATH.exists():
        raise FileNotFoundError(f"Dataset not found: {DATASET_PATH}")

    with open(DATASET_PATH, "r", encoding="utf-8") as file:
        users = json.load(file)

    print(f"Loaded {len(users)} users from {DATASET_PATH}")

    client = MongoClient(MONGODB_URI, serverSelectionTimeoutMS=5000)
    client.admin.command("ping")

    db = client[DATABASE_NAME]
    collection = db[COLLECTION_NAME]

    print("Clearing old users...")
    collection.delete_many({})

    print("Creating unique index on user_id...")
    collection.create_index("user_id", unique=True)

    print("Inserting users...")
    for start in range(0, len(users), BATCH_SIZE):
        batch = users[start:start + BATCH_SIZE]
        collection.insert_many(batch)
        print(f"Inserted {start + len(batch)} / {len(users)} users")

    final_count = collection.count_documents({})
    print(f"Final user count: {final_count}")

    client.close()


if __name__ == "__main__":
    main()