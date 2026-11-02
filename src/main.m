
clc;
clear;
close all;

disp('Starting Document Forgery Detection...');

% Select a document image
[file, path] = uigetfile( ...
    {'*.jpg;*.jpeg;*.png;*.tif;*.tiff', ...
    'Document Images'}, ...
    'Select a Document Image');

if isequal(file, 0)
    disp('No image selected.');
    return;
end

% Load the image
img = imread(fullfile(path, file));
disp('Document image loaded successfully.');

% Preprocess the document
grayImg = preprocessImage(img);
disp('Preprocessing completed.');

% Display original and processed images
figure('Name', 'Document Preprocessing');

subplot(1, 2, 1);
imshow(img);
title('Original Document');

subplot(1, 2, 2);
imshow(grayImg);
title('Preprocessed Grayscale Image');

% Run copy-move detection
disp('Calling copy-move detection...');

[resultImg, matchedPoints1, matchedPoints2] = ...
    detectCopyMove(grayImg);

disp('Detection function returned.');
