# scripts/generate_users.py

import json
import random
from faker import Faker

fake = Faker()

users = []

for i in range(1, 10001):
    user = {
        "user_id": i,
        "username": fake.user_name(),
        "full_name": fake.name(),
        "email": fake.unique.email(),
        "age": random.randint(18, 65),
        "country": fake.country(),
        "city": fake.city(),
        "phone": fake.phone_number(),
        "job": fake.job(),
    }
    users.append(user)

with open("../dataset/users.json", "w", encoding="utf-8") as f:
    json.dump(users, f, indent=2, ensure_ascii=False)

print("Generated 10,000 user profiles in dataset/users.json")