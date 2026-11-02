function compareOriginalTampered()

clc;
close all;

fprintf('\n=== Original vs Tampered Document Comparison ===\n');

% Select original image
[file1, path1] = uigetfile( ...
    {'*.png;*.jpg;*.jpeg;*.tif;*.tiff;*.bmp', 'Image files'}, ...
    'Select ORIGINAL document image');
if isequal(file1, 0)
    disp('Original image selection cancelled.');
    return;
end
original = imread(fullfile(path1, file1));

% Select tampered image
[file2, path2] = uigetfile( ...
    {'*.png;*.jpg;*.jpeg;*.tif;*.tiff;*.bmp', 'Image files'}, ...
    'Select TAMPERED document image');
if isequal(file2, 0)
    disp('Tampered image selection cancelled.');
    return;
end
tampered = imread(fullfile(path2, file2));

% Convert to grayscale
if size(original, 3) == 3
    originalGray = rgb2gray(original);
else
    originalGray = original;
end
if size(tampered, 3) == 3
    tamperedGray = rgb2gray(tampered);
else
    tamperedGray = tampered;
end

% Make image sizes consistent only if necessary.
% Resizing can affect pixel-level comparison, so warn before doing so.
if ~isequal(size(originalGray), size(tamperedGray))
    warning('Image dimensions differ. Resizing tampered image to match original.');
    tamperedGray = imresize(tamperedGray, size(originalGray));
    if size(tampered, 3) == 3
        tampered = imresize(tampered, [size(originalGray,1), size(originalGray,2)]);
    else
        tampered = tamperedGray;
    end
end

[H, W] = size(originalGray);
fprintf('Original image: %s\n', file1);
fprintf('Tampered image: %s\n', file2);
fprintf('Image dimensions: %d x %d\n', H, W);

% Pixel difference
originalGray = im2uint8(originalGray);
tamperedGray = im2uint8(tamperedGray);
difference = imabsdiff(originalGray, tamperedGray);

% Tunable parameters
differenceThreshold = 20;  % Increase to ignore more subtle differences
minimumArea = 20;          % Remove tiny isolated changes
mergeRadius = 7;           % Join nearby changed pixels/regions

fprintf('Difference threshold: %d\n', differenceThreshold);

% Build and clean changed-pixel mask
changedMask = difference > differenceThreshold;
changedMask = bwareaopen(changedMask, minimumArea);
changedMask = imclose(changedMask, strel('disk', 2, 0));
changedMask = imfill(changedMask, 'holes');

% Use a dilated copy only for grouping nearby changed components into boxes.

stats = regionprops(changedMask, ...
    'BoundingBox', 'Area');

boxes = zeros(0,4);

for k = 1:numel(stats)
    if stats(k).Area >= 20
        boxes(end+1,:) = stats(k).BoundingBox; %#ok<AGROW>
    end
end

fprintf('Detected separate changed regions: %d\n', size(boxes,1));

% Display the detected regions
figure('Name','Separate Detected Changed Regions','Color','w');
imshow(tampered);
hold on;

for k = 1:size(boxes,1)
    rectangle('Position', boxes(k,:), ...
        'EdgeColor','r','LineWidth',1.5);
end

title('Separate Candidate Changed Regions');
hold off;

stats = regionprops(changedMask, 'BoundingBox', 'Area');
% Get candidate regions from the grouped mask
stats = regionprops(groupingMask, 'BoundingBox', 'Area');
boxes = zeros(0,4);
for k = 1:numel(stats)
    if stats(k).Area >= minimumArea
        boxes(end+1,:) = stats(k).BoundingBox; %#ok<AGROW>
    end
end

% Keep boxes within image bounds
for k = 1:size(boxes,1)
    x = max(1, boxes(k,1));
    y = max(1, boxes(k,2));
    x2 = min(W, boxes(k,1) + boxes(k,3));
    y2 = min(H, boxes(k,2) + boxes(k,4));
    boxes(k,:) = [x, y, max(1,x2-x), max(1,y2-y)];
end

changedPixels = nnz(changedMask);
changedPercent = 100 * changedPixels / numel(changedMask);

fprintf('Changed pixels after filtering: %d\n', changedPixels);
fprintf('Changed area: %.2f%% of image pixels\n', changedPercent);
fprintf('Detected merged candidate regions: %d\n', size(boxes,1));

% Figure 1: original vs tampered
figure('Name','Original vs Tampered Comparison','Color','w');
subplot(1,2,1);
imshow(original);
title('Original Document','Interpreter','none');
subplot(1,2,2);
imshow(tampered);
title('Tampered Document','Interpreter','none');

% Figure 2: difference map
figure('Name','Pixel Difference Image','Color','w');
imshow(difference, []);
title(sprintf('Absolute Difference (Threshold = %d)', differenceThreshold));

% Figure 3: candidate changed regions
figure('Name','Cleaned Detected Changed Regions','Color','w');
imshow(tampered);
hold on;
for k = 1:size(boxes,1)
    rectangle('Position', boxes(k,:), 'EdgeColor','r', 'LineWidth',1.5);
end
title(sprintf('Candidate Changed Regions (%d merged boxes)', size(boxes,1)));
hold off;

% Save results in current working folder
imwrite(difference, 'comparison_difference.png');
imwrite(changedMask, 'comparison_changed_mask.png');

overlay = im2uint8(tampered);
if size(overlay,3) == 1
    overlay = repmat(overlay,1,1,3);
end
fig = figure('Visible','off','Color','w');
imshow(overlay);
hold on;
for k = 1:size(boxes,1)
    rectangle('Position', boxes(k,:), 'EdgeColor','r', 'LineWidth',2);
end
title('Detected Candidate Changed Regions');
hold off;
exportgraphics(gca, 'comparison_detected_regions.png', 'Resolution', 150);
close(fig);

fprintf('\nSaved files in current folder:\n');
fprintf('  comparison_difference.png\n');
fprintf('  comparison_changed_mask.png\n');
fprintf('  comparison_detected_regions.png\n');
disp('Comparison complete. This is reference-based validation, not single-image detection.');
end
