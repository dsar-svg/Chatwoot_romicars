module CacheKeysHelper
  def get_prefixed_cache_key(account_id, key)
    "idb-cache-key-account-#{account_id}-#{key}"
  end

  def fetch_value_for_key(account_id, key)
    prefixed_cache_key = get_prefixed_cache_key(account_id, key)
    value_from_cache = Redis::Alfred.get(prefixed_cache_key)

    return value_from_cache if value_from_cache.present?

    # An expired key gets a new one, never a constant. With the old fixed '0000000000', a
    # browser that had cached its list under that value took every later expiry as "nothing
    # changed" and kept showing inboxes from weeks ago. `nx` so two requests agree on one key.
    Redis::Alfred.set(prefixed_cache_key, Time.now.utc.to_i, nx: true, ex: CacheKeys::CACHE_KEYS_EXPIRY.to_i)
    Redis::Alfred.get(prefixed_cache_key)
  end
end
