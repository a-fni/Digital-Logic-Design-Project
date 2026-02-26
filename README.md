# Digital Logic Design Project

Final project of the [Digital Logic Design](https://onlineservices.polimi.it/manifesti/manifesti/controller/ManifestoPublic.do?EVN_DETTAGLIO_RIGA_MANIFESTO=evento&aa=2025&k_cf=225&k_corso_la=531&k_indir=I3I&codDescr=054441&lang=IT&semestre=1&anno_corso=3&idItemOfferta=178957&idRiga=335659)
course held at Politecnico di Milano.

## Oveview

The objective of this project was to design a simple hardware module in charge of acting as an adapter between
a memory module and four output channels (of 8 bit each). More in detail, our hardware module receives a serial sequence of bits
from its one bit input which will have the following structure:
- 2 bits indicating which output channel should be used.
- A number between 0 and 16 bits indicating the memory address we should read. If less than 16 bits are provided LHS zero extension should be performed.
The job the module is to correctly format the provided memory address, read from memory and finally forward the read data to the correct output bus.

A more detailed description on the specifications of the assignment can be found in the `PFRL_Specifica_22_23 V0.0.pdf` PDF document.

## Hardware Description and Design

Both a coarse design of the electronical schematics as well as a precise VHDL description were required by the assignment
and a final report describing all development phases and design decisions of the project can be found under `Report/`.

## Testing and Evaluation

Testing of the designed hardware module was performed using the provided open test benches, stored
under `tbs/`. The final score obtained by the final submission was of **28 out of 30**, which includes
grading of the source code as well as of the final report.
