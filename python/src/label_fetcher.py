import os
import requests
import zipfile
import pandas as pd
import shutil
class LabelFetcher:
    BASE_URL = "https://registream.com/data"
    DEFAULT_DIR = os.path.expanduser("~/.registream/autolabel_keys")

    def __init__(self, domain='scb', lang='eng', label_type='variables'):
        self.domain = domain
        self.lang = lang

        if label_type == 'values':
            self.label_type = 'value_labels'
        elif label_type == 'variables':
            self.label_type = 'variables'
        else:
            raise ValueError(f"Invalid label type: {label_type}")

        self.label_dir = os.path.expanduser("~/.registream/autolabel_keys")
        self.csv_name = f"{self.domain}_{self.label_type}_{self.lang}.csv"
        self.zip_name = f"{self.domain}_{self.label_type}_{self.lang}.zip"
        self.csv_path = os.path.join(self.label_dir, self.csv_name)
        self.csv_folder = os.path.join(self.label_dir, f"{self.domain}_{self.label_type}_{self.lang}")

    def ensure_labels(self):
        if os.path.exists(self.csv_path):
            return self.csv_path

        # If constituent CSV files folder exists, just merge them
        if os.path.exists(self.csv_folder):
            self.combine_csv_files()
            return self.csv_path

        # Neither file nor folder exists, prompt download
        print(f"\nThe file {self.csv_name} does not exist locally.")
        permission = input("Would you like to download it? (yes/no): ").strip().lower()
        if permission != "yes":
            raise PermissionError("Download permission denied.")

        self.download_and_extract()
        self.combine_csv_files()

        if not os.path.exists(self.csv_path):
            raise FileNotFoundError("CSV file not found after extraction. Please contact developers.")

        return self.csv_path

    def download_and_extract(self):
        self.clean_up()

        zip_url = f"https://registream.com/data/{self.zip_name}"
        zip_path = os.path.join(self.label_dir, self.zip_name)

        os.makedirs(self.label_dir, exist_ok=True)
        print(f"Downloading {zip_url}...")
        response = requests.get(zip_url)
        response.raise_for_status()
        with open(zip_path, 'wb') as f:
            f.write(response.content)

        with zipfile.ZipFile(zip_path, 'r') as zip_ref:
            zip_ref.extractall(self.label_dir)

        os.remove(zip_path)


    def combine_csv_files(self):
        csv_files = sorted([
            os.path.join(self.csv_folder, f)
            for f in os.listdir(self.csv_folder)
            if f.endswith('.csv')
        ])

        if not csv_files:
            raise FileNotFoundError(f"No CSV files found in {self.csv_folder}.")

        df_list = []
        for f in csv_files:
            try:
                df = pd.read_csv(
                    f,
                    delimiter=';',              # <-- corrected delimiter here
                    quoting=0,
                    on_bad_lines='skip',
                    encoding='utf-8'
                )
                df_list.append(df)
            except pd.errors.ParserError as e:
                print(f"Warning: Issue parsing {f} ({e}). Skipping problematic lines.")

        if not df_list:
            raise ValueError("All constituent CSV files failed to parse.")

        df_combined = pd.concat(df_list, ignore_index=True)
        df_combined_sorted = df_combined.sort_values(by='variable')
        df_combined_sorted = df_combined_sorted.drop_duplicates(subset=['variable'], keep='first')
        df_combined_sorted.to_csv(self.csv_path, index=False)

        # clean up constituent folder
        self.clean_up()

        return self.csv_path
    
    def clean_up(self):
        if os.path.exists(self.csv_folder):
            shutil.rmtree(self.csv_folder)