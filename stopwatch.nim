# this code is based on https://github.com/nim-lang/Nim/blob/devel/lib/system/timers.nim

#
#
#            Nim's Runtime Library
#        (c) Copyright 2012 Andreas Rumpf
#
#    See the file "copying.txt", included in this
#    distribution, for details about the copyright.
#

## Timer support for the realtime GC. Based on
## `<https://github.com/jckarter/clay/blob/master/compiler/src/hirestimer.cpp>`_

discard """
=====================================================
Nim -- a Compiler for Nim. http://nim-lang.org/

Copyright (C) 2006-2015 Andreas Rumpf. All rights reserved.

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.

[ MIT license: http://www.opensource.org/licenses/mit-license.php ]
"""

include "system/timers"

type clock* = object
  clockStart*: int64
  clockStop*: int64

proc start*(c: var clock) {.inline.} = c.clockStart = getTicks().Nanos
proc stop*(c: var clock) {.inline.} = c.clockStop = getTicks().Nanos
proc nanoseconds*(c: clock): int64 {.inline.} = c.clockStop - c.clockStart
proc seconds*(c: clock): float {.inline.} = float64(c.clockStop - c.clockStart)/1_000_000_000

template bench*(c: clock, body: stmt): stmt {.immediate.} =
  c.start()
  body
  c.stop()

when isMainModule:
  from os import sleep

  var c: clock

  # example without using the bench abstraction
  c.start()
  sleep(1)
  c.stop()
  echo c.nanoseconds(), " ns" # in nanoseconds
  echo c.seconds, " s"

  # another example using bench
  var c0, c1, c2: clock

  bench(c):
    bench(c0):
      sleep(100)
    bench(c1):
      sleep(50)
    bench(c2):
      for i in 0..<2:
        sleep(1)

  echo "bench 0): ", c0.seconds, " s"
  echo "bench 1): ", c1.seconds, " s"
  echo "bench 2): ", c2.seconds, " s"
  echo "total: ", c.seconds, " s"
