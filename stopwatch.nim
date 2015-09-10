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

# 
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

type
  Ticks* = distinct int64
  Nanos* = int64
{.deprecated: [TTicks: Ticks, TNanos: Nanos].}

when defined(windows):

  proc QueryPerformanceCounter(res: var Ticks) {.
    importc: "QueryPerformanceCounter", stdcall, dynlib: "kernel32".}
  proc QueryPerformanceFrequency(res: var int64) {.
    importc: "QueryPerformanceFrequency", stdcall, dynlib: "kernel32".}

  proc getTicks*(): Ticks {.inline.} =
    QueryPerformanceCounter(result)

  proc `-`*(a, b: Ticks): Nanos =
    var frequency: int64
    QueryPerformanceFrequency(frequency)
    var performanceCounterRate = 1e+9'f64 / float64(frequency)

    result = Nanos(float64(a.int64 - b.int64) * performanceCounterRate)

elif defined(macosx):
  type
    MachTimebaseInfoData {.pure, final, 
        importc: "mach_timebase_info_data_t", 
        header: "<mach/mach_time.h>".} = object
      numer, denom: int32
  {.deprecated: [TMachTimebaseInfoData: MachTimebaseInfoData].}

  proc mach_absolute_time(): int64 {.importc, header: "<mach/mach.h>".}
  proc mach_timebase_info(info: var MachTimebaseInfoData) {.importc,
    header: "<mach/mach_time.h>".}

  proc getTicks*(): Ticks {.inline.} =
    result = Ticks(mach_absolute_time())
  
  var timeBaseInfo: MachTimebaseInfoData
  mach_timebase_info(timeBaseInfo)
    
  proc `-`*(a, b: Ticks): Nanos =
    result = (a.int64 - b.int64)  * timeBaseInfo.numer div timeBaseInfo.denom

elif defined(posixRealtime):
  type
    Clockid {.importc: "clockid_t", header: "<time.h>", final.} = object

    TimeSpec {.importc: "struct timespec", header: "<time.h>", 
               final, pure.} = object ## struct timespec
      tv_sec: int  ## Seconds. 
      tv_nsec: int ## Nanoseconds. 
  {.deprecated: [TClockid: Clickid, TTimeSpec: TimeSpec].}

  var
    CLOCK_REALTIME {.importc: "CLOCK_REALTIME", header: "<time.h>".}: Clockid

  proc clock_gettime(clkId: Clockid, tp: var Timespec) {.
    importc: "clock_gettime", header: "<time.h>".}

  proc getTicks*(): Ticks =
    var t: Timespec
    clock_gettime(CLOCK_REALTIME, t)
    result = Ticks(int64(t.tv_sec) * 1000000000'i64 + int64(t.tv_nsec))

  proc `-`*(a, b: Ticks): Nanos {.borrow.}

else:
  # fallback Posix implementation:  
  type
    Timeval {.importc: "struct timeval", header: "<sys/select.h>", 
               final, pure.} = object ## struct timeval
      tv_sec: int  ## Seconds. 
      tv_usec: int ## Microseconds. 
  {.deprecated: [Ttimeval: Timeval].}
  proc posix_gettimeofday(tp: var Timeval, unused: pointer = nil) {.
    importc: "gettimeofday", header: "<sys/time.h>".}

  proc getTicks*(): Ticks =
    var t: Timeval
    posix_gettimeofday(t)
    result = Ticks(int64(t.tv_sec) * 1000_000_000'i64 + 
                    int64(t.tv_usec) * 1000'i64)
  proc `-`*(a, b: Ticks): Nanos {.borrow.}

type clock* = object
  clockStart*: int64
  clockStop*: int64

proc start*(c: var clock) {.inline.} = c.clockStart = getTicks().Nanos
proc stop*(c: var clock) {.inline.} = c.clockStop = getTicks().Nanos
proc seconds*(c: clock): string {.inline.} = $(float64(c.clockStop - c.clockStart)/1000000000) & "s"

import strutils


template bench*(c: clock, body: stmt): stmt =
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
  echo ($(c.clockStop - c.clockStart) & "ns") # in nanoseconds
  echo c.seconds
  
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

  echo "bench 0): ", c0.seconds
  echo "bench 1): ", c1.seconds
  echo "bench 2): ", c2.seconds
  echo "total: ", c.seconds

