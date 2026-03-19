import asyncio
import os
import sys
from datetime import datetime
import certifi

# Fix SSL for Python 3.13 before importing pymongo
os.environ['SSL_CERT_FILE'] = certifi.where()

from database import connect_db, get_db, close_db
from services.strictness_service import evaluate_user_strictness
from bson import ObjectId

async def main():
    await connect_db()
    db = get_db()
    
    # 1. Create a mock user
    user_id = str(ObjectId())
    await db.users.insert_one({
        "_id": ObjectId(user_id),
        "name": "Strictness Test",
        "email": f"test_{user_id}@test.com",
    })
    
    today = datetime.now().strftime("%Y-%m-%d")
    
    print("--- Test 1: First Evaluation (No Sessions) ---")
    res1 = await evaluate_user_strictness(user_id, today)
    print(f"Result: {res1}")
    assert res1["warnings"] == 1
    assert res1["level"] == "WARNING_1"
    
    # Fast forward: Test Warning 2
    # To bypass the 'already evaluated today' check we just manually clear last_evaluated
    await db.users.update_one({"_id": ObjectId(user_id)}, {"$set": {"strictness_settings.last_evaluated": None}})
    
    print("\n--- Test 2: Second Evaluation (Still No Sessions) ---")
    res2 = await evaluate_user_strictness(user_id, today)
    print(f"Result: {res2}")
    assert res2["warnings"] == 2
    assert res2["level"] == "WARNING_2"
    
    # Fast forward: Test Lockdown
    await db.users.update_one({"_id": ObjectId(user_id)}, {"$set": {"strictness_settings.last_evaluated": None}})
    
    print("\n--- Test 3: Third Evaluation (Lockdown) ---")
    res3 = await evaluate_user_strictness(user_id, today)
    print(f"Result: {res3}")
    assert res3["warnings"] == 3
    assert res3["level"] == "LOCKDOWN"
    
    # Fast forward: Test Good Behavior (Reduces warning)
    await db.users.update_one({"_id": ObjectId(user_id)}, {"$set": {"strictness_settings.last_evaluated": None}})
    
    # Insert a good session for today
    await db.sessions.insert_one({
        "user_id": user_id,
        "completed_at": datetime.now().isoformat(),
        "productivity_score": 100
    })
    
    print("\n--- Test 4: Good Behavior (Reduces Warnings) ---")
    res4 = await evaluate_user_strictness(user_id, today)
    print(f"Result: {res4}")
    assert res4["warnings"] == 2
    
    # Cleanup
    await db.users.delete_one({"_id": ObjectId(user_id)})
    await db.sessions.delete_one({"user_id": user_id})
    await close_db()
    print("\nAll strictness tests passed!")

if __name__ == "__main__":
    asyncio.run(main())
