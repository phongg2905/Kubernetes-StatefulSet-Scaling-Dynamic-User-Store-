import os
from pymongo import MongoClient

MONGODB_URI = os.getenv(
    "MONGODB_URI",
    "mongodb://localhost:27017/?directConnection=true"
)

DATABASE_NAME = "dynamic_user_store"
COLLECTION_NAME = "users"


def main():
    client = MongoClient(MONGODB_URI, serverSelectionTimeoutMS=5000)
    client.admin.command("ping")

    db = client[DATABASE_NAME]
    collection = db[COLLECTION_NAME]

    count = collection.count_documents({})
    print(f"User count: {count}")

    sample_user = collection.find_one({}, {"_id": 0})
    print("Sample user:")
    print(sample_user)

    client.close()


if __name__ == "__main__":
    main()