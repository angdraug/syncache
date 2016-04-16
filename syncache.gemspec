Gem::Specification.new do |spec|
  spec.name        = 'syncache'
  spec.version     = '1.4'
  spec.author      = 'Dmitry Borodaenko'
  spec.email       = 'angdraug@debian.org'
  spec.homepage    = 'https://github.com/angdraug/syncache'
  spec.summary     = 'Thread-safe time-limited cache with flexible replacement policy'
  spec.description = <<-EOF
SynCache stores cached objects in a Hash that is protected by an advanced
two-level locking mechanism which ensures that:

 * Multiple threads can add and fetch objects in parallel.
 * While one thread is working on a cache entry, other threads can access
   the rest of the cache with no waiting on the global lock, no race
   conditions nor deadlock or livelock situations.
 * While one thread is performing a long and resource-intensive
   operation, other threads that request the same data will be put on hold,
   and as soon as the first thread completes the operation, the result will be
   returned to all threads.
    EOF
  spec.files       = %w(COPYING ChangeLog.mtn README.rdoc setup.rb Rakefile
                        syncache.gemspec bin/syncache-drb man/syncache-drb.1) +
                     Dir['{lib,test}/**/*.rb']
  spec.test_files  = Dir['test/ts_*.rb']
  spec.executables = spec.files.map{|p| p =~ /^bin\/(.*)/ ? $1 : nil }.compact
  spec.license     = 'GPL-3.0+'
end
