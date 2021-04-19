close all;
clear;
clc;

%% get window dimensions
f1=figure(1);
pos_normal = f1.Position(3:4);
f1.WindowState = 'maximized';
pause(0.5); % waiting for the window to expand
pos_fullscreen = f1.Position(3:4);
close 1

%% display images
MAP = figure('Name','MAP','NumberTitle','off');
pbaspect([1 1 1]);
I = imread('../Maps images/IST_campus.png');
imshow(I);
MAP.Children.Position = [0 0 1 1];
MAP.MenuBar = 'none';
MAP.ToolBar = 'none';
len = pos_normal(1) + pos_fullscreen(2)-pos_normal(2);
MAP.InnerPosition(3:4) = [len len];

%% get references
clc
point_not_valid = true;
disp("Draw the first location point, and type the coordinates.");
while(point_not_valid)
    h1 = drawcrosshair;
    lat1 = input("Latitude:")
    long1 = input("Longitude:")
    
    input("If you want to draw it again, press 'n'.");
end

% p1 = input(prompt);
disp("Draw the first location point, and type the coordinates:");
% input(prompt);


%h = drawpolyline('Color','green');

% h2 = drawpoint