# ProbSMT

ProbSMT is a Z3-based research prototype that injects distribution-aware sampling into SMT solving. Constant declarations may carry a distribution annotation, which this fork uses when sampling a real assignment. The annotations are specific to this fork and lie outside standard SMT-LIB.

The paper is included as [ASE2023_PSMT.pdf](ASE2023_PSMT.pdf).

## Overview

A declaration names one distribution and two rational parameters:

```smt2
(declare-const x Real UD 0 1000)
(declare-const y Real GD 0 0.1)
```

`UD` is the uniform-style annotation. In this implementation the two numerals are a center and a spread. `GD` is the Gaussian-style annotation. The two numerals are a mean and a scale. Runnable examples are under [test/](test/) and [test/smt/](test/smt/).

## Requirements

The build below uses CMake 3.4 or newer, a C++17 compiler, and Make. Other generators and options are documented in [README-CMake.md](README-CMake.md).

## Building

From the repository root, this Unix Makefiles procedure produces the `build/z3` executable used by the commands below. [README-CMake.md](README-CMake.md) is the full build reference.

```bash
mkdir build
cd build
cmake -G "Unix Makefiles" ../
make -j4
```

Replace `4` with a suitable job count.

## Quick Start

[test/Prob_Circle.smt2](test/Prob_Circle.smt2) uses two probabilistic variables with additional geometric constraints:

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

## Implementation Guide

The parser accepts `UD` and `GD` on `declare-const` in [src/parsers/smt2/smt2parser.cpp](src/parsers/smt2/smt2parser.cpp). The NLSAT solver loads that metadata in [src/nlsat/nlsat_solver.cpp](src/nlsat/nlsat_solver.cpp). Sampling and interval probability logic are in [src/nlsat/nlsat_interval_set.h](src/nlsat/nlsat_interval_set.h) and [src/nlsat/nlsat_interval_set.cpp](src/nlsat/nlsat_interval_set.cpp). These declarations are an extension of this fork.

## Benchmarks

The case-study formulas are in [test/smt/](test/smt/). [test/smt/Triangle.smt2](test/smt/Triangle.smt2) declares plain real constants. [test/smt/Prob_Triangle.smt2](test/smt/Prob_Triangle.smt2) uses `UD`. The Gaussian groups are `GD_Triangle_0_*`, `GD_Triangle_5_*`, and `GD_Triangle_7_*`, named for locations `0`, `0.5`, and `-0.5`. Suffixes `_1`, `_2`, and `_5` use scales `0.1`, `0.25`, and `0.5`. Each `.smt2` file holds the exact declaration.

[test/QF_NIA/](test/QF_NIA/) and [test/QF_NRA/](test/QF_NRA/) contain further SMT-LIB inputs without these annotations.

## Reproducing Experiments

The paper reports two trends for the triangle case study. With variance fixed, shifting the mean moves the sampled points inside the feasible triangle. With the mean fixed, increasing the variance spreads the points while they remain feasible.

Run the scripts from [test/](test/) after `build/z3` exists. `case_study_run.sh` takes a file name from [test/smt/](test/smt/) and a positive run count. The default file is `GD_Triangle_0_1.smt2` and the default count is `1000`. `case_study_batch.sh` passes its count to every `GD_Triangle_*.smt2` file and also defaults to `1000`. Logs are written under [test/res/](test/res/).

```bash
cd test
./case_study_run.sh GD_Triangle_0_1.smt2 200
```

```bash
cd test
./case_study_batch.sh 1000
```

```bash
cd test
./case_study_report.sh GD_Triangle_0_1.smt2
```

## Results

Stored sample logs are in [test/res/](test/res/), and charts are in [test/charts/](test/charts/). Rerunning the scripts resamples with this prototype and is not an exact reproduction of the figures in the paper.

## Paper and Citation

Fuqi Jia, Rui Han, Xutong Ma, Baoquan Cui, Minghao Liu, Pei Huang, Feifei Ma, and Jian Zhang. "PSMT: Satisfiability Modulo Theories Meets Probability Distribution." In *2023 38th IEEE/ACM International Conference on Automated Software Engineering (ASE)*, Luxembourg, 11–15 September 2023, pages 1756–1760. IEEE. <https://doi.org/10.1109/ase56229.2023.00183>.

The local copy is [ASE2023_PSMT.pdf](ASE2023_PSMT.pdf).

```bibtex
@inproceedings{jia2023psmt,
  author = {Jia, Fuqi and Han, Rui and Ma, Xutong and Cui, Baoquan and Liu, Minghao and Huang, Pei and Ma, Feifei and Zhang, Jian},
  title = {{PSMT}: Satisfiability Modulo Theories Meets Probability Distribution},
  booktitle = {2023 38th IEEE/ACM International Conference on Automated Software Engineering (ASE)},
  year = {2023},
  month = sep,
  pages = {1756--1760},
  address = {Luxembourg},
  publisher = {IEEE},
  doi = {10.1109/ase56229.2023.00183},
  url = {https://doi.org/10.1109/ase56229.2023.00183}
}
```

License terms shipped with this tree are in [LICENSE.txt](LICENSE.txt).
