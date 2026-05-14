"""Benchmark: compare FAISS index types by add time, search speed, and recall."""
import time

import faiss
import numpy as np

try:
    from tabulate import tabulate
    HAS_TABULATE = True
except ImportError:
    HAS_TABULATE = False

# ── Parameters ────────────────────────────────────────────────────────────────
D  = 128        # vector dimensionality
NB = 100_000    # database size
NQ = 10         # number of query vectors
K  = 5          # top-k neighbours

np.random.seed(42)
xb = np.random.random((NB, D)).astype("float32")
xq = np.random.random((NQ, D)).astype("float32")

# Ground truth via exact search (used for recall calculation)
_gt_index = faiss.IndexFlatL2(D)
_gt_index.add(xb)
_, GT = _gt_index.search(xq, K)


def recall_at_k(indices: np.ndarray) -> float:
    """Fraction of top-1 ground-truth matches found in returned top-K results."""
    hits = sum(GT[i, 0] in indices[i] for i in range(NQ))
    return hits / NQ


def benchmark(name: str, index: faiss.Index, train: bool = False) -> dict:
    if train:
        index.train(xb)

    t0 = time.perf_counter()
    index.add(xb)
    add_time = time.perf_counter() - t0

    t1 = time.perf_counter()
    distances, indices = index.search(xq, K)
    search_ms = (time.perf_counter() - t1) * 1000 / NQ

    return {
        "Index Type":         name,
        "Add Time (s)":       f"{add_time:.4f}",
        "Search (ms/query)":  f"{search_ms:.4f}",
        "Recall@K":           f"{recall_at_k(indices):.2%}",
        "Top-1 Idx":          indices[0][0],
        "Top-1 Dist":         f"{distances[0][0]:.4f}",
    }


# ── Index configurations ───────────────────────────────────────────────────────
results = []

# Exact brute-force
results.append(benchmark("IndexFlatL2", faiss.IndexFlatL2(D)))

# IVF partitioned (approximate)
nlist = 100
quantizer = faiss.IndexFlatL2(D)
ivf = faiss.IndexIVFFlat(quantizer, D, nlist, faiss.METRIC_L2)
ivf.nprobe = 10
results.append(benchmark("IndexIVFFlat", ivf, train=True))

# HNSW graph-based (approximate)
hnsw = faiss.IndexHNSWFlat(D, 32)
results.append(benchmark("IndexHNSWFlat", hnsw))

# ── Print results ──────────────────────────────────────────────────────────────
headers = list(results[0].keys())
rows    = [list(r.values()) for r in results]

print(f"\nFAISS Benchmark  —  D={D}, NB={NB:,}, NQ={NQ}, K={K}\n")

if HAS_TABULATE:
    print(tabulate(rows, headers=headers, tablefmt="rounded_outline"))
else:
    # Fallback: manual fixed-width table
    col_w = [max(len(h), max(len(str(r[i])) for r in rows)) for i, h in enumerate(headers)]
    sep   = "+-" + "-+-".join("-" * w for w in col_w) + "-+"
    fmt   = "| " + " | ".join(f"{{:<{w}}}" for w in col_w) + " |"

    print(sep)
    print(fmt.format(*headers))
    print(sep)
    for row in rows:
        print(fmt.format(*row))
    print(sep)

print()
