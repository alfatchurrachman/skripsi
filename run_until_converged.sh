#!/bin/bash
# =============================================================================
# run_until_converged.sh
# =============================================================================
# Menjalankan TOPAS berulang kali hingga relative error DSB/Gy/Gbp
# across run mencapai TARGET_ERROR, lalu membuat file .xlsx ringkasan.
#
# Cara pakai:
#   chmod +x run_until_converged.sh
#   ./run_until_converged.sh
# =============================================================================

# =============================================================================
# KONFIGURASI
# =============================================================================
TOPAS_PARAM="Nucleus.topas"
TARGET_ERROR=0.1
MAX_RUNS=1000
OUTPUT_DIR="outputs"
TOPAS_BIN="$HOME/shellScripts/topas"
PHSP_OUTPUT="DNADamage.phsp"
HEADER_OUTPUT="DNADamage.header"
run=1
# =============================================================================


# -----------------------------------------------------------------------------
# Persiapan awal
# -----------------------------------------------------------------------------
mkdir -p "$OUTPUT_DIR"

if ! command -v "$TOPAS_BIN" &> /dev/null; then
    echo "[ERROR] TOPAS tidak ditemukan: $TOPAS_BIN"
    exit 1
fi

if [ ! -f "$TOPAS_PARAM" ]; then
    echo "[ERROR] File parameter tidak ditemukan: $TOPAS_PARAM"
    exit 1
fi

if ! command -v python3 &> /dev/null; then
    echo "[ERROR] python3 tidak ditemukan."
    exit 1
fi

if [ ! -f "check_error.py" ]; then
    echo "[ERROR] check_error.py tidak ditemukan."
    exit 1
fi

if [ ! -f "generate_xlsx.py" ]; then
    echo "[ERROR] generate_xlsx.py tidak ditemukan."
    exit 1
fi

echo "============================================================"
echo "  TOPAS Convergence Runner"
echo "  Target relative error : $TARGET_ERROR"
echo "  Maks run              : $MAX_RUNS"
echo "  Output dir            : $OUTPUT_DIR/"
echo "============================================================"


# -----------------------------------------------------------------------------
# Fungsi: buat xlsx di akhir
# -----------------------------------------------------------------------------
make_xlsx() {
    echo ""
    echo "  Membuat file .xlsx ringkasan..."
    python3 generate_xlsx.py 2>&1
    if [ $? -eq 0 ]; then
        echo "  File xlsx berhasil dibuat: $OUTPUT_DIR/hasil_simulasi.xlsx"
    else
        echo "  [WARNING] Gagal membuat file xlsx. Cek generate_xlsx.py."
    fi
}


# -----------------------------------------------------------------------------
# Loop utama
# -----------------------------------------------------------------------------
while [ "$run" -le "$MAX_RUNS" ]; do

    echo ""
    echo "------------------------------------------------------------"
    echo "  RUN ke-$run dimulai..."
    echo "------------------------------------------------------------"

    # Set seed
    if grep -q "i:Ts/Seed" "$TOPAS_PARAM"; then
        sed -i "s/^i:Ts\/Seed = .*/i:Ts\/Seed = $run/" "$TOPAS_PARAM"
    else
        echo "i:Ts/Seed = $run" >> "$TOPAS_PARAM"
    fi
    echo "  Seed diset ke: $run"

    # Jalankan TOPAS
    echo "  Menjalankan TOPAS..."
    "$TOPAS_BIN" "$TOPAS_PARAM"
    TOPAS_EXIT=$?

    # Tangani error / segfault: skip seed ini, lanjut ke berikutnya
    if [ $TOPAS_EXIT -ne 0 ]; then
        echo "  [WARNING] TOPAS gagal pada run ke-$run (exit code: $TOPAS_EXIT). Seed ini dilewati."
        run=$((run + 1))
        continue
    fi

    # Pastikan file output tersedia setelah TOPAS selesai
    if [ ! -f "$PHSP_OUTPUT" ]; then
        echo "  [WARNING] File output tidak ditemukan setelah run ke-$run. Seed ini dilewati."
        run=$((run + 1))
        continue
    fi

    cp "$PHSP_OUTPUT" "$OUTPUT_DIR/DNADamage_${run}.phsp"
    echo "  Output dicopy ke: $OUTPUT_DIR/DNADamage_${run}.phsp"

    # Copy header sekali saja (dari run yang berhasil pertama kali)
    if [ ! -f "$OUTPUT_DIR/DNADamage.header" ] && [ -f "$HEADER_OUTPUT" ]; then
        cp "$HEADER_OUTPUT" "$OUTPUT_DIR/DNADamage.header"
        echo "  Header dicopy ke: $OUTPUT_DIR/DNADamage.header"
    fi

    # Hitung konvergensi
    echo "  Menghitung konvergensi..."
    ERROR=$(python3 check_error.py 2>/dev/tty)

    echo ""
    echo "  Relative error saat ini: $ERROR"

    # Cek eksplisit dulu apakah ERROR adalah "inf" (belum cukup run)
    # bc tidak bisa membandingkan "inf" dengan benar — dianggap 0 sehingga
    # 0 < 0.05 = true, padahal belum konvergen sama sekali
    if [ "$ERROR" = "inf" ] || [ -z "$ERROR" ]; then
        IS_CONVERGED=0
    else
        IS_CONVERGED=$(echo "$ERROR < $TARGET_ERROR" | bc -l 2>/dev/null)
    fi

    if [ "$IS_CONVERGED" = "1" ]; then
        echo ""
        echo "============================================================"
        echo "  KONVERGEN!"
        echo "  Relative error = $ERROR < target $TARGET_ERROR"
        echo "  Total run      : $run"
        echo "============================================================"
        make_xlsx
        exit 0
    else
        echo "  Belum konvergen. Lanjut ke run berikutnya..."
    fi

    run=$((run + 1))

done

# Mencapai batas maksimum
echo ""
echo "============================================================"
echo "  [PERINGATAN] Mencapai batas maksimum $MAX_RUNS run."
echo "  Relative error terakhir: $ERROR"
echo "  Pertimbangkan menambah MAX_RUNS atau histories per run."
echo "============================================================"
make_xlsx
exit 1
