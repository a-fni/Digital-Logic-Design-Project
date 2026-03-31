# Digital Logic Design Project
> **Politecnico di Milano** — *Digital Logic Design (Reti Logiche)*, A.Y. 2022/2023
> Final grade: **28 / 30**

---

## Table of Contents

1. [Overview](#overview)
2. [Project Specification](#project-specification)
3. [Architecture](#architecture)
   - [Top-Level Entity](#top-level-entity)
   - [Finite State Machine](#finite-state-machine)
   - [Datapath](#datapath)
4. [Signal Description](#signal-description)
5. [Timing & Clocking](#timing--clocking)
6. [Repository Structure](#repository-structure)
7. [Simulation & Testing](#simulation--testing)
8. [Results](#results)
9. [License](#license)

---

## Overview

This repository contains the complete VHDL implementation of a **serial-input memory-adapter module**, developed as the final project for the [Digital Logic Design](https://onlineservices.polimi.it/manifesti/manifesti/controller/ManifestoPublic.do?EVN_DETTAGLIO_RIGA_MANIFESTO=evento&aa=2025&k_cf=225&k_corso_la=531&k_indir=I3I&codDescr=054441&lang=IT&semestre=1&anno_corso=3&idItemOfferta=178957&idRiga=335659) course held at Politecnico di Milano.

The module bridges a single-bit serial input to a 16-bit memory bus and demultiplexes the retrieved 8-bit data onto one of four output channels. The design follows a classic **FSM + Datapath** decomposition, fully described at the RTL level in VHDL and verified against 8 independent test benches.

---

## Project Specification

The full specification is available at [`PFRL_Specifica_22_23 V0.0.pdf`](PFRL_Specifica_22_23%20V0.0.pdf). A summary follows.

### Input Protocol

The module receives a **serial bit-stream** on the single-wire input `i_w`, framed by the `i_start` signal. Each transaction encodes:

| Bit position | Width | Content |
|---|---|---|
| 0 | 1 bit | MSB of the 2-bit channel selector |
| 1 | 1 bit | LSB of the 2-bit channel selector |
| 2 … N+1 | 0 – 16 bits | Memory address, MSB first |

- The address field may be **0 to 16 bits** wide. If fewer than 16 bits are provided, **left-zero extension (LHS padding)** is applied automatically via the shift-register accumulator in the datapath.
- The 2-bit channel selector encodes the output destination:

| `ch1` | `ch0` | Output channel |
|---|---|---|
| 0 | 0 | `o_z0` |
| 0 | 1 | `o_z1` |
| 1 | 0 | `o_z2` |
| 1 | 1 | `o_z3` |

### Output Behaviour

- While `o_done = '0'`, all four output buses hold `0x00`.
- On the rising edge that asserts `o_done = '1'`, the addressed memory byte is presented on the selected output channel; all other channels hold `0x00`.
- `o_done` is de-asserted on the following clock cycle, and all outputs revert to `0x00`.

---

## Architecture

The design is split into two cooperating entities following the standard **FSM + Datapath** pattern.

### Top-Level Entity

```vhdl
entity project_reti_logiche is
    port (
        i_clk      : in  std_logic;
        i_rst      : in  std_logic;
        i_start    : in  std_logic;
        i_w        : in  std_logic;

        o_z0       : out std_logic_vector(7 downto 0);
        o_z1       : out std_logic_vector(7 downto 0);
        o_z2       : out std_logic_vector(7 downto 0);
        o_z3       : out std_logic_vector(7 downto 0);
        o_done     : out std_logic;

        o_mem_addr : out std_logic_vector(15 downto 0);
        i_mem_data : in  std_logic_vector(7 downto 0);
        o_mem_we   : out std_logic;
        o_mem_en   : out std_logic
    );
end project_reti_logiche;
```

The top-level instantiates one `datapath` component and wires the FSM control signals to it.

---

### Finite State Machine

The controller is a **Mealy/Moore hybrid FSM** with 7 states (`S0`–`S6`). State transitions are clocked on the **rising edge** of `i_clk`; output signals are combinationally derived from the current state.

```
      i_start=1
  ┌────────────────┐
  │                ▼
 [S0] ─ ────────► [S1]
  ▲                │  (always)
  │                ▼
  │               [S2] ──── i_start=1 ──► [S3] ──┐ i_start=0
  │                │                       │◄─────┘ (loop)
  │           i_start=0                    │ i_start=0
  │                │                       │
  │                ▼                       │
  │              [S4] ◄────────────────────┘
  │                │  (always)
  │                ▼
  │              [S5]
  │                │  (always)
  └──────────── [S6]
```

| State | Action | Control signals asserted |
|---|---|---|
| **S0** | Reset / idle — wipe address register | `addr_wipe` |
| **S1** | Sample first serial bit → `ch1` register | `ch1_load` |
| **S2** | Sample second serial bit → `ch0` register | `ch0_load` |
| **S3** | Accumulate address bits (loop while `i_start = '1'`) | `addr_load` |
| **S4** | Present address to memory, assert `o_mem_en` | `o_mem_en` |
| **S5** | Latch memory data into the selected Zn register | `z_ctrl` |
| **S6** | Assert `o_done`, drive outputs | `done_ctrl` |

> **Key design note:** The address accumulation loop (S2 → S3 → S3 → … → S4) naturally provides **left-zero extension**: the 16-bit shift register is pre-wiped in S0, so un-shifted MSBs remain zero regardless of how many address bits are provided.

---

### Datapath

```vhdl
entity datapath is
    port (
        i_clk, i_rst, i_w          : in  std_logic;
        ch1_load, ch0_load         : in  std_logic;   -- channel register loads
        addr_load, addr_wipe       : in  std_logic;   -- address shift-register control
        o_mem_addr                 : out std_logic_vector(15 downto 0);
        i_mem_data                 : in  std_logic_vector(7 downto 0);
        z_ctrl                     : in  std_logic;   -- enables Zn write
        o_done                     : in  std_logic;   -- output-mux select
        m0_o, m1_o, m2_o, m3_o    : out std_logic_vector(7 downto 0)
    );
end datapath;
```

The datapath contains the following register-level components:

| Component | Type | Width | Clocked on | Description |
|---|---|---|---|---|
| `ch1`, `ch0` | D flip-flop | 1 bit | Falling edge | Store the 2-bit channel selector |
| `addr` | Shift register | 16 bits | Falling edge | Accumulates address bits MSB-first; supports wipe |
| `z0`–`z3` | D register | 8 bits | Rising edge | Hold the per-channel output data |
| Output MUX | Combinational | — | — | Gates all Zn outputs through `o_done` |

> **Clock-edge rationale:** Channel and address registers sample `i_w` on the **falling edge**, guaranteeing that the FSM has settled its control signals (which transition on the rising edge) before data is captured — avoiding hold-time races.

**Address shift logic:**
```vhdl
next_addr <= addr_o(14 downto 0) & i_w;   -- left-shift, insert new bit at LSB
o_mem_addr <= addr_o;                      -- address is presented continuously
```

**Output channel decode (combinational):**
```vhdl
z0_load <= z_ctrl and (not ch1_o) and (not ch0_o);
z1_load <= z_ctrl and (not ch1_o) and      ch0_o;
z2_load <= z_ctrl and      ch1_o  and (not ch0_o);
z3_load <= z_ctrl and      ch1_o  and      ch0_o;
```

**Output multiplexer:**
```vhdl
with o_done select  m0_o <= (others => '0') when '0',  z0_o when '1', ...;
-- (repeated for m1_o–m3_o)
```

---

## Signal Description

| Signal | Direction | Width | Description |
|---|---|---|---|
| `i_clk` | in | 1 | System clock (10 MHz, 100 ns period) |
| `i_rst` | in | 1 | Synchronous active-high reset |
| `i_start` | in | 1 | Frames the serial input; high during transmission |
| `i_w` | in | 1 | Serial data input |
| `o_z0`–`o_z3` | out | 8 | Output channels (only one valid when `o_done = '1'`) |
| `o_done` | out | 1 | Pulses high for one clock cycle when output is valid |
| `o_mem_addr` | out | 16 | Memory read address |
| `i_mem_data` | in | 8 | Data returned by memory |
| `o_mem_we` | out | 1 | Memory write enable (always `'0'` — read-only) |
| `o_mem_en` | out | 1 | Memory chip enable |

---

## Timing & Clocking

The design targets a **10 MHz** clock (100 ns period) as specified by the Xilinx constraint file:

```tcl
create_clock -period 100 -name clock -waveform {0 5} [get_ports i_clk]
```

- **FSM state register** — updates on the **rising** edge of `i_clk`.
- **Channel / Address registers** — update on the **falling** edge of `i_clk` (see clock-edge rationale above).
- **Output (Zn) registers** — update on the **rising** edge of `i_clk`.
- **Asynchronous reset** — `i_rst` is recognised asynchronously in all register processes; the FSM returns to S0 and all registers clear to `0`.

---

## Repository Structure

```
Digital-Logic-Design-Project/
│
├── DLD_Sources/               # Primary synthesisable sources
│   ├── 10751746.vhd           # Top-level + datapath (full RTL design)
│   └── clock.xdc              # Xilinx timing constraint
│
├── tbs/                       # VHDL test benches
│   ├── tb_example23.vhd       # Reference example provided with the spec
│   ├── tb_1.vhd … tb_7.vhd   # Seven additional test scenarios
│
├── Deliverables/              # Final submission artefacts
│   ├── 10751746.vhd           # Submitted source (matches DLD_Sources/)
│   └── 10751746.pdf           # Submitted report
│
├── Report/                    # Report source and assets
│   ├── 10751746.pdf           # Final compiled report (PDF)
│   └── raw artifacts/
│       ├── 10751746.tex       # LaTeX source
│       └── Images/            # draw.io schematics (PNG + .drawio)
│           ├── FiniteStateMachine.drawio.png
│           ├── FullSchematics.drawio.png
│           ├── ModulosSchematics.drawio.png
│           ├── InputAndAddressModule.drawio.png
│           └── OutputModule.drawio.png
│
├── PFRL_Specifica_22_23 V0.0.pdf   # Assignment specification
├── PFRL_Regole_22_23 V0.0.pdf      # Course rules & grading rubric
└── LICENSE                          # MIT License
```

---

## Simulation & Testing

Eight independent VHDL test benches are provided under `tbs/`. Each instantiates `project_reti_logiche` connected to a behavioural RAM model and drives `scenario_rst`, `scenario_start`, and `scenario_w` bit-vectors to exercise specific protocol scenarios.

### Running with GHDL (open-source)

```bash
# Compile the design and a test bench
ghdl -a DLD_Sources/10751746.vhd
ghdl -a tbs/tb_example23.vhd

# Elaborate and run
ghdl -e project_tb
ghdl -r project_tb --wave=sim.ghw

# Inspect waveform (GTKWave)
gtkwave sim.ghw
```

### Running with Vivado (Xilinx)

1. Create a new project targeting your board (or use `xc7a35tcpg236-1` as a dummy part).
2. Add `DLD_Sources/10751746.vhd` as a design source and `clock.xdc` as a constraint.
3. Add the desired `tbs/tb_*.vhd` as a simulation source.
4. Run *Behavioral Simulation* from the Flow Navigator.

### Test-Bench Coverage Overview

| Bench | Key scenarios covered |
|---|---|
| `tb_example23` | Reference case from spec: ch2→MEM[1], ch1→MEM[2] |
| `tb_1` | Multiple consecutive transactions, reset between |
| `tb_2` | Maximum 16-bit address, all four channels |
| `tb_3` | Zero-bit address (immediate read from address 0) |
| `tb_4` | Mixed address widths in a single run |
| `tb_5` | Stress: long address sequences, boundary addresses |
| `tb_6` | Reset asserted mid-transaction |
| `tb_7` | Repeated start/stop sequences without reset |

---

## Results

| Criterion | Score |
|---|---|
| Functional correctness (test benches) | ✅ All passed |
| VHDL code quality & style | ✅ |
| Design report | ✅ |
| **Total** | **28 / 30** |

---

## License

This project is released under the [MIT License](LICENSE).  
Copyright © 2026 Andrea Ferrarini.

> This repository is shared for academic and educational purposes. Please respect Politecnico di Milano's academic integrity policy if you are currently enrolled in this or a similar course.
