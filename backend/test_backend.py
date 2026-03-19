"""Quick test script to verify backend components."""
import sys
sys.path.insert(0, '.')
import asyncio
from database import connect_db, get_db
from utils.security import hash_password, verify_password

async def test():
    # Test 1: bcrypt
    print("Testing bcrypt...")
    h = hash_password("test123")
    print(f"  Hash OK: {h[:20]}...")
    ok = verify_password("test123", h)
    print(f"  Verify OK: {ok}")
    
    # Test 2: MongoDB
    print("Testing MongoDB...")
    await connect_db()
    db = get_db()
    
    # Find
    r = await db.users.find_one({"email": "probe@test.com"})
    print(f"  Find OK: {r}")
    
    # Insert
    result = await db.users.insert_one({
        "email": "probe@test.com",
        "name": "Probe",
        "password_hash": h,
        "created_at": "2025-01-01",
    })
    print(f"  Insert OK: {result.inserted_id}")
    
    # Cleanup
    await db.users.delete_one({"email": "probe@test.com"})
    print(f"  Delete OK")
    
    print("\nAll tests passed!")

asyncio.run(test())
