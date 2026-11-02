
clc;
clear;
close all;

% Select the original document
[file, path] = uigetfile( ...
    {'*.jpg;*.jpeg;*.png;*.tif;*.tiff', ...
    'Document Images'}, ...
    'Select Original Document');

if isequal(file, 0)
    disp('No image selected.');
    return;
end

img = imread(fullfile(path, file));

% Display document and select source region
figure('Name', 'Select Source Region');
imshow(img);
title({'Select a small region to copy', ...
    'Drag a rectangle around text or a table cell'});

sourceRect = getrect;
sourceRect = round(sourceRect);

if sourceRect(3) < 2 || sourceRect(4) < 2
    error('Please select a larger source region.');
end

% Crop the selected region
croppedRegion = imcrop(img, sourceRect);

if isempty(croppedRegion)
    error('Could not crop the selected region.');
end

% Select destination location
figure('Name', 'Select Destination');
imshow(img);
title({'Click the destination location', ...
    'Choose a different area of the document'});

[x, y] = ginput(1);

x = round(x);
y = round(y);

% Calculate destination boundaries
[h, w, ~] = size(croppedRegion);
[imgH, imgW, ~] = size(img);

% Keep pasted region within image boundaries
x = max(1, min(x, imgW - w + 1));
y = max(1, min(y, imgH - h + 1));

% Create a separate tampered image
tamperedImg = img;

tamperedImg(y:y+h-1, x:x+w-1, :) = croppedRegion;

% Save the tampered image
outputFile = fullfile(path, 'tampered_document.png');
imwrite(tamperedImg, outputFile);

% Display comparison
figure('Name', 'Copy-Move Forgery Simulation');

subplot(1, 2, 1);
imshow(img);
title('Original Document');

subplot(1, 2, 2);
imshow(tamperedImg);
title('Tampered Document');

fprintf('Tampered image saved at:\n%s\n', outputFile);
