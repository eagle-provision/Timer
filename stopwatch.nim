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
