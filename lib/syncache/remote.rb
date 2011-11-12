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

require 'drb'
require 'delegate'

module SynCache

REMOTE_TIMEOUT = 60 * 5   # 5 minutes
REMOTE_FIRST_DELAY = 0.1    # 100 ms

class Placeholder
  def initialize
    @id = rand(9223372036854775808)
    @timestamp = Time.now
  end

  attr_reader :id, :timestamp

  def ===(other)
    other.kind_of?(Placeholder) and other.id == @id
  end
end

# Connects to a remote SynCache instance over DRb at the provided URI and
# replaces the remote fetch_or_add method with a slightly less bullet-proof
# version that invokes the supplied block locally (instead of sending it over
# DRb to the cache and then back to a different local thread via a local DRb
# service).
#
# If another RemoteCache client is already working on the same key, this client
# will wait, using randomly increasing intervals. When a configured timeout
# runs out (counting from the time the other client has put a placeholder in
# the cache), the client will give up, discard the other client's placeholder
# and start working on the key itself.
#
# Mixing access to the same cache entries from direct and RemoteCache clients
# is not recommended.
#
class RemoteCache
  def initialize(uri, timeout=REMOTE_TIMEOUT, first_delay=REMOTE_FIRST_DELAY)
    @timeout = timeout
    @first_delay = first_delay
    @cache = DRbObject.new_with_uri(uri)
  end

  def method_missing(method, *args)
    @cache.send(method, *args)
  end

  def fetch_or_add(key)
    placeholder = Placeholder.new
    value = @cache.fetch_or_add(key) { placeholder }

    case value
    when placeholder
      # our placeholder
      value = @cache[key] = yield

    when Placeholder
      # someone else's placeholder
      delay = @first_delay
      while value.kind_of?(Placeholder) and Time.now < value.timestamp + @timeout
        sleep(delay)
        delay *= 1 + rand
        value = @cache[key]
      end

      if value.kind_of?(Placeholder)
        # ran out of time: give up and do it ourselves
        @cache.delete(key)
        @cache[key] = Placeholder.new
        value = @cache[key] = yield
      end
    end

    value
  end
end

end   # module SynCache
