"""Handle jac compile data for blog.

This script is used to handle the jac compile data for jac playground.
Simplified version for standalone blog setup.
"""

import os
import sys
import zipfile

# Try to import jaclang and find its location
try:
    import jaclang
    TARGET_FOLDER = os.path.dirname(jaclang.__file__)
except ImportError:
    TARGET_FOLDER = None

EXTRACTED_FOLDER = "docs/playground"
PLAYGROUND_ZIP_PATH = os.path.join(EXTRACTED_FOLDER, "jaclang.zip")
ZIP_FOLDER_NAME = "jaclang"


def pre_build_hook(**kwargs: dict) -> None:
    """Run pre-build tasks for preparing files.

    This function is called before the build process starts.
    """
    print("Running pre-build hook...")

    if TARGET_FOLDER is None:
        print("WARNING: jaclang package not found. Runnable code blocks will not work.")
        print("Install jaclang to enable interactive code execution: pip install jaclang")
        return

    if os.path.exists(PLAYGROUND_ZIP_PATH):
        print(f"Removing existing zip file: {PLAYGROUND_ZIP_PATH}")
        os.remove(PLAYGROUND_ZIP_PATH)

    create_playground_zip()
    print("Jaclang zip file created successfully.")


def create_playground_zip() -> None:
    """Create a zip file containing the jaclang folder.

    The zip file is created in the EXTRACTED_FOLDER directory.
    """
    print("Creating jaclang zip...")

    if not os.path.exists(TARGET_FOLDER):
        print(f"WARNING: Folder not found: {TARGET_FOLDER}")
        return

    # Ensure the playground directory exists
    os.makedirs(EXTRACTED_FOLDER, exist_ok=True)

    with zipfile.ZipFile(PLAYGROUND_ZIP_PATH, "w", zipfile.ZIP_DEFLATED) as zipf:
        for root, _, files in os.walk(TARGET_FOLDER):
            for file in files:
                file_path = os.path.join(root, file)
                arcname = os.path.join(
                    ZIP_FOLDER_NAME, os.path.relpath(file_path, TARGET_FOLDER)
                )
                zipf.write(file_path, arcname)

    print(f"Zip saved to: {PLAYGROUND_ZIP_PATH}")


# This hook is called by MkDocs when loading the config
pre_build_hook()
