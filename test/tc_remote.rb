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

class TC_RemoteCache < Test::Unit::TestCase

  def setup
    @server = ::DRb.start_service(nil, Cache.new(0.1, 5))
    @cache = RemoteCache.new(@server.uri, 0.1, 0.01)
  end

  def teardown
    ::DRb.stop_service
  end

  def test_flush
    @cache['t'] = 'test'
    @cache.flush
    assert_equal nil, @cache['t']
  end

  def test_add_fetch
    @cache['t'] = 'test'
    assert_equal 'test', @cache['t']
  end

  def test_fetch_or_add
    assert_equal nil, @cache['t']
    @cache.fetch_or_add('t') { 'test' }
    assert_equal 'test', @cache['t']
  end

  def test_size
    1.upto(5) {|i| @cache[i] = i }
    1.upto(5) do |i|
      assert_equal i, @cache[i]
    end
    6.upto(10) {|i| @cache[i] = i }
    1.upto(5) do |i|
      assert_equal nil, @cache[i]
    end
  end

  def test_ttl
    1.upto(5) {|i| @cache[i] = i }
    1.upto(5) do |i|
      assert_equal i, @cache[i]
    end
    sleep(0.2)
    1.upto(5) do |i|
      assert_equal nil, @cache[i]
    end
  end

  def test_timeout
    slow = Thread.new do
      @cache.fetch_or_add('t') { sleep 0.2; 'slow' }
    end
    sleep 0.01
    @cache.fetch_or_add('t') { 'fast' }
    assert_equal 'fast', @cache['t']
    slow.join
    @cache.delete('t')

    decent = Thread.new do
      @cache.fetch_or_add('t') { sleep 0.03; 'decent' }
    end
    sleep 0.01
    @cache.fetch_or_add('t') { 'fast' }
    assert_equal 'decent', @cache['t']
    decent.join
  end
end
