import os
import requests
import zipfile
import pandas as pd
import shutil
import platform

class LabelFetcher:
    BASE_URL = "https://registream.com/data"
    
    # ANSI color codes
    YELLOW = "\033[93m"  # Warning/info
    GREEN = "\033[92m"   # Success
    RED = "\033[91m"     # Error
    BLUE = "\033[94m"    # Info/prompt
    BOLD = "\033[1m"     # Bold text
    RESET = "\033[0m"    # Reset formatting
    
    # Class-level flag to track if the custom directory message has been shown
    _custom_dir_message_shown = False
    
    @classmethod
    def get_default_dir(cls):
        """
        Get the directory for registream data based on the environment variable or default location.
        
        Returns:
        --------
        str
            The directory path for registream data
        """
        # Check if a custom directory is set in environment variable
        custom_dir = os.environ.get('REGISTREAM_DIR')
        if custom_dir:
            # Only show the message once per script execution
            if not cls._custom_dir_message_shown:
                print(f"\n{cls.YELLOW}Using custom REGISTREAM_DIR: {custom_dir}{cls.RESET}")
                cls._custom_dir_message_shown = True
            return os.path.join(custom_dir, 'autolabel_keys')
            
        # Use platform-specific default directories if no custom directory is set
        system = platform.system()
        if system == 'Windows':
            # Windows: C:\Users\<username>\AppData\Local\registream\
            return os.path.join(os.path.expanduser('~'), 'AppData', 'Local', 'registream', 'autolabel_keys')
        else:
            # macOS/Linux: ~/.registream/
            return os.path.expanduser('~/.registream/autolabel_keys')

    def __init__(self, domain='scb', lang='eng', label_type='variables'):
        self.domain = domain
        self.lang = lang

        if label_type == 'values':
            self.label_type = 'value_labels'
        elif label_type == 'variables':
            self.label_type = 'variables'
        else:
            raise ValueError(f"Invalid label type: {label_type}")

        # Get directory from environment variable or default
        self.label_dir = self.get_default_dir()
            
        self.csv_name = f"{self.domain}_{self.label_type}_{self.lang}.csv"
        self.zip_name = f"{self.domain}_{self.label_type}_{self.lang}.zip"
        self.csv_path = os.path.join(self.label_dir, self.csv_name)
        self.csv_folder = os.path.join(self.label_dir, f"{self.domain}_{self.label_type}_{self.lang}")

    def ensure_labels(self):
        """
        Ensure that the label CSV file exists, downloading and extracting if necessary.
        
        Returns:
        --------
        str
            Path to the CSV file containing the labels
        """
        if os.path.exists(self.csv_path):
            return self.csv_path

        # If constituent CSV files folder exists, just merge them
        if os.path.exists(self.csv_folder):
            self.combine_csv_files()
            return self.csv_path

        # Neither file nor folder exists, prompt download
        print(f"\n{self.BLUE}{self.BOLD}File Not Found{self.RESET}")
        print(f"{self.BLUE}The file {self.BOLD}{self.csv_name}{self.RESET}{self.BLUE} does not exist locally.{self.RESET}")
        print(f"{self.BLUE}Expected location: {self.BOLD}{self.csv_path}{self.RESET}")
        print(f"{self.BLUE}You can manually place the file or constituent CSV files in this location.{self.RESET}\n")
        
        permission = input(f"{self.YELLOW}Would you like to download it now? (yes/no): {self.RESET}").strip().lower()
        if permission != "yes":
            print(f"\n{self.RED}{self.BOLD}Download permission denied.{self.RESET}")
            print(f"\n{self.BLUE}{self.BOLD}Please follow these manual steps:{self.RESET}")
            print(f"{self.BLUE}1. Download {self.BOLD}{self.zip_name}{self.RESET}{self.BLUE} from {self.BOLD}https://registream.com/data/{self.RESET}")
            print(f"{self.BLUE}2. Extract the zip file to get a folder named {self.BOLD}{self.domain}_{self.label_type}_{self.lang}{self.RESET}")
            print(f"{self.BLUE}3. Place this folder in {self.BOLD}{self.label_dir}{self.RESET}")
            print(f"{self.BLUE}4. Alternatively, you can set a custom directory using the REGISTREAM_DIR environment variable{self.RESET}")
            print(f"{self.BLUE}   Example: {self.BOLD}export REGISTREAM_DIR=\"path/to/your/custom/directory\"{self.RESET}\n")
            raise PermissionError("Download permission denied.")

        self.download_and_extract()
        self.combine_csv_files()

        if not os.path.exists(self.csv_path):
            print(f"\n{self.RED}{self.BOLD}Error: CSV file not found after extraction.{self.RESET}")
            print(f"{self.RED}Please contact developers or try manual installation.{self.RESET}\n")
            raise FileNotFoundError("CSV file not found after extraction.")

        return self.csv_path

    def download_and_extract(self):
        """
        Download and extract the zip file containing label data.
        """
        self.clean_up()

        zip_url = f"{self.BASE_URL}/{self.zip_name}"
        zip_path = os.path.join(self.label_dir, self.zip_name)

        os.makedirs(self.label_dir, exist_ok=True)
        print(f"\n{self.BLUE}Downloading {self.BOLD}{zip_url}{self.RESET}{self.BLUE}...{self.RESET}")
        try:
            response = requests.get(zip_url)
            response.raise_for_status()
            with open(zip_path, 'wb') as f:
                f.write(response.content)

            print(f"{self.BLUE}Extracting files...{self.RESET}")
            with zipfile.ZipFile(zip_path, 'r') as zip_ref:
                zip_ref.extractall(self.label_dir)

            os.remove(zip_path)
            print(f"{self.GREEN}Download and extraction successful!{self.RESET}\n")
        except requests.exceptions.RequestException as e:
            print(f"\n{self.RED}{self.BOLD}Error downloading file: {e}{self.RESET}")
            print(f"\n{self.BLUE}{self.BOLD}Please follow these manual steps:{self.RESET}")
            print(f"{self.BLUE}1. Download {self.BOLD}{self.zip_name}{self.RESET}{self.BLUE} from {self.BOLD}https://registream.com/data/{self.RESET}")
            print(f"{self.BLUE}2. Extract the zip file to get a folder named {self.BOLD}{self.domain}_{self.label_type}_{self.lang}{self.RESET}")
            print(f"{self.BLUE}3. Place this folder in {self.BOLD}{self.label_dir}{self.RESET}\n")
            raise

    def combine_csv_files(self):
        """
        Combine multiple CSV files into a single CSV file.
        
        Returns:
        --------
        str
            Path to the combined CSV file
        """
        csv_files = sorted([
            os.path.join(self.csv_folder, f)
            for f in os.listdir(self.csv_folder)
            if f.endswith('.csv')
        ])

        if not csv_files:
            print(f"\n{self.RED}{self.BOLD}Error: No CSV files found.{self.RESET}")
            print(f"{self.RED}No CSV files found in {self.BOLD}{self.csv_folder}{self.RESET}\n")
            raise FileNotFoundError(f"No CSV files found in {self.csv_folder}.")

        print(f"{self.BLUE}Combining {self.BOLD}{len(csv_files)}{self.RESET}{self.BLUE} CSV files...{self.RESET}")
        df_list = []
        for f in csv_files:
            try:
                df = pd.read_csv(
                    f,
                    delimiter=';',
                    quoting=0,
                    on_bad_lines='skip',
                    encoding='utf-8'
                )
                df_list.append(df)
            except pd.errors.ParserError as e:
                print(f"{self.YELLOW}Warning: Issue parsing {os.path.basename(f)} ({e}). Skipping problematic lines.{self.RESET}")

        if not df_list:
            print(f"\n{self.RED}{self.BOLD}Error: All CSV files failed to parse.{self.RESET}\n")
            raise ValueError("All constituent CSV files failed to parse.")

        df_combined = pd.concat(df_list, ignore_index=True)
        df_combined_sorted = df_combined.sort_values(by='variable')
        df_combined_sorted = df_combined_sorted.drop_duplicates(subset=['variable'], keep='first')
        
        # Ensure directory exists
        os.makedirs(os.path.dirname(self.csv_path), exist_ok=True)
        df_combined_sorted.to_csv(self.csv_path, index=False)
        
        print(f"{self.GREEN}Successfully combined CSV files into {self.BOLD}{self.csv_path}{self.RESET}\n")

        # clean up constituent folder
        self.clean_up()

        return self.csv_path
    
    def clean_up(self):
        """
        Clean up temporary files and folders.
        """
        if os.path.exists(self.csv_folder):
            shutil.rmtree(self.csv_folder)