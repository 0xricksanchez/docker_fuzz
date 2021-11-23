# README

This is an all purpose test container for all things fuzzing/debugging.
It has a bunch of tools installed to get you started.
List of tools:

* AFL++ (full)
    * AFL-cov
* libfuzzer
* honggfuzz
* radamsa
* gdb(-multiarch) with pwndbg
* rr
* crashwalk
* exploitable
* zsh
* hexyl
* ripgrep
* bat
* httpie
* exposed ssh server
* go
* python3
* valgrind
* strace, ltrace, uftrace, lcov, gcov, llvm-cov

Just build and run it as you would any other container

```bash
docker built -t bfuzz .
docker run -it --cap-add=SYS_PTRACE --security-opt seccomp=unconfined bfuzz
// alternatively if you want to mount a fuzz target into the container run
docker run -itv "/host_dir:/container_dir" --cap-add=SYS_PTRACE --security-opt seccomp=unconfined bfuzz
```

or you can even pull the container directly from docker hub:

```bash
docker pull 0x434b/bfuzz
docker run -itv "$(pwd)/host_dir:/container_dir" --cap-add=SYS_PTRACE --security-opt seccomp=unconfined 0x434b:bfuzz
```

The extra flags `--cap-add=SYS_PTRACE --security-opt seccomp=unconfined` are needed by the *rr* debugger to work inside a docker container.
