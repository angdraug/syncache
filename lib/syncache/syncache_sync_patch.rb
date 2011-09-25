# Monkey patch for standard sync.rb (see bug #11680 on RubyForge).

if RUBY_VERSION < "1.8.7" or (RUBY_VERSION == "1.8.7" and RUBY_PATCHLEVEL < 173)

module Sync_m
  class Err < StandardError
    def Err.Fail(*opt)
      Thread.critical = false
      fail self, sprintf(self::Message, *opt)
    end
  end

  def sync_try_lock(mode = EX)
    return unlock if mode == UN

    Thread.critical = true
    ret = sync_try_lock_sub(mode)
    Thread.critical = false
    ret
  end
end

elsif RUBY_VERSION >= "1.9.0"

module Sync_m
  def sync_try_lock(mode = EX)
    return unlock if mode == UN
    ret = nil
    @sync_mutex.synchronize do
      ret = sync_try_lock_sub(mode)
    end
    ret
  end
end

class Object
  remove_const :Sync
  remove_const :Synchronizer
end

class Sync_c
  include Sync_m
end

Synchronizer = Sync = Sync_c

end
