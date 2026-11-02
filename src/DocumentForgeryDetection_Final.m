%% DOCUMENT FORGERY DETECTION - FINAL READY-TO-RUN SCRIPT
% Required input files in MATLAB Current Folder:
%   sample_document.png.png
%   tampered_document.png
% Output folder: DocumentForgeryResults
% This script detects differences against a reference image. It does not
% independently prove forgery.

clc; clear; close all;

originalFile = 'sample_document.png.png';
tamperedFile = 'tampered_document.png';

if ~isfile(originalFile)
    [f,p] = uigetfile({'*.png;*.jpg;*.jpeg;*.tif;*.bmp','Image files'}, ...
        'Select ORIGINAL document image');
    if isequal(f,0), error('No original image selected.'); end
    originalFile = fullfile(p,f);
end
if ~isfile(tamperedFile)
    [f,p] = uigetfile({'*.png;*.jpg;*.jpeg;*.tif;*.bmp','Image files'}, ...
        'Select TAMPERED document image');
    if isequal(f,0), error('No tampered image selected.'); end
    tamperedFile = fullfile(p,f);
end

original = imread(originalFile);
tampered = imread(tamperedFile);

if size(original,3)==3, originalGray=rgb2gray(original); else, originalGray=original; end
if size(tampered,3)==3, tamperedGray=rgb2gray(tampered); else, tamperedGray=tampered; end

if ~isequal(size(originalGray),size(tamperedGray))
    error('Images have different dimensions. Align them to the same size first.');
end

originalGray = im2uint8(originalGray);
tamperedGray = im2uint8(tamperedGray);
diffImage = imabsdiff(originalGray,tamperedGray);

outputFolder = 'DocumentForgeryResults';
if ~exist(outputFolder,'dir'), mkdir(outputFolder); end

%% Threshold comparison
thresholds = [25 40 60];
minComponentArea = 30;
results = zeros(numel(thresholds),3);

figure('Name','Threshold Comparison','Color','w');
for k=1:numel(thresholds)
    threshold = thresholds(k);
    mask = diffImage > threshold;
    mask = bwareaopen(mask,minComponentArea,8);
    changedPixels = nnz(mask);
    changedPercentage = 100*changedPixels/numel(mask);
    results(k,:) = [threshold,changedPixels,changedPercentage];

    subplot(2,3,k);
    imshow(mask);
    title(sprintf('Threshold = %d',threshold));

    subplot(2,3,k+3);
    imshow(imoverlay(tamperedGray,bwperim(mask),[1 0 0]));
    title(sprintf('Changed pixels: %.2f%%',changedPercentage));

    imwrite(mask,fullfile(outputFolder, ...
        sprintf('difference_mask_threshold_%d.png',threshold)));
end

%% Candidate regions using threshold 40
selectedThreshold = 40;
diffMask = diffImage > selectedThreshold;
diffMask = bwareaopen(diffMask,minComponentArea,8);
diffMask = imclose(diffMask,strel('rectangle',[5 5]));
diffMask = imfill(diffMask,'holes');

CC = bwconncomp(diffMask,8);
stats = regionprops(CC,'Area','BoundingBox','Centroid');

if isempty(stats)
    order = [];
else
    [~,order] = sort([stats.Area],'descend');
end
numberToShow = min(10,numel(order));

figure('Name','Candidate Difference Regions','Color','w');
imshow(tampered);
hold on;
title(sprintf('Largest Candidate Difference Regions (Threshold %d)',selectedThreshold));

fprintf('\n===== DOCUMENT DIFFERENCE REPORT =====\n');
fprintf('Original: %s\nTampered: %s\n',originalFile,tamperedFile);
fprintf('Image dimensions: %d x %d\n',size(originalGray,1),size(originalGray,2));
fprintf('\nThreshold | Changed pixels | Changed percentage\n');
for k=1:size(results,1)
    fprintf('%9d | %14d | %7.2f%%\n',results(k,1),results(k,2),results(k,3));
end
fprintf('\nConnected candidate regions at threshold %d: %d\n',selectedThreshold,CC.NumObjects);
fprintf('Largest candidate regions:\n');

for k=1:numberToShow
    idx=order(k);
    bb=stats(idx).BoundingBox;
    rectangle('Position',bb,'EdgeColor','r','LineWidth',1.5);
    text(bb(1),max(1,bb(2)-10),sprintf('%d',k),'Color','y', ...
        'FontSize',10,'FontWeight','bold','BackgroundColor','k');
    fprintf('Region %d | Area: %d | X: %.0f, Y: %.0f, Width: %.0f, Height: %.0f\n', ...
        k,stats(idx).Area,bb(1),bb(2),bb(3),bb(4));
end
hold off;
exportgraphics(gca,fullfile(outputFolder,'candidate_regions_annotated.png'));

imwrite(diffImage,fullfile(outputFolder,'absolute_difference.png'));

figure('Name','Original vs Tampered vs Difference','Color','w');
subplot(1,3,1); imshow(original); title('Original Document');
subplot(1,3,2); imshow(tampered); title('Tampered Document');
subplot(1,3,3); imshow(diffImage,[]); title('Absolute Difference');
exportgraphics(gcf,fullfile(outputFolder,'comparison_summary.png'));

%% Save text report
reportFile=fullfile(outputFolder,'analysis_report.txt');
fid=fopen(reportFile,'w');
if fid~=-1
    fprintf(fid,'DOCUMENT FORGERY DETECTION - DIFFERENCE REPORT\n\n');
    fprintf(fid,'Original: %s\nTampered: %s\n',originalFile,tamperedFile);
    fprintf(fid,'Image dimensions: %d x %d\n',size(originalGray,1),size(originalGray,2));
    fprintf(fid,'\nThreshold | Changed pixels | Changed percentage\n');
    for k=1:size(results,1)
        fprintf(fid,'%9d | %14d | %7.2f%%\n',results(k,1),results(k,2),results(k,3));
    end
    fprintf(fid,'\nSelected threshold: %d\nConnected candidate regions: %d\n', ...
        selectedThreshold,CC.NumObjects);
    fprintf(fid,'\nLargest candidate regions:\n');
    for k=1:numberToShow
        idx=order(k); bb=stats(idx).BoundingBox;
        fprintf(fid,'Region %d | Area: %d | X: %.0f, Y: %.0f, Width: %.0f, Height: %.0f\n', ...
            k,stats(idx).Area,bb(1),bb(2),bb(3),bb(4));
    end
    fprintf(fid,'\nHighlighted areas are differences from the reference image, not definitive proof of forgery.\n');
    fclose(fid);
else
    warning('Could not write text report.');
end

fprintf('\nCompleted. Results saved in: %s\n',outputFolder);
