# SynCache: thread-safe time-limited cache with flexible replacement policy
# (originally written for Samizdat project)
#
#   Copyright (c) 2002-2011  Dmitry Borodaenko <angdraug@debian.org>
#
#   This program is free software.
#   You can distribute/modify this program under the terms of
#   the GNU General Public License version 3 or later.
#
# vim: et sw=2 sts=2 ts=8 tw=0

require 'sync'
require 'syncache/syncache_sync_patch'

module SynCache

FOREVER = 60 * 60 * 24 * 365 * 5   # 5 years

class CacheError < RuntimeError; end

class CacheEntry
  def initialize(ttl = nil, value = nil)
    @value = value
    @ttl = ttl
    @dirty = false
    record_access

    @sync = Sync.new
  end

  # stores the value object
  attr_accessor :value

  # change this to make the entry expire sooner
  attr_accessor :ttl

  # use this to synchronize access to +value+
  attr_reader :sync

  # record the fact that the entry was accessed
  #
  def record_access
    return if @dirty
    @expires = Time.now + (@ttl or FOREVER)
  end

  # entries with lowest index will be replaced first
  #
  def replacement_index
    @expires
  end

  # check if entry is stale
  #
  def stale?
    @expires < Time.now
  end

  # mark entry as dirty and schedule it to expire at given time
  #
  def expire_at(time)
    @expires = time if @expires > time
    @dirty = true
  end
end

class Cache

  # a float number of seconds to sleep when a race condition is detected
  # (actual delay is randomized to avoid live lock situation)
  #
  LOCK_SLEEP = 0.2

  # _ttl_ (time to live) is time in seconds from the last access until cache
  # entry is expired (set to _nil_ to disable time limit)
  # 
  # _max_size_ is max number of objects in cache
  #
  # _flush_delay_ is used to rate-limit flush operations: if less than that
  # number of seconds has passed since last flush, next flush will be delayed;
  # default is no rate limit
  #
  def initialize(ttl = 60*60, max_size = 5000, flush_delay = nil)
    @ttl = ttl
    @max_size = max_size
    @debug = false

    if @flush_delay = flush_delay
      @last_flush = Time.now
    end

    @sync = Sync.new
    @cache = {}
  end

  # set to _true_ to report every single cache operation
  #
  attr_accessor :debug

  # remove all values from cache
  #
  # if _base_ is given, only values with keys matching the base (using
  # <tt>===</tt> operator) are removed
  #
  def flush(base = nil)
    debug { 'flush ' << base.to_s }

    @sync.synchronize do

      if @flush_delay
        next_flush = @last_flush + @flush_delay

        if next_flush > Time.now
          flush_at(next_flush, base)
        else
          flush_now(base)
          @last_flush = Time.now
        end

      else
        flush_now(base)
      end
    end
  end

  # remove single value from cache
  #
  def delete(key)
    debug { 'delete ' << key.to_s }

    @sync.synchronize do
      @cache.delete(key)
    end
  end

  # store new value in cache
  #
  # see also Cache#fetch_or_add
  #
  def []=(key, value)
    debug { '[]= ' << key.to_s }

    entry = get_locked_entry(key)
    begin
      return entry.value = value
    ensure
      entry.sync.unlock
    end
  end

  # retrieve value from cache if it's still fresh
  #
  # see also Cache#fetch_or_add
  #
  def [](key)
    debug { '[] ' << key.to_s }

    entry = get_locked_entry(key, false)
    unless entry.nil?
      begin
        return entry.value
      ensure
        entry.sync.unlock
      end
    end
  end

  # initialize missing cache entry from supplied block
  #
  # this is the preferred method of adding values to the cache as it locks the
  # key for the duration of computation of the supplied block to prevent
  # parallel execution of resource-intensive actions
  #
  def fetch_or_add(key)
    debug { 'fetch_or_add ' << key.to_s }

    entry = get_locked_entry(key)
    begin
      if entry.value.nil?
        entry.value = yield
      end
      return entry.value
    ensure
      entry.sync.unlock
    end
  end

  private

  # immediate flush (delete all entries matching _base_)
  #
  # must be run from inside global lock, see #flush
  #
  def flush_now(base = nil)
    if base
      @cache.delete_if {|key, entry| base === key }
    else
      @cache = {}
    end
  end

  # delayed flush (ensure all entries matching _base_ expire no later than _next_flush_)
  #
  # must be run from inside global lock, see #flush
  #
  def flush_at(next_flush, base = nil)
    @cache.each do |key, entry|
      next if base and not base === key
      entry.expire_at(next_flush)
    end
  end

  def add_blank_entry(key)
    @sync.sync_exclusive? or raise CacheError,
      'add_entry called while @sync is not locked'

    had_same_key = @cache.has_key?(key)
    entry = @cache[key] = CacheEntry.new(@ttl)
    check_size unless had_same_key
    entry
  end

  def get_locked_entry(key, add_if_missing=true)
    debug { "get_locked_entry #{key}, #{add_if_missing}" }

    entry = nil   # scope fix
    entry_locked = false
    until entry_locked do
      @sync.synchronize do
        entry = @cache[key]

        if entry.nil? or entry.stale?
          if add_if_missing
            entry = add_blank_entry(key)
          else
            @cache.delete(key) unless entry.nil?
            return nil
          end
        end

        entry_locked = entry.sync.try_lock
      end
      sleep(rand * LOCK_SLEEP) unless entry_locked
    end

    entry.record_access
    entry
  end

  # remove oldest item from cache if size limit reached
  #
  def check_size
    debug { 'check_size' }

    return unless @max_size.kind_of? Numeric

    @sync.synchronize do
      while @cache.size > @max_size do
        # optimize: supplement hash with queue
        oldest = @cache.keys.min {|a, b| @cache[a].replacement_index <=> @cache[b].replacement_index }

        @cache.delete(oldest)
      end
    end
  end

  # send debug output to syslog if enabled
  #
  def debug
    return unless @debug
    message = Thread.current.to_s + ' ' + yield
    if defined?(Syslog) and Syslog.opened?
      Syslog.debug(message)
    else
      STDERR << 'syncache: ' + message + "\n"
      STDERR.flush
    end
  end
end

end   # module SynCache
