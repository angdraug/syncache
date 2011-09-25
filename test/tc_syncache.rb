#!/usr/bin/env ruby
#
# SynCache tests
#
#   Copyright (c) 2002-2011  Dmitry Borodaenko <angdraug@debian.org>
#
#   This program is free software.
#   You can distribute/modify this program under the terms of
#   the GNU General Public License version 3 or later.
#
# vim: et sw=2 sts=2 ts=8 tw=0

require 'test/unit'
require 'syncache'

include SynCache

class TC_Cache < Test::Unit::TestCase

  def test_flush
    cache = Cache.new(3, 5)
    cache['t'] = 'test'
    cache.flush
    assert_equal nil, cache['t']
  end

  def test_add_fetch
    cache = Cache.new(3, 5)
    cache['t'] = 'test'
    assert_equal 'test', cache['t']
  end

  def test_fetch_or_add
    cache = Cache.new(3, 5)
    assert_equal nil, cache['t']
    cache.fetch_or_add('t') { 'test' }
    assert_equal 'test', cache['t']
  end

  def test_size
    cache = Cache.new(3, 5)
    1.upto(5) {|i| cache[i] = i }
    1.upto(5) do |i|
      assert_equal i, cache[i]
    end
    6.upto(10) {|i| cache[i] = i }
    1.upto(5) do |i|
      assert_equal nil, cache[i]
    end
  end

  def test_ttl
    cache = Cache.new(0.01, 5)
    1.upto(5) {|i| cache[i] = i }
    1.upto(5) do |i|
      assert_equal i, cache[i]
    end
    sleep(0.02)
    1.upto(5) do |i|
      assert_equal nil, cache[i]
    end
  end
end
