Di repo ini ada:
- Nucleus.topas : file parameter simulasi
- run_until_converged.sh : file untuk memerintahkan simulasi berulang. Di dalemnya udah ada parameter perulangan simulasi seperti jumlah simulasi,
  error target batas konvergensi
- check_error.py : untuk ngecek error, dipanggil di run_until_converged.sh
- generate_xlsx.py : untuk ngeparsing hasil simulasi (format .phsp) menjadi excel, dan ngegabungin semua running

Cara menjalankan run_until_converged.sh dijelasin di dalem file tersebut, yakni:
1. chmod +x run_until_converged.sh
2. ./run_until_converged.sh
