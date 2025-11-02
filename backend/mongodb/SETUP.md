# MongoDB Atlas Setup for Bitcoin Watcher

## Prerequisites
- MongoDB Atlas account (free tier)
- Database user with read/write permissions

## Collections

### 1. btc_prices (Time Series Collection)
```javascript
db.createCollection("btc_prices", {
  timeseries: {
    timeField: "timestamp",
    metaField: "metadata",
    granularity: "seconds"
  }
});

// Create index for better query performance
db.btc_prices.createIndex({ "timestamp": -1 });
```

### 2. signals
```javascript
db.createCollection("signals");

// Create indexes
db.signals.createIndex({ "timestamp": -1 });
db.signals.createIndex({ "type": 1 });
```

### 3. notifications
```javascript
db.createCollection("notifications");

// Create indexes
db.notifications.createIndex({ "timestamp": -1 });
db.notifications.createIndex({ "signal_id": 1 });
db.notifications.createIndex({ "signal_type": 1 });
```

## Setup Steps

### 1. Create MongoDB Atlas Cluster
1. Go to https://cloud.mongodb.com/
2. Create a new account or sign in
3. Click "Build a Database"
4. Choose "FREE" tier (M0)
5. Select your preferred cloud provider and region
6. Name your cluster (e.g., "bitcoin-watcher")
7. Click "Create"

### 2. Configure Network Access
1. Go to "Network Access" in the left menu
2. Click "Add IP Address"
3. Either add your current IP or allow access from anywhere (0.0.0.0/0)
   - For production, restrict to your AWS Lambda IP ranges
4. Click "Confirm"

### 3. Create Database User
1. Go to "Database Access" in the left menu
2. Click "Add New Database User"
3. Choose "Password" authentication
4. Create username and strong password
5. Select "Read and write to any database"
6. Click "Add User"

### 4. Get Connection String
1. Go to "Database" in the left menu
2. Click "Connect" on your cluster
3. Choose "Connect your application"
4. Copy the connection string
5. Replace `<password>` with your database user password
6. Replace `<database>` with `bitcoin_watcher`

Example connection string:
```
mongodb+srv://username:password@cluster0.xxxxx.mongodb.net/bitcoin_watcher?retryWrites=true&w=majority
```

### 5. Create Collections via MongoDB Shell
1. Click "Connect" on your cluster
2. Choose "MongoDB Shell"
3. Follow instructions to install mongosh
4. Connect to your cluster
5. Run the collection creation commands above

Or use MongoDB Compass:
1. Download MongoDB Compass
2. Connect using your connection string
3. Create database "bitcoin_watcher"
4. Create collections as specified above

### 6. Store Connection String in AWS
```bash
# Store MongoDB URI in AWS Systems Manager Parameter Store
aws ssm put-parameter \
  --name "/bitcoin-watcher/mongodb-uri" \
  --value "mongodb+srv://username:password@cluster0.xxxxx.mongodb.net/bitcoin_watcher?retryWrites=true&w=majority" \
  --type "SecureString" \
  --description "MongoDB connection string for Bitcoin Watcher"
```

## Time Series Collection Benefits
- Optimized storage for time-based data
- Automatic data expiration (TTL) options
- Better query performance for time-range queries
- Reduced storage costs

## Data Retention (Optional)
To automatically expire old data after 30 days:
```javascript
db.btc_prices.createIndex(
  { "timestamp": 1 },
  { expireAfterSeconds: 2592000 }  // 30 days
);
```

## Monitoring
- Check "Metrics" tab in Atlas to monitor:
  - Operations per second
  - Storage usage
  - Network traffic
  - Query performance

## Free Tier Limits
- 512 MB storage
- Shared RAM
- Shared vCPUs
- Perfect for this application's needs
