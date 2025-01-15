################################################################################
# Makefile for building and profiling CUDA sources: sum.cu, matmul.cu, 
# cublaslt_matmul.cu. The final .ncu-rep files go to <GPU_NAME>/ncu_reports/
# so that the "profile.sh" script can parse them into CSVs.
################################################################################

# --------------------- Basic Compiler Settings ---------------------
# You can adjust these paths and flags as needed.
NVCC_FLAGS      = -std=c++17 -O3 -DNDEBUG -w
NVCC_LDFLAGS    = -lcublas -lcuda
NVCC_INCLUDES   = -I/usr/local/cuda-12.6/include
NVCC_LDLIBS     =
OUT_DIR         = out

# Example: detect the first GPU’s compute capability removing any dot, e.g. "90" → "90a".
# If you want to override this, comment or adjust.
GPU_COMPUTE_CAPABILITY = $(shell nvidia-smi --query-gpu=compute_cap --format=csv,noheader | sed 's/\.//g' | sort -n | head -n 1)
GPU_COMPUTE_CAPABILITY := $(strip $(GPU_COMPUTE_CAPABILITY))
GPU_COMPUTE_CAPABILITY := $(if $(findstring 90,${GPU_COMPUTE_CAPABILITY}),90a,${GPU_COMPUTE_CAPABILITY})

# Detect GPU name for use in directory naming (replaces spaces with underscores).
GPUNAME = $(shell nvidia-smi --query-gpu=name --format=csv,noheader | head -n 1 | sed 's/ /_/g')
REPORTS_DIR = $(GPUNAME)/ncu_reports

# Nsight Compute location. If you don't need sudo, remove "sudo" below.
NCU_PATH    := $(shell which ncu)
NCU_COMMAND  = sudo $(NCU_PATH) --set full --import-source yes

# Additional recommended flags for CUDA.
# -Xcompiler=-fPIE, etc. to help with certain linking conditions.
NVCC_FLAGS += --expt-relaxed-constexpr --expt-extended-lambda --use_fast_math \
              -Xcompiler=-fPIE -Xcompiler=-Wno-psabi -Xcompiler=-fno-strict-aliasing

# Example of setting a specific arch. Adjust if your GPU is different.
NVCC_FLAGS += -arch=sm_90a

# Final NVCC command
NVCC_BASE = nvcc $(NVCC_FLAGS) $(NVCC_LDFLAGS) -lineinfo $(NVCC_INCLUDES) $(NVCC_LDLIBS)

# ----------------------- Source Files -----------------------
SUM_SRC          = sum.cu
MATMUL_SRC       = matmul.cu
CUBLASLT_SRC     = examples/matmul/cublaslt_matmul.cu

# Outputs go into ./out/<target_name>
# The variable $@ is the name of the target. $(CUDA_OUTPUT_FILE) is set below.
CUDA_OUTPUT_FILE = -o $(OUT_DIR)/$@

# ----------------------- Build Rules -------------------------
# sum
sum: $(SUM_SRC)
	mkdir -p $(OUT_DIR)
	$(NVCC_BASE) $^ $(CUDA_OUTPUT_FILE)

# matmul
matmul: $(MATMUL_SRC)
	mkdir -p $(OUT_DIR)
	$(NVCC_BASE) $^ $(CUDA_OUTPUT_FILE)

# cublaslt_matmul
cublaslt_matmul: $(CUBLASLT_SRC)
	mkdir -p $(OUT_DIR)
	$(NVCC_BASE) $^ $(CUDA_OUTPUT_FILE)

# ----------------------- Profiling Rules ----------------------
# For each profile rule, we specify an output .ncu-rep in <GPU_NAME>/ncu_reports.
sumprofile: sum
	mkdir -p $(REPORTS_DIR)
	$(NCU_COMMAND) -o $(REPORTS_DIR)/$@.ncu-rep -f $(OUT_DIR)/sum

matmulprofile: matmul
	mkdir -p $(REPORTS_DIR)
	$(NCU_COMMAND) -o $(REPORTS_DIR)/$@.ncu-rep -f $(OUT_DIR)/matmul

cublaslt_matmulprofile: cublaslt_matmul
	mkdir -p $(REPORTS_DIR)
	$(NCU_COMMAND) -o $(REPORTS_DIR)/$@.ncu-rep -f $(OUT_DIR)/cublaslt_matmul

# ------------------- "all" Target -------------------
# "make all" compiles all three binaries and then profiles them, 
# and finally calls the profile.sh script to generate CSVs in the same run.
all: sum matmul cublaslt_matmul sumprofile matmulprofile cublaslt_matmulprofile analyze

# Optionally run the shell script (profile.sh) after all ncu-rep files are generated
analyze:
	@echo "Running profile.sh to analyze Nsight Compute reports..."
	@bash profile.sh

# ------------------- Clean Up -------------------
clean:
	rm -f $(OUT_DIR)/*
	rm -rf $(GPUNAME)
	@echo "Cleaned build outputs and profiling directory."
