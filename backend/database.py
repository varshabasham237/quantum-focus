"""
MongoDB connection using Motor (async driver).
SSL fix for Python 3.13 + OpenSSL 3.0.x + MongoDB Atlas.
"""

import os
import ssl
import certifi

# Fix SSL for Python 3.13 — must be set BEFORE importing pymongo/motor
os.environ['SSL_CERT_FILE'] = certifi.where()

from motor.motor_asyncio import AsyncIOMotorClient
from config import settings

# Module-level client and database references
client: AsyncIOMotorClient = None
database = None


async def connect_db():
    """Connect to MongoDB Atlas."""
    global client, database

    # Create a permissive SSL context for Python 3.13 
    ssl_context = ssl.create_default_context(cafile=certifi.where())
    ssl_context.check_hostname = True
    ssl_context.verify_mode = ssl.CERT_REQUIRED

    client = AsyncIOMotorClient(
        settings.MONGODB_URI,
        tls=True,
        tlsCAFile=certifi.where(),
        serverSelectionTimeoutMS=10000,
        connectTimeoutMS=10000,
    )
    database = client[settings.MONGODB_DB_NAME]

    # Test connection
    try:
        await client.admin.command("ping")
        print(f"[DB] Connected to MongoDB: {settings.MONGODB_DB_NAME}")
    except Exception as e:
        print(f"[DB] Warning: Could not ping MongoDB, but proceeding anyway: {e}")
        print("[DB] Lazy connection will be used on first actual query")


async def close_db():
    """Close the database connection."""
    global client
    if client:
        client.close()
        print("[DB] MongoDB connection closed")


def get_db():
    """Get the database instance."""
    return database
