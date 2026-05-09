# Owned payload moved into thread

`spawn` consumes the owned payload. The parent cannot destroy or otherwise use
that owner after spawning the worker.
