# ProbSMT

ProbSMT is a Z3-based research prototype that injects distribution-aware sampling into SMT solving. Constant declarations may carry a distribution annotation, and the NLSAT engine consults that annotation when it selects a real witness. The annotation syntax belongs to this fork.

The PSMT problem and the Prob-MCSAT algorithm are described in the ASE 2023 paper. A copy of that paper is stored at [ASE2023_PSMT.pdf](ASE2023_PSMT.pdf).

## Overview

A constant declaration may carry one distribution name and two rational parameters:

```smt2
(declare-const x Real UD 0 1000)
(declare-const y Real GD 0 0.1)
```

`UD` is the uniform-style annotation. In this implementation the two numerals are a center and a spread. `GD` is the Gaussian-style annotation. The two numerals are a location and a scale. Runnable inputs are under [test/](test/) and [test/smt/](test/smt/).

Annotated constants are sampled during NLSAT witness selection. Constants without an annotation keep Z3's ordinary witness selection. The sampling path is a prototype. Parameter interpretation lives in [src/nlsat/nlsat_interval_set.cpp](src/nlsat/nlsat_interval_set.cpp), metadata is passed through a shared `.extract` file in the working directory, and each distribution object is seeded from `time(NULL)`. The [Implementation Guide](#implementation-guide) records those limitations.

The CMake project version in this tree is 4.11.2.0. The paper states that the tool is based on Z3 4.12.1.

## Requirements

The commands in this file expect a `z3` executable at `build/z3`. Building that executable uses the following, as declared in this tree:

- CMake 3.4 or newer. [CMakeLists.txt](CMakeLists.txt) sets `cmake_minimum_required` to 3.4.
- A C++ compiler that accepts C++17. The top-level lists file sets `CMAKE_CXX_STANDARD` to 17 and `CMAKE_CXX_STANDARD_REQUIRED` to `ON`.
- A CMake generator and its build tool. [README-CMake.md](README-CMake.md) documents Unix Makefiles, Ninja, NMake, and Visual Studio.

CMake rejects an in-source build. Configure a separate build directory.

The legacy entry point [configure](configure) is independent of the CMake flow used by the case-study scripts. It invokes [scripts/mk_make.py](scripts/mk_make.py) with the interpreter named by `PYTHON`, or with `python` when that variable is unset. The script exits when that interpreter cannot run a short Python statement.

Binding, GMP, and API-documentation options are listed in [README-CMake.md](README-CMake.md). The case-study scripts require the `z3` executable.

## Building

With the build directory named `build`, the shell target produces `build/z3`. [src/shell/CMakeLists.txt](src/shell/CMakeLists.txt) sets the target output name to `z3`. [src/CMakeLists.txt](src/CMakeLists.txt) adds that executable when this repository is the top-level CMake project. When the tree is configured as a subdirectory, `Z3_BUILD_EXECUTABLE` defaults to `OFF`.

[README-CMake.md](README-CMake.md) is the reference for generators, build types, compiler selection, install rules, and cache options. Its Unix Makefiles procedure, run from the repository root, is:

```bash
mkdir build
cd build
cmake -G "Unix Makefiles" ../
make -j4
```

[README-CMake.md](README-CMake.md) states that `-G "Unix Makefiles"` may be omitted where that generator is already the default, and that `4` in `make -j4` should be replaced by a suitable job count. The same document lists the build types `Release`, `Debug`, `RelWithDebInfo`, and `MinSizeRel`. For Unix Makefiles and Ninja, the type is chosen at configure time, for example with `-DCMAKE_BUILD_TYPE=Release`.

When `build/z3` is missing, [test/case_study_run.sh](test/case_study_run.sh) prints this hint:

```bash
cmake -S . -B build && cmake --build build -j
```

That hint is the text of the script. The procedure in [README-CMake.md](README-CMake.md) is the `mkdir` form above, matching the CMake 3.4 minimum declared in [CMakeLists.txt](CMakeLists.txt).

If a previous Python build left generated sources in the tree, CMake refuses to configure. [README-CMake.md](README-CMake.md) documents a preview and the corresponding cleanup:

```bash
git clean -nx src
git clean -fx src
```

The second command deletes untracked files under `src`. Inspect the preview before running it.

## Quick Start

With `build/z3` in place, the checked-in example is:

```bash
cd test
../build/z3 Prob_Circle.smt2
```

The input is [test/Prob_Circle.smt2](test/Prob_Circle.smt2). The previous README states that this command prints `sat` and one model assignment. The file contains:

```smt2
(set-logic QF_NRA)
(declare-const x Real UD 0 1000)
(declare-const y Real UD 0 1000)
(assert (>= (+ (* x x) (* (- 1) y) y 1) 1))
(assert (>= y (- (* 2 (* x x)) 1)))
(assert (and (>= x -1) (<= x 1)))
(assert (and (>= y -1) (<= y 1)))
(check-sat)
(get-model)
(exit)
```

As written, the first assertion simplifies to `x^2 >= 0`. The second assertion is `y >= 2 x^2 - 1`, together with the box bounds on `x` and `y`.

[test/Prob_BMI.smt2](test/Prob_BMI.smt2) is a separate example. Its `GD` declarations are comments. The active declarations are ordinary `Real` constants, with the BMI bounds and `(assert (>= height 2.5))`.

## Implementation Guide

### Annotations

The extension applies to `declare-const`. In [src/parsers/smt2/smt2parser.cpp](src/parsers/smt2/smt2parser.cpp), `parse_declare_const` calls `check_distribution` after the sort. The recognized names are `GD` and `UD`. Each name is followed by two numerals. The parser appends one line to `.extract`:

```text
<symbol> <GD|UD> <parameter-1> <parameter-2>
```

### Metadata File

`.extract` is a file in the process working directory. The parser opens it in append mode. At the start of NLSAT `check`, `init_distribution` in [src/nlsat/nlsat_solver.cpp](src/nlsat/nlsat_solver.cpp) reads every complete line, maps each symbol onto a displayed variable name, stores `GD` as type 1 and `UD` as type 2, and then truncates `.extract`. A run that never reaches this check leaves its lines in the file, and the next parse appends after them. Processes that share a working directory share this file. `.extract` is not listed in [.gitignore](.gitignore).

Name matching advances through the variable permutation until the displayed name equals the recorded symbol. The index wraps by modulo arithmetic. That loop has no separate failure return when the symbol is absent.

### Witness Selection

`select_witness` samples from the loaded distribution when the current variable is present in the map. Otherwise it calls the ordinary `peek_in_complement` overload. The distribution-aware overload is implemented in [src/nlsat/nlsat_interval_set.cpp](src/nlsat/nlsat_interval_set.cpp), and the class is declared in [src/nlsat/nlsat_interval_set.h](src/nlsat/nlsat_interval_set.h).

`init_distribution` seeds every distribution object from `time(NULL)`, then adds one to the seed for each recorded variable. [test/case_study_run.sh](test/case_study_run.sh) starts the next run immediately, so runs that begin during the same second share the initial seed. [test/run_times.sh](test/run_times.sh) sleeps for one second between runs.

The second `GD` parameter is consumed in two ways in [src/nlsat/nlsat_interval_set.cpp](src/nlsat/nlsat_interval_set.cpp). `rand_GD` draws an unconstrained sample whose standard deviation is the square root of that parameter. `CDF`, `PPF`, and the Gaussian branch of `get_prob` pass the parameter through as the scale of the normal formulas, including the density factor `scale * sqrt(2 * pi)`. Sampling inside a bounded feasible interval uses `CDF` and `PPF`.

`rand_UD` returns `center + s * u`, where `s` is `-1` or `1` and `u` is drawn from `[0, spread]`. When a feasible interval has two finite endpoints, the uniform branch samples uniformly between those endpoints and weights the interval by the difference of the endpoints. On a one-sided feasible ray, the uniform weight used while choosing an interval is the declared spread.

`init_distribution` also allocates a default object of type `UD` with parameters `0` and `1000`. The statement that would sample from that object is commented out, so variables absent from `.extract` follow the ordinary witness path.

## Benchmarks

### Triangle Instances

The case-study formulas are in [test/smt/](test/smt/). Each file sets the logic to `QF_NRA`, declares `x` and `y`, and ends with `check-sat`, `get-model`, and `exit`. The nine Gaussian files, [test/smt/Triangle.smt2](test/smt/Triangle.smt2), and [test/smt/Prob_Triangle.smt2](test/smt/Prob_Triangle.smt2) share these assertions:

```smt2
(assert (<= x (- y)))
(assert (<= y x))
(assert (and (>= x -1) (<= x 1)))
(assert (and (>= y -1) (<= y 1)))
```

The declarations differ as follows:

- [test/smt/Triangle.smt2](test/smt/Triangle.smt2) declares plain `Real` constants.
- [test/smt/Prob_Triangle.smt2](test/smt/Prob_Triangle.smt2) declares both constants as `UD 0 1000`.
- [test/smt/GD_Triangle_0_1.smt2](test/smt/GD_Triangle_0_1.smt2), [test/smt/GD_Triangle_0_2.smt2](test/smt/GD_Triangle_0_2.smt2), and [test/smt/GD_Triangle_0_5.smt2](test/smt/GD_Triangle_0_5.smt2) give both constants location `0`. The scales are `0.1`, `0.25`, and `0.5`.
- [test/smt/GD_Triangle_5_1.smt2](test/smt/GD_Triangle_5_1.smt2), [test/smt/GD_Triangle_5_2.smt2](test/smt/GD_Triangle_5_2.smt2), and [test/smt/GD_Triangle_5_5.smt2](test/smt/GD_Triangle_5_5.smt2) give `x` location `0.5` and `y` location `0`, with the same three scales on both constants.
- [test/smt/GD_Triangle_7_1.smt2](test/smt/GD_Triangle_7_1.smt2), [test/smt/GD_Triangle_7_2.smt2](test/smt/GD_Triangle_7_2.smt2), and [test/smt/GD_Triangle_7_5.smt2](test/smt/GD_Triangle_7_5.smt2) give `x` location `-0.5` and `y` location `0`, with the same three scales on both constants.

The paper's Example 2 states the constraints `x - y >= 0`, `x + y <= 0`, and `y >= -1`. The checked-in files also bound both variables to `[-1, 1]`. For the normal-distribution figures, the paper states that `y` follows `N(0, 0.1)` and that each caption is the distribution followed by `x`. Those captions use second parameters `0.1`, `0.25`, and `0.5`. In the checked-in Gaussian files, `y` carries the same scale suffix as `x`.

### Other Inputs

[test/Prob_Circle.smt2](test/Prob_Circle.smt2) and [test/Prob_BMI.smt2](test/Prob_BMI.smt2) are single-file examples. The BMI file leaves its `GD` declarations commented out.

[test/QF_NIA/](test/QF_NIA/) contains 15 SMT-LIB `QF_NIA` files. Their headers attribute the set to the AProVE team, submitted for SMT-COMP 2014. [test/QF_NRA/](test/QF_NRA/) contains 20 `hong_*.smt2` files. Their headers attribute the set to the Hong family used in Dejan Jovanovic and Leonardo de Moura, "Solving Non-Linear Arithmetic", IJCAR 2012. These files contain no `UD` or `GD` annotations, and this repository stores no result logs for them. A commented loop over `QF_NIA` remains in [test/run.sh](test/run.sh).

## Reproducing Experiments

The paper states that each parameter setting was run 1000 times. The scripts below use that count as their default. They write solver logs. They contain no figure-generation step.

### Case-Study Scripts

Run these commands from [test/](test/) after `build/z3` exists.

One configuration, with an explicit run count:

```bash
cd test
./case_study_run.sh GD_Triangle_0_1.smt2 200
```

[test/case_study_run.sh](test/case_study_run.sh) takes a file name located in [test/smt/](test/smt/) and a positive integer run count. The default file is `GD_Triangle_0_1.smt2`, and the default count is 1000. The script creates [test/res/](test/res/) when needed, replaces `test/res/<file>.log`, appends one solver invocation per run, and prints the number of lines equal to `sat`.

The nine Gaussian files:

```bash
cd test
./case_study_batch.sh 1000
```

[test/case_study_batch.sh](test/case_study_batch.sh) forwards its run count to `case_study_run.sh` for every `test/smt/GD_Triangle_*.smt2` file. The default count is 1000.

One stored log:

```bash
cd test
./case_study_report.sh GD_Triangle_0_1.smt2
```

[test/case_study_report.sh](test/case_study_report.sh) reads `test/res/<file>.log`. It prints the counts of `sat`, `define-fun x`, and `define-fun y`, then the first five recorded assignments of `x` and of `y`.

### Earlier Scripts

[test/run_times.sh](test/run_times.sh) is started from `test/`. It removes `res/<file>.log`, invokes `../build/z3 smt/<file>` 1000 times, appends each invocation to that log, and sleeps one second between runs. The script itself does not create `res/`.

[test/parallel.sh](test/parallel.sh) launches `run_times.sh` in the background for all nine `GD_Triangle_*.smt2` files. The script then contains the literal path `/home/hanrui/prob-smt/noarch`, which the shell executes as a command.

[test/run.sh](test/run.sh) is also started from `test/`. It runs `make -j10` in `../build`, which requires a build directory that CMake has already configured, and then executes:

```bash
../build/z3 $1 -memory:30720 -tr:hr -tr:nlsat -tr:nlsat_assign -tr:mpq_set -tr:nlsat_model
```

`$1` is unquoted in the script. The flag `-tr:hr` matches `TRACE("hr", ...)` sites in the distribution parser and sampler. `-tr:nlsat_assign` and `-tr:nlsat_model` match sites in [src/nlsat/nlsat_solver.cpp](src/nlsat/nlsat_solver.cpp). `-tr:mpq_set` matches sites in [src/util/mpq.cpp](src/util/mpq.cpp).

## Results

### Paper

The paper reports the triangle case study qualitatively and states that each parameter setting was run 1000 times.

For the uniform comparison, the paper describes points from a uniform sampler and from uniform Prob-MCSAT on the triangle. It states that Prob-MCSAT concentrates points near the two lower corners because the feasible interval for `y` shrinks as `x` approaches `-1` or `1`. It also states that Z3 produced one invariant model, shown as a black diamond, across those 1000 runs.

For the normal distribution, the paper states two trends. With the variance held fixed, changing the mean moves the center of the cluster. With the mean held fixed, increasing the variance spreads the cluster. The captions for `x` are `N(0, 0.1)`, `N(0, 0.25)`, `N(0, 0.5)`, `N(0.5, 0.1)`, `N(0.5, 0.25)`, `N(0.5, 0.5)`, `N(-0.5, 0.1)`, `N(-0.5, 0.25)`, and `N(-0.5, 0.5)`. The surrounding text states that `y` follows `N(0, 0.1)`.

The paper's BMI illustration reports an ordinary SMT assignment `w = 0.375`, `h = 0.125`, and an assignment `w = 66.82`, `h = 1.75` under `w ~ N(60, 10)` and `h ~ N(1.7, 0.1)`. Those values are stated in the paper. This repository does not store the corresponding solver output, and the `GD` lines in [test/Prob_BMI.smt2](test/Prob_BMI.smt2) are comments.

### Checked-in Logs and Charts

The logs currently stored in [test/res/](test/res/) contain the following numbers of lines whose entire text is `sat`. None of these logs contains a line `unsat`, `unknown`, or an SMT-LIB error.

- `GD_Triangle_0_1.smt2.log`: 978
- `GD_Triangle_0_2.smt2.log`: 987
- `GD_Triangle_0_5.smt2.log`: 988
- `GD_Triangle_5_1.smt2.log`: 984
- `GD_Triangle_5_2.smt2.log`: 971
- `GD_Triangle_5_5.smt2.log`: 976
- `GD_Triangle_7_1.smt2.log`: 992
- `GD_Triangle_7_2.smt2.log`: 985
- `GD_Triangle_7_5.smt2.log`: 986
- `Prob_Triangle.smt2.log`: 1000
- `Triangle.smt2.log`: 1000

The repository does not record the command, seed, or solver binary that produced these logs. The paper's stated run count is 1000 for each setting. The stored Gaussian logs contain 971 to 992 `sat` lines.

[test/charts/](test/charts/) contains `UD.pdf`, `Prob_Triangle.smt2.log.pdf`, and one PDF named for each of the nine Gaussian logs. `Triangle.smt2.log` has no PDF in that directory.

## Paper and Citation

Fuqi Jia, Rui Han, Xutong Ma, Baoquan Cui, Minghao Liu, Pei Huang, Feifei Ma, and Jian Zhang. "PSMT: Satisfiability Modulo Theories Meets Probability Distribution." In *2023 38th IEEE/ACM International Conference on Automated Software Engineering (ASE)*, Luxembourg, 11–15 September 2023, pages 1756–1760. IEEE. <https://doi.org/10.1109/ase56229.2023.00183>.

The ASE 2023 program lists this paper in the NIER track. The PDF copy in this repository is [ASE2023_PSMT.pdf](ASE2023_PSMT.pdf). That copy marks Fuqi Jia and Rui Han as equal contributors, and Feifei Ma and Jian Zhang as corresponding authors.

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
