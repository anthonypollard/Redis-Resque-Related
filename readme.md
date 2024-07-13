=============== **A Bash script to iterate over a Redis + Resque database that uses the resque-status gem** ===============

This will delete the associated key, and the key that lurks inside resque:_statuses which also 
Updates pagination on /statuses. Includes sanity checks, retries, safe fails/waits/resumes
And rate limiters to prevent interupting a production environment (like running out of ulimit). 
Remove the sleeps if ulimit is not an issue (or > 4096 for most). Assumes the db is db:0, 
Check that with the command "redis-cli INFO keyspace" and update the var. 

Redis server 3.0.6 requires a restart to reflect recovered ram after key deletion.
TTL/Key Expiration is recommended to be set so it applies to all new keys before running.
TTL/Expired keys recover ram correctly in redis-server 3.0.6

With limiters, actual throughput was ~30 keys/sec.

=============== **Est. Time to iterate with default limiters** ===============

10,000     keys - 5m 30s

50,000     keys - 27m 45s

100,000    keys - 55m 30s

1,000,000  keys - 9hr 15m

10,000,000 keys - 92hr 32m

50,000,000 keys - 19d 7h


=============== **Est. Time to iterate without limites** ===============

10,000     keys - 33s

50,000     keys - 2m 45s

100,000    keys - 5m 30s

1,000,000  keys - 55m 30s

10,000,000 keys - 9h 15m

50,000,000 keys - 1d 22hr 17m
