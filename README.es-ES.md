

# ProbSMT

ProbSMT es un prototipo de investigación basado en Z3 que inyecta muestreo consciente de distribuciones en la resolución SMT.

## ¿Qué es diferente del SMT-LIB estándar?

Este prototipo extiende las declaraciones de constantes con anotaciones de distribución:

```smt2
(declare-const x Real UD 0 1000)
(declare-const y Real GD 0 0.1)
```

- `UD`: parámetros de distribución tipo uniforme (centro + dispersión en esta implementación)
- `GD`: parámetros de distribución tipo gaussiana (media + escala)

Vea los ejemplos ejecutables en `test/` y `test/smt/`.

## Ruta de implementación (donde ocurre la magia)

Si desea rastrear la ejecución desde la entrada hasta el comportamiento de muestreo:

1. El analizador acepta declaraciones extendidas:
   - `src/parsers/smt2/smt2parser.cpp`
   - los metadatos de distribución se recopilan en un archivo temporal `.extract`.
2. El solucionador NLSAT carga esos metadatos:
   - `src/nlsat/nlsat_solver.cpp`
3. Lógica de muestreo y probabilidad por intervalos:
   - `src/nlsat/nlsat_interval_set.h`
   - `src/nlsat/nlsat_interval_set.cpp`

Esto significa que las anotaciones de distribución no son un comportamiento estándar de SMT-LIB y solo funcionan en este fork.

## Inicio rápido

`Prob_Circle.smt2` utiliza dos variables probabilísticas con restricciones geométricas adicionales:

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

Debería ver `sat` y una asignación de modelo.

## Reproducir el caso de estudio

El objetivo del caso de estudio no es solo "ejecutar comandos", sino observar las dos tendencias reportadas en el artículo:

1. Fijar la varianza, desplazar la media -> los puntos muestreados se desplazan dentro del triángulo factible.
2. Fijar la media, aumentar la varianza -> los puntos muestreados se dispersan manteniéndose en la región factible.

Los grupos de referencia (en `test/smt/`) están alineados con estas afirmaciones:

- `GD_Triangle_0_*`: media = 0
- `GD_Triangle_5_*`: media = 0.5
- `GD_Triangle_7_*`: media = -0.5
- Los sufijos `_1`, `_2`, `_5` corresponden a configuraciones de varianza creciente.

### Flujo de trabajo recomendado

Ejecute una configuración rápidamente (verificación inicial + generación de registros):

```bash
cd test
./case_study_run.sh GD_Triangle_0_1.smt2 200
```

Ejecute la matriz completa del caso de estudio gaussiano:

```bash
cd test
./case_study_batch.sh 1000
```

Inspeccione uno de los registros generados:

```bash
cd test
./case_study_report.sh GD_Triangle_0_1.smt2
```

Todos los registros se almacenan en `test/res/`.

## Citación

Si utiliza este proyecto, por favor cite:

```text
Fuqi Jia, Rui Han, Xutong Ma, Baoquan Cui, Minghao Liu, Pei Huang,
Feifei Ma, Jian Zhang.
PSMT: Satisfiability Modulo Theories Meets Probability Distribution.
ASE 2023.
```
