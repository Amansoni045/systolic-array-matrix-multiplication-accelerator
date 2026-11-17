# Literature References & Theoretical Foundations

This directory documents the seminal academic papers and reference textbooks that form the theoretical and architectural foundation of the **4×4 Systolic Array Matrix Multiplication Accelerator**.

---

## 1. Systolic Array Architecture Foundations

**Citation:**  
H. T. Kung and C. E. Leiserson, *"Systolic arrays (for VLSI)"*, in *Sparse Matrix Proceedings 1978*, I. S. Duff and G. W. Stewart, Eds. Philadelphia, PA, USA: SIAM, 1979, pp. 256–282.

- **Direct Download Link:** [https://apps.dtic.mil/sti/tr/pdf/ADA067674.pdf](https://apps.dtic.mil/sti/tr/pdf/ADA067674.pdf)
- **Key Concepts Adopted:**
  - Concept of rhythmic, pipelined data movement through a regular network of tightly coupled Processing Elements (PEs).
  - Reusing operands $O(N)$ times across neighbouring PEs to achieve $O(N^3)$ computational operations with only $O(N)$ memory bandwidth.
  - Spatial systolic wavefront propagation across diagonal processing lines.

---

## 2. Computer Architecture & Matrix Multiplication Hardware

**Citation:**  
D. A. Patterson and J. L. Hennessy, *Computer Organization and Design RISC-V Edition: The Hardware/Software Interface*, 2nd ed. San Francisco, CA, USA: Morgan Kaufmann, 2020, Chapters 4–6.

- **Publisher Link:** [https://www.elsevier.com/books/computer-organization-and-design-risc-v-edition/patterson/978-0-12-812275-4](https://www.elsevier.com/books/computer-organization-and-design-risc-v-edition/patterson/978-0-12-812275-4)
- **Key Concepts Adopted:**
  - Analysis of the Von Neumann "memory wall" bottleneck for arithmetic kernels.
  - Hardware techniques for signed two's complement integer arithmetic (INT8) and overflow avoidance using extended accumulators (INT32).
  - Datapath and control unit state machine co-design for deterministic hardware scheduling.

---

## 3. Domain-Specific Accelerators & TPU Architecture

**Citation:**  
N. P. Jouppi et al., *"In-datacenter performance analysis of a tensor processing unit"*, in *Proceedings of the 44th Annual International Symposium on Computer Architecture (ISCA)*, Toronto, ON, Canada, Jun. 2017, pp. 1–12.

- **ACM Digital Library Link:** [https://doi.org/10.1145/3079856.3080246](https://doi.org/10.1145/3079856.3080246)
- **Key Concepts Adopted:**
  - Trade-off analysis between Weight-Stationary (WS), Input-Stationary (IS), and Output-Stationary (OS) matrix engines.
  - Adoption of the Output-Stationary (OS) strategy for minimizing internal register switching activity and wire congestion in fixed-dimension GEMM cores.
  - Low-power INT8 quantization for neural network inference acceleration.
