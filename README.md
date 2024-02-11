# SimpleMulticoreProcessor

## 2-core Processor with Unified Memory and Address Bus.

A 2-core processor connected via a Unified Memory unit. Incorporates Cache Coherence by utilizing a snooping based mechanism. Contains a matrix multiplication task to evaluate enhanced parallel performance when compared to equiv. uniprocessor.

## Summary of Architecture

1. Two CPUs connected by shared bus.
2. One data memory that serves both CPUs.
3. Each CPU has it's own memory controller and d-cache.
4. Bus contains a SM that interfaces between 2 d-caches and the data memory.

