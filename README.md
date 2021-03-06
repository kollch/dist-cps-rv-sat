# dist-cps-rv-sat
### Distributed CPS Runtime Verification using SAT

Cyber-physical systems (CPS) are systems where the software and physical components are closely integrated. A common example of this is a system of drones, where the software for operating the drones is impacted by the physical state of the drones at any given time. One common requirement when operating a system like this is following certain safety properties such as avoiding collisions between drones or flying at an appropriate altitude. These safety properties can be represented as a boolean formula where each atom is an inequality of a constant and a linear combination of drone states. The safety properties can be considered upheld if the formula is unsatisfied for all time slices and violated if the formula is satisfied. Thus determining satisfaction of the boolean formula is a useful criterion for runtime monitoring.

While satisfiability of the boolean formula would be trivial with an SMT solver and a constant value for each drone, it is more complicated when the drones' values can change over time. The formula must be modified to account for these differences. In addition, more complexity arises when an exact time for every drone is not needed. This consideration can arise due to the lack of a "global time" among the drones since there may be slight fluctuations in communication times between them. We need to introduce a time fluctuation between drones which allows for safety violations even if drones' reported identical timings would indicate no violation. For example, a time fluctuation of 0.1 secs would allow for a drone's reported value at time 0.3 secs and another's reported value at time 0.35 secs to together satisfy the formula, since the difference between 0.3 and 0.35 is within 0.1 secs.

We transform this safety property satisfaction problem into a traditional SMT problem which can be solved by the SMT solver Z3 and SMT results transformed back into results of the safety satisfaction.

This provided formulation is done in Julia. Since current research related to the problem is also being conducted in Julia, this implementation will be useful as a comparison with current work.

The function to call with this code is the only one exported, ```signalsat```. It takes a boolean formula of inequalities as atoms, a maximum time skew between agents _epsilon_, and time and signal vectors respectively, for as many agents as the problem requires.

## Example
```signalsat("x1 - x2 <= 0.2 && x2 - x1 <= 0.2", 0.1, [1, 2, 4], [1, 4, -2], [1, 3, 4], [0, 1, -1])```

This call corresponds to two agents, x1 and x2, which violate the safety property if their signals are closer than 0.2. There is a maximum time skew of 0.1 between the agents' local clocks. Agent x1 has corresponding (`t`, `x`) pairs (1, 1), (2, 4), and (4, -2), where `t` is the time and `x` is the signal value. Agent x2's pairs are (1, 0), (3, 1), and (4, -1).

## Getting started

### Technology used
[Julia v1.7.3](https://julialang.org/downloads/)

### How to run?
After installing Julia, follow as below.

- Initiate a `Julia` session in the project directory.
```
> julia
```
- Type the following to activate it.
```
> ]activate .
```

- Instantiate the project.
```
> instantiate
```
- Backspace once, and then type
```
> using RVSAT
> using HDF5
```
- Load in the datasets
```
> f107 = h5open("dataset/thor_flight107_studentgnssdeniednavfilter_2014_05_04.h5", "r")

> f111 = h5open("dataset/thor_flight111_studentgnssdeniednavfilter_2014_05_04.h5", "r")
```
- Read and convert time attribute to vector form

```
> t1 = read(f107["time"])[:, 1]

> t2 = read(f111["time"])[:, 1]
```

- Read and convert time attribute to vector form

```
> x1 = read(f107["alt"])[:, 1]

> x2 = read(f111["alt"])[:, 1]
```
- Call the function `signalsat`. $\varphi$ is the safety formula, $\varepsilon$ is the maximum time skew, and `signals` is the signal value. <br />
Wrapping `@time begin...end` around function call will print the total time taken to run the algorithm function.
```
> @time begin

        signalsat("x2 - x1 ??? 6 ??? x1 - x2 ??? 6", 9.98, t1 [end-4000:end-2000], x1[end-4000:end-2000], t2[end-4000:end-2000], x2[end-4000:end-2000])

    end
```
Now your project is all set and running! <br />
<br />
You will see the result of either `Formula does not satisfy` or `Formula satisfies` with values of `x1`, `x2`, `t1`, and `t2`.





