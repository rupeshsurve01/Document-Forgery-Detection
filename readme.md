# Document Forgery Detection Using Digital Image Processing in MATLAB

## Overview

Document Forgery Detection is a MATLAB-based mini-project that analyzes document images to identify potential signs of manipulation using digital image processing techniques.

The project implements two approaches:

1. **Copy-Move Detection:** Uses SURF feature detection, feature matching, displacement clustering, and RANSAC-based geometric verification to identify candidate regions that may have been copied and pasted within the same document.
2. **Reference-Based Comparison:** Compares an original document with a suspected tampered document to highlight pixel-level differences and changed regions.

## Features

- Document image preprocessing
- SURF feature detection and matching
- Copy-move forgery candidate detection
- RANSAC-based geometric verification
- Original-versus-tampered image comparison
- Difference image and changed-pixel mask generation
- Visual highlighting of candidate regions

## Technologies Used

- MATLAB
- Image Processing Toolbox
- Computer Vision Toolbox
- Statistics and Machine Learning Toolbox, where required by the implementation

## Project Structure

```text
Document-Forgery-Detection/
├── src/
│   ├── main.m
│   ├── preprocessImage.m
│   ├── detectCopyMove.m
│   ├── compareOriginalTampered.m
│   └── createTamperedImage.m
├── images/
│   ├── sample_document.png.png
│   ├── tampered_document.png
│   ├── comparison_difference.png
│   └── comparison_changed_mask.png
├── docs/
└── README.md
```

*The folder structure above is illustrative; update it to match the files actually committed.*

## Requirements

- MATLAB with a compatible release
- Image Processing Toolbox
- Computer Vision Toolbox
- Statistics and Machine Learning Toolbox if required by the selected implementation
- Sample document images in a supported format, such as PNG or JPG

## How to Run

1. Clone or download this repository.
2. Open MATLAB and set the project directory as the Current Folder.
3. Ensure the required toolboxes are installed.
4. Run `main.m` for single-image copy-move candidate detection.
5. Run `compareOriginalTampered.m` to compare a trusted original image with a suspected tampered image.
6. Inspect the generated visualizations and output images.

Ensure that the input image paths in the scripts match the actual locations of the images.

## Important Limitations

- Detected regions are candidates for further inspection, not definitive proof of forgery.
- The single-image method may produce false positives or miss certain manipulations.
- Reference-based comparison requires an original image and a suspected tampered image that are suitably aligned.
- Differences caused by resizing, compression, or other image processing can affect comparison results.

## Project Purpose

This project demonstrates classical digital image processing and computer vision techniques for preliminary document forgery analysis. It is intended for academic and educational purposes and is not a substitute for professional forensic examination.
