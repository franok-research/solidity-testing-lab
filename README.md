# Solidity Testing Lab

[![Foundry CI](https://github.com/franok-research/solidity-testing-lab/actions/workflows/ci.yml/badge.svg)](https://github.com/franok-research/solidity-testing-lab/actions/workflows/ci.yml)

A **dependency-free Foundry testing portfolio** built around a standalone Solidity
rate-bounding example. The goal is to demonstrate deterministic unit tests,
property-based fuzz tests, **stateful invariant testing**, and a GitHub Actions
pipeline. No RPC endpoints, tokens, keys, wallets, or chain deployments are needed.

> **Security notice:** Educational code only. **Not audited. Not suitable for
> collateral pricing, lending, or production use.** This repository is an
> independent example; it is **not a fork of FLUID/Instadapp contracts** and
> does **not** claim to identify vulnerabilities in any third-party protocol.

## What is being tested?

`BoundedRateOracle` reads `(rate, observedAt)` from an external rate source,
validates the observation, and rate-limits each successful state update.
For a previous stored rate `R` and move limit `b` basis points:

```text
allowance = floor(R * b / 10_000)
lower = R - allowance
upper = R + allowance
next = min(max(raw, lower), upper)
```

A cooldown limits update frequency. A freshness check rejects source
observations with missing, future or overly old timestamps. Input rates must be
in `(0, 1e36]`. Rate values are unsigned integers in **application-defined
units**; the contract does not enforce a particular decimal scale.

### Deliberate limitations

- Clamping **is not** an authenticated oracle: a compromised source can still
  steer the rate via successive permitted updates.
- The bound is **per successful update**, not per unit of wall-clock time.
- The example uses a symmetrical bound and integer division (rounding down).
- No source redundancy, governance, circuit breakers, decimals conversion,
  market sanity checks or economic attack modeling are included.
- The sample mock is **test-only** and accepts arbitrary values.

## Run locally

Install [Foundry](https://book.getfoundry.sh/getting-started/installation), then:

```bash
forge --version
forge build
forge test -vv
```

No `forge install`, secrets, or chain RPC URLs are required. Tested contracts are
pinned to Solidity `0.8.21` in `foundry.toml`.

To run a single suite:

```bash
forge test --match-contract BoundedRateOracleTest -vv
forge test --match-contract BoundedRateOracleInvariantTest -vv
```

## Test matrix

| Test family | Coverage |
|---|---|
| Unit | Constructor defaults and bad arguments; cooldown; valid in-range updates; upper/lower limits; repeated refreshes |
| Negative | Zero/excessive rates; stale, future and missing timestamps |
| Fuzz | Arbitrary source rates and independently varied basis-point limits |
| Invariant | Stateful valid-update sequences; positive finite rates; bounded transitions; consistent clock |
| CI | Build and execute all test families on each push and pull request |

**Threat model:** We intentionally model an untrusted *numeric input*, not a
fully malicious Ethereum contract. Re-entrancy, malicious callback behavior,
or adversarial network/oracle governance are not in scope. Passing these tests
is evidence about the stated properties only, not a security certification.

## Repository map

```text
src/BoundedRateOracle.sol             small reference implementation
test/BoundedRateOracle.t.sol          deterministic + property-based tests
test/BoundedRateOracle.invariant.t.sol handler-driven invariant testing
test/mocks/MockRateSource.sol         untrusted input simulator
test/utils/Vm.sol                     minimal Foundry cheatcode interface
.github/workflows/ci.yml             automated test workflow
foundry.toml                         fuzz/invariant campaign settings
```

## Suggested extension exercises

1. Model two independent sources and a source deviation check.
2. Implement and test asymmetrical up/down limits.
3. Add event assertions, gas snapshots and mutation-based tests.
4. Specify time-normalized rate bounds, then compare with the per-update model.

## License

MIT
