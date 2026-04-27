# ProbSMT

ProbSMT is a Z3-based research prototype that injects distribution-aware sampling into SMT solving.

## What is different from standard SMT-LIB?

This prototype extends constant declarations with distribution annotations:

```smt2
(declare-const x Real UD 0 1000)
(declare-const y Real GD 0 0.1)
```

- `UD`: uniform-style distribution parameters (center + spread in this implementation)
- `GD`: gaussian-style distribution parameters (mean + scale)

See runnable examples under `test/` and `test/smt/`.

## Implementation Path (Where the magic happens)

If you want to trace execution from input to sampling behavior:

1. Parser accepts extended declarations:
   - `src/parsers/smt2/smt2parser.cpp`
   - distribution metadata is collected into a temporary `.extract` file.
2. NLSAT solver loads those metadata:
   - `src/nlsat/nlsat_solver.cpp`
3. Sampling and interval probability logic:
   - `src/nlsat/nlsat_interval_set.h`
   - `src/nlsat/nlsat_interval_set.cpp`

This means distribution annotations are not standard SMT-LIB behavior and only work in this fork.

## Quick Start

`Prob_Circle.smt2` uses two probabilistic variables with additional geometric constraints:

```smt2
(set-logic QF_NRA)
(declare-const x Real UD 0 1000)
(declare-const y Real UD 0 1000)

(assert (and (>= x -1) (<= x 1)))
(assert (and (>= y -1) (<= y 1)))
(check-sat)
(get-model)
(exit)
```

```bash
cd test
../build/z3 Prob_Circle.smt2
```

You should see `sat` and one model assignment.

## Reproduce the Case Study

The case-study goal is not only to "run commands", but to observe the two trends reported in the paper:

1. Fix variance, shift mean -> sampled points shift in the feasible triangle.
2. Fix mean, increase variance -> sampled points spread out while staying feasible.

Benchmark groups (in `test/smt/`) are aligned with these claims:

- `GD_Triangle_0_*`: mean = 0
- `GD_Triangle_5_*`: mean = 0.5
- `GD_Triangle_7_*`: mean = -0.5
- Suffix `_1`, `_2`, `_5` correspond to increasing variance settings.

### Recommended workflow

Run one configuration quickly (sanity check + log generation):

```bash
cd test
./case_study_run.sh GD_Triangle_0_1.smt2 200
```

Run the full Gaussian case-study matrix:

```bash
cd test
./case_study_batch.sh 1000
```

Inspect one generated log:

```bash
cd test
./case_study_report.sh GD_Triangle_0_1.smt2
```

All logs are stored in `test/res/`.

## Citation

If you use this project, please cite:

```text
Fuqi Jia, Rui Han, Xutong Ma, Baoquan Cui, Minghao Liu, Pei Huang,
Feifei Ma, Jian Zhang.
PSMT: Satisfiability Modulo Theories Meets Probability Distribution.
ASE 2023.
```
