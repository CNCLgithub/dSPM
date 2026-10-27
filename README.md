# dSPM-pong

Code for **"Hypothesis-Driven Identification of Neural Algorithms With Dynamical Structure-Preserving Manifolds"**
(Calbick, Kim, Sohn & Yildirim).

The code builds dynamical Structure-Preserving Manifold (dSPM) reservoirs: recurrent networks that are programmed analytically, with no training, to run a 12-variable dynamical algorithm of the Pong gameboard. It then compares their states with DMFC recordings and with task-optimized RNNs. Everything is in MATLAB.

## Layout

```
scripts/
  create-dspm-networks/     build, program and run the dSPM Pong reservoirs
    dspm-reservoir-matlab/  the dspm_reservoir package (decompile, program, close loop), GUI, tests
    dependencies/           Pong dynamics (12 equations) and the glue to the package
  dependencies/             ReservoirTanhB_dc, plus the original Kim & Bassett functions used by the parity check
  objects/                  container classes for network, decoding and statistics outputs
  preprocessing/            trim, mask and normalize DMFC, dSPM, RNN and Ball State state tensors
  manifold-analysis/        eigenspectrum, participation ratio, early-epoch PC/LDA geometry, PCA viewer
  decoding-analysis/        endpoint (FTP), future-trajectory (MTP), condition-subspace and SVM bounce decoding
  rsa-analysis/             RSA and residualization
  lotka-volterra-reservoir/ Lotka–Volterra demonstration (needs the dspm_reservoir package)
  spectral-properties/      spectral radius / local spectrum of the programmed adjacency
  pong_colors.m             shared color definitions
figures/                    animation script and exported figure panels
hpc-job-scripts/            SLURM / dSQ jobs that generate the reservoirs on the cluster
dsq-caller.sh               wrapper around dSQ (Dead Simple Queue)
setup_paths.m               adds scripts/ to the MATLAB path
DATA.md                     files in the data release and which script makes/reads each
```

## Manuscript figures → code

| Manuscript item | Analysis | Plot |
|---|---|---|
| Fig. 1, Supp. Figs. 4–5 (dynamical algorithm, primitives) | `create-dspm-networks/dependencies/define_pong_dynamics.m`, `create-dspm-networks/program_rnn.m` | `create-dspm-networks/run_pong_trial.m` |
| Fig. 2A eigenspectrum, 2B participation ratio | `manifold-analysis/eigenspectrum.m`, `compute_pr_crossval.m` | same |
| Supp. Fig. 7, Supp. Section 7 (noise floor in the dimensionality analyses: noise-matched dSPM, noise-corrected DMFC) | `manifold-analysis/supp_noise_floor_dimensionality.m` | same (writes `figures/supp_noise_floor_dimensionality.pdf`) |
| Fig. 2C–D early-epoch PC geometry / LDA | `eigenspectrum.m` (leaves the workspace `export_pca_data.m` needs) → `export_pca_data.m` (writes `pca_data.js`) → `lda_analysis.m` | `lda_plots.m` |
| Fig. 3C ball-endpoint decoding | `decoding-analysis/ftp_decoding_pipeline.m` | `plot_ftp_decoding_formal.m` |
| Fig. 3D future-trajectory decoding, Supp. Fig. 8 (CCC) | `decoding-analysis/mtp_decoding_pipeline.m` | `plot_mtp_decoding_formal.m` |
| Fig. 3E bounce / no-bounce endpoint decoding | `decoding-analysis/bounce_subspace_ftp_decoding_pipeline.m` | `plot_condition_subspace_ftp.m` |
| Fig. 3F pre-collision SVM | `decoding-analysis/svm_bounce_pipeline.m` | `plot_svm_bounce.m` |
| Fig. 4, Supp. Fig. 9 RSA and residualization | `rsa-analysis/rsa_current_06_15_2026.m` | same |
| Supp. Figs. 1–2, Supp. Section 2 (Lotka–Volterra) | `lotka-volterra-reservoir/create_LV_reservoirs.m`; 20-reservoir conservation numbers: `lv_hamiltonian_spread.m`; dependence on input scale and step: `lv_conservation_hamiltonian_sweep.m` | `create_LV_reservoirs.m` |
| Methods "Spectral radius of the programmed adjacency", Supp. Fig. 3, Supp. Section 3 | `spectral-properties/analyze_spectral_distribution.m` (ρ(A<sub>p</sub>), value at r\* and r\*<sub>i</sub>), `analyze_spectral_trajectories.m` (leading eigenvalue along trials), `first_order_spectral_radius.m` (first-order program); one-reservoir walkthrough: `create-dspm-networks/test_spectral_properties.m` | `make_spectral_radius_figure.m` |
| Supp. Fig. 6 animation | `figures/network_Trial_animation.m` | same |

## Pipeline

1. **Generate reservoirs.** `create_and_program_pong_rnns` → `program_rnn` builds a `dspm_reservoir`, decompiles it, compiles the 12-equation Pong program (`define_pong_dynamics`, `pong_program_matrix`) and closes the loop. To try one interactively:

   ```matlab
   setup_paths
   cd scripts/create-dspm-networks
   res = create_and_program_pong_rnns(1, 1000, "programmed", paddle_exist=false);
   out = run_pong_trial(res(1), vx=0.4, vy=0.3, animate=true);
   ```

   For the full set, `hpc-job-scripts/main-write-jobs.sh` writes one job per reservoir; each calls `train_and_run_rnn_worldmodels.m`, which builds one reservoir and runs it on the 79 task conditions (`run_rnn_trials`). The paper uses the 50 reservoirs in run `28-Feb-2025_1000neurons_44a04e02-…`.

   Those 50 were built with Kim & Bassett's original functions (`getexpansion` → `solve_readout`, kept in `scripts/dependencies/`). The `dspm_reservoir` generator reproduces them: `create-dspm-networks/compare_generation_old_vs_new.m` builds both on the same random read-in matrix and operating point and compares R, P, W and a closed-loop trial.
2. **Preprocess.** `preprocessing/preprocess_neural_and_RNN_data.m`, `generate_ballState_and_linearMap.m` and `dspm_run_state_normalization.m` build the trimmed, normalized state tensors for decoding. `manifold-analysis/preprocess_for_PCA.m` builds `data-pca/` for the eigenspectrum, PR and geometry analyses. `preprocess_brain_rnn_ballState_manifold.m` and `dspm_manifold_normalization.m` build the masked manifold tensors; of these, `export_pca_data.m` uses the Ball State one.
3. **Analyze.** Run the scripts in the table above from their own folder. Data paths are relative (`../../data/...`, `./data/...`, `data-pca/...`). [DATA.md](DATA.md) lists every file they read and which script makes it; the intermediate files and decoding outputs are in the data release, so each plot can be redrawn without rerunning its pipeline.

## Requirements

- MATLAB (cluster runs used R2023a) with the Symbolic Math (network programming), Statistics and Machine Learning (decoding, SVM, RSA), and Parallel Computing (`parfor`) toolboxes.
- `slanCM` colormaps from MATLAB File Exchange (only for `figures/network_Trial_animation.m`).

Run `setup_paths` from the repository root before anything else. It adds `scripts/` and only `core/` of the bundled package. Don't use `addpath(genpath(...))` on the repository or the package: `dspm-reservoir-matlab/utils/code_jasonKim_final/` and `verify/helpers/` contain different versions of `ReservoirTanhB_dc`, `gen_basis`, `sym2deriv`, `decomp_poly1_ns` and `tanh_deriv` that would shadow the ones in `scripts/dependencies/`.

## Data

The DMFC recordings and task-optimized RNNs come from Rajalingham et al. (2022, 2025). Please cite those papers if you use them.

## Citation

<!-- TODO: add citation once available -->

## License

MIT; see [LICENSE](LICENSE).
