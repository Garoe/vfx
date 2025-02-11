%% KLT_test.m
clear; close all; clc

%% Initialise
% Left image folder
if isunix
    folder_left = '~/workspaces/matlab/vfx/Data/Richard2/Left/images_rect/';
else
    folder_left = 'C:\Users\Richard\Desktop\CDE\Semester 2\Visual Effects\Data\Richard2\Left\images_rect';
end
% Right image folder
if isunix
    folder_right = '~/workspaces/matlab/vfx/Data/Richard2/Right/images_rect/';
else
    folder_right = 'C:\Users\Richard\Desktop\CDE\Semester 2\Visual Effects\Data\Richard2\Right\images_rect';
end
imgType = 'jpg';
sDir_left =  dir( fullfile(folder_left ,['*' imgType]) );
sDir_right =  dir( fullfile(folder_right ,['*' imgType]) );
numImgs = size(sDir_left, 1);

firstFrame = 350;
lastFrame = 410;
load(['points_left_' num2str(firstFrame,'% 05.f') '.mat']);
load(['points_right_' num2str(firstFrame,'% 05.f') '.mat']);
numFeatures = size(points_left,2);
storePoints_left = NaN(2,numFeatures,numImgs);
storePoints_right = NaN(2,numFeatures,numImgs);

% First frame
figure(1);
im_left = imread([folder_left '/' sDir_left(firstFrame).name]);
im_right = imread([folder_right '/' sDir_right(firstFrame).name]);
[height, width] = size(im_left);
imshow([im_left,im_right],[]); hold on;
% Plot features
figure(1);
plot(points_left(1,:),points_left(2,:),'yO')
plot(points_right(1,:)+width,points_right(2,:),'yO')
% Display feature numbers
for i = 1:numFeatures
    figure(1);
    text(points_left(1,i),points_left(2,i),num2str(i));
    text(points_right(1,i)+width,points_right(2,i),num2str(i));
end
% Store movie frame
if isunix
    Mov(1) = im2frame([im_left,im_right], gray(256));
else
    Mov(1) = im2frame(flipud([im_left,im_right]), gray(256));
end
% Store features
storePoints_left(:,:,firstFrame) = points_left;
storePoints_right(:,:,firstFrame) = points_right;

%% Initialise point trackers
% Create points objects
pObj_left = cornerPoints(points_left');
pObj_right = cornerPoints(points_right');

% Create a point tracker and enable the bidirectional error constraint to
% make it more robust in the presence of noise and clutter
pointTracker_left = vision.PointTracker('MaxBidirectionalError', inf);
pointTracker_right = vision.PointTracker('MaxBidirectionalError', inf);

% Initialize the tracker with the initial point locations and the initial
% video frame
pObj_left = pObj_left.Location;
pObj_right = pObj_right.Location;
initialize(pointTracker_left, pObj_left, im_left);
initialize(pointTracker_right, pObj_right, im_right);

%% Track points
disp('Tracking points...');
count = 1;

% Make a copy of the points to be used for computing the geometric
% transformation between the points in the previous and the current frames
oldPoints_left = pObj_left;
oldPoints_right = pObj_right;

for frame = (firstFrame+1):lastFrame
    count = count+1;
    % Get next frame
    newImg_left = imread([folder_left '/' sDir_left(frame).name]);
    newImg_right = imread([folder_right '/' sDir_right(frame).name]);

    % Track the points. Note that some points may be lost
    % Left image
    [pObj_left, isFound_left] = step(pointTracker_left, newImg_left);
    visiblePoints_left = pObj_left(isFound_left, :);
    oldInliers_left = oldPoints_left(isFound_left, :);
    
    % Right image
    [pObj_right, isFound_right] = step(pointTracker_right, newImg_right);
    visiblePoints_right = pObj_right(isFound_right, :);
    oldInliers_right = oldPoints_right(isFound_right, :);
    
    % Estimate the geometric transformation between the old points
    % and the new points and eliminate outliers
%     [xform_left, oldInliers_left, visiblePoints_left] = estimateGeometricTransform(...
%         oldInliers_left, visiblePoints_left, 'similarity', 'MaxDistance', 4);
%     [xform_right, oldInliers_right, visiblePoints_right] = estimateGeometricTransform(...
%             oldInliers_right, visiblePoints_right, 'similarity', 'MaxDistance', 4);
    
    % Display tracked points
    newImg_left = insertMarker(newImg_left, visiblePoints_left, '+', ...
            'Color', 'white');
    newImg_right = insertMarker(newImg_right, visiblePoints_right, '+', ...
            'Color', 'white');

    % Reset the points
    oldPoints_left = visiblePoints_left;
    oldPoints_right = visiblePoints_right;
    setPoints(pointTracker_left, oldPoints_left);
    setPoints(pointTracker_right, oldPoints_right);       
   
    % Store frame
    newImg = [newImg_left(:,:,1),newImg_right(:,:,1)];
    if isunix
        Mov(count) = im2frame(newImg, gray(256));
    else
        Mov(count) = im2frame(flipud(newImg), gray(256));
    end
       
    % Store points
    % If points are lost, break loop
    if size(visiblePoints_left,1)<numFeatures || size(visiblePoints_right,1)<numFeatures
        numImgs = frame-1;
        disp(['Points lost on frame ', num2str(frame),'! Please re-estimate points']);
        break;
    end
    storePoints_left(:,:,frame) = visiblePoints_left';
    storePoints_right(:,:,frame) = visiblePoints_right';
end
disp('Done!')

%% Play movie
figure; imshow([im_left,im_right]);
movie(Mov,1,120);

%% Re-estimate points in last frame
points_left = storePoints_left(:,:,frame);
points_right = storePoints_right(:,:,frame);
newPoints_left = ReEstimatePoints(newImg_left, points_left);
newPoints_right = ReEstimatePoints(newImg_right, points_right);
% Apply epipolar constraint
newPoints_left(2,:) = (newPoints_left(2,:) + newPoints_right(2,:))./2; % Set y-coordinate to average
newPoints_right(2,:) = newPoints_left(2,:);
figure;
imshow([newImg_left,newImg_right],[]); hold on;
plot(newPoints_left(1,:),newPoints_left(2,:),'rO'); hold on;
plot(newPoints_right(1,:)+width,newPoints_right(2,:),'rO'); hold on;

%% Save points
points_left = newPoints_left;
points_right = newPoints_right;
save(['points_left_' num2str(frame,'% 05.f') '.mat'], 'points_left');
save(['points_right_' num2str(frame,'% 05.f') '.mat'], 'points_right');

