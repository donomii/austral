# Threading Demo

This example exercises `System.Thread` and `System.Thread.Pool`.

```sh
make
make run
```

The build compiles Austral to C and then links the generated program with the
pthread support runtime in `standard/src/System/thread_support.c`.
