delete(timerfindall)
clear all;
close all hidden;
clc;

%% Guidance

global debug_mode path_points path_orientation map_information file_path occupancy_matrix fixed_sample_rate max_velocity 
global energy_budget map_velocity duration_people orientation_people initialPoint_people time_people

debug_mode = false;
create_map

[sampled_path, checkpoints] = path_planning(path_points, path_orientation);
max_velocity = map_velocity/3.6; %m/s

%% Control and Navigation

% Timer initialize
global start_v err_w count_w countstop countgo people_walk

start_v = 0;err_w = 0;count_w = 0;countstop = 0;countgo = 0;

% Testar e depois apagar!!!!!!
duration_people = [10 5];
orientation_people = [pi pi];

initialPoint_people = [470 470 ;1080 1100];
Number_of_people =length(orientation_people);
for npeople =1:Number_of_people
    people_walk{npeople} = people_path(npeople);
end


%%

my_timer = timer('Name', 'my_timer', 'ExecutionMode', 'fixedRate', 'Period', 0.01, ...
                    'StartFcn', @(x,y)disp('started...'), ...
                    'StopFcn', @(x,y)disp('stopped...'), ...
                    'TimerFcn', @my_start_fcn);
% Path from guidance
Rini = wrapToPi(deg2rad(path_orientation));

xt = sampled_path(:,1)*map_information.meters_from_MAP;
yt = sampled_path(:,2)*map_information.meters_from_MAP;
thetat = theta_generator(xt,yt);
thetat(1) = -Rini(1); thetat(end) = -Rini(2);
valid = 0; thderror = 1;
while ~valid && thderror <= 4
    [b_stp, min_dist, valid] = FindStep(xt, yt, thetat, thderror);
    thderror = thderror*2;
end
% b_stp = 0.015;
t_pred = It_Prediction(length(xt));
%% Initialization

% Initialize timer
start(my_timer);
stp = b_stp;%0.1;%06; % 0.013 para ist e 0.084 para corrida
end_stop = -1;

% Initialize Car Exact Position and Old GPS position
x = xt(1);y = yt(1);theta = thetat(1);
x_old = x;y_old = y;theta_old = theta;

% Initialize Pos. estimate 
x_new = x;y_new = y;theta_new = theta;

% Initialize odometry
x_odom = x;y_odom = y;

% Initialize Iterations Counter
t = 0; counter_nav = 0; counter_col = 0; countcol = 0;
fin = 0;

% Initialize Exact Velocity
v = 1;
v_old = v; vel_max = map_velocity;

% Initialize Wheel orientation and angular speed
phi = 0;
w_phi = 0;

% Odometry deviation
error = 0.005;

% Path counter
wait_time = 1;

% colisions
colision = 0;

% Initialize Estimate Covariance of the EKF

P = [0.01^2 0 0 ; 0 0.01^2 0 ;0 0 (0.01*0.1)^2];
E = energy_budget;
P0 = 1000;
Energy_wasted = 0;
flag_energy = 0;
wet = false;

% Sensor variables
load 'Initialize_Sensors.mat';
load 'Initialize_Sensors_flags.mat';

% Create lidar
[x_lidar,y_lidar]= lidar;
% Create camera
[x_camera,y_camera]= camera;
count = 1;
count1 = 1;
count2=1;

x_people1 = people1(1,:);y_people1=people1(2,:);
x_people2 = people2(1,:);y_people2=people2(2,:);
object_x_old = -1;
object_y_old = -1;

old_value = -1;

% GPS Breakups

% Vector of points for GPS Break Ups - They can Be Random and in specific
% areas - FALTA METER A FUNCIONAR COM OQ UE VEM DO .mat
GPS_Breakups = [];
conglomerate_breakups = 1;
    
%% Run the Autonomous Car Program

h1 = openfig(string(file_path+"MAP.fig"));
ax1 = gca;
fig1 = get(ax1,'children'); %get handle to all the children in the figure
fig2 = get(ax1,'children');

fig = figure("Name","Real Time Simulation",'numbertitle', 'off');
clf;
fig.Position(1) = fig.Position(1)-(fig.Position(3))/2;
fig.Position(3) = 1.7*fig.Position(3);

s1=subplot(2,3,[1,2,4,5]);
copyobj(fig1,s1);
set(gca, 'YDir','reverse')
hold on
box on
axis off
axis equal
title("Circuit");
plot(sampled_path(:,1),sampled_path(:,2),"y--");

s2=subplot(2,3,3);
copyobj(fig2,s2);
set(gca, 'YDir','reverse')
hold on
box on
axis off
axis equal
title("Interest Area");
plot(sampled_path(:,1),sampled_path(:,2),"y--");

s3=subplot(2,3,6);
hold on
title("Spedometer");

close(h1)

wt = waitbar(1,"Energy...");
set(wt,'Name','Energy Variation In Percentage');
 % find the patch object
hPatch = findobj(wt,'Type','Patch');
 % change the edge and face to blue
set(hPatch,'FaceColor','b', 'EdgeColor','w')
tic
while ~fin
    Flag_GPS_Breakup = 0;
    if start_v == 1
        % Measure the distance to tranjectory
        [point, distance, thetap, wait_time] = dist_to_traj(x_new, y_new, xt, yt, thetat, v, stp, wait_time);
        dist_to_p(t+1) = distance;
        if distance > 1
            debug = 1
            %break;
        end
        
        if t == 145
            pause_please = 1;
        end
        
        % alteraÃ§Ã£o com a branco e a r
        if flag_Inerent_collision
%             if counter_col == 0
%                 turn_now = true;
%             else
%                 turn_now = false;
%             end
%             counter_col = counter_col + 1;
%             if counter_col == 10
%                 counter_col = 0;
%             end
            disp("Colisão inerente: mudar direção")
%         else
%             turn_now = false;
%             counter_col = 0;
        end
        if length(xt) - wait_time < 2/fixed_sample_rate
            end_stop = length(xt)-wait_time;
        end
        
        if flag_energy || flag_red_ligth || flag_stopSignal %|| flag_Inerent_collision
            stopt = true;
        else
            stopt = false;
        end
        if flag_red_ligth && count==1
            [icondata,iconcmap] = imread(string(file_path+"sem.jpg")); 
            h=msgbox('Red Light detected',...
         'Camera','custom',icondata,iconcmap);
            count=0;
        elseif flag_passadeira && count==1
            [icondata,iconcmap] = imread(string(file_path+"passa.jpeg")); 
            h=msgbox('Crosswalk detected',...
            'Camera','custom',icondata,iconcmap);
            count=0;
        elseif flag_stopSignal && count ==1
            [icondata,iconcmap] = imread(string(file_path+"stop.jpg")); 
            h=msgbox('Stop Signal detected',...
            'Camera','custom',icondata,iconcmap);
            count=0;
        end
        if flag_Person && count2==1
            if exist('h','var')
                delete(h)
            end
            [icondata,iconcmap] = imread(string(file_path+"person.png")); 
            h=msgbox('Person detected',...
            'Camera','custom',icondata,iconcmap);
            count2=0;
        elseif flag_Person==0 &&count2==0
            delete(h)
            count=1;
            count2=1;
        end
        

%         vel_max = 5.6;
        % Controller of the Car
        theta_safe = TrackPredict(thetat, fixed_sample_rate, wait_time);
        [w_phi, v] = simple_controler_with_v(point(1)-x_new, point(2)-y_new,...
            wrapToPi(theta_new), phi, v,...
            difference_from_theta(wrapToPi(thetap),wrapToPi(theta_new)),...
            theta_safe, vel_max, wet, stopt, flag_passadeira||flag_Inerent_collision, flag_Person, end_stop);
        v_aux = v;

        % Car simulator
        [x,y,theta,phi] = robot_simulation(x, y, theta, v, phi, w_phi);
        [stopE, E] = Energy_decreasing(v, v_old, P0, E);

        x_aux = x;
        y_aux = y;
        theta_aux = theta;
        x_odom_old = x_odom;
        y_odom_old = y_odom;
        x_odom = x_odom+error*sin(theta)+(x-x_old);
        y_odom = y_odom+error*cos(theta)+(y-y_old);
        theta_odom = theta;
        
        if randsample( [0 1], 1, true, [0.999 0.001] ) || occupancy_matrix(round(y/map_information.meters_from_MAP)+1,round(x/map_information.meters_from_MAP)+1) == 6
            GPS_Breakups = [GPS_Breakups; t];
            if conglomerate_breakups
                GPS_Breakups = [GPS_Breakups; (repmat(t,10,1) + (1:1:10)')];
                conglomerate_breakups = 0;
            end   
        end
        
        
        
        
        if v ~= 0
            counter_nav = counter_nav + 1;
            [P,x_new,y_new,theta_new,flag_energy,vel_max] ...
                = navigation(x,y,theta,x_old,y_old,...
                P,E,t_pred, counter_nav, x_new, y_new, theta_new,any(GPS_Breakups(:) == t),...
                x_odom_old, y_odom_old, x_odom, y_odom);
        end
        % Past GPS position
        x_old = x_aux;
        y_old = y_aux;
        theta_old = theta_aux;
        v_old = v_aux;
        % Save current GPS Position
        xp(t+1) = x;
        yp(t+1) = y;
        % save Estimation of Car Position
        thetapt(t+1) = theta;
        xnewp(t+1) = x_new;
        ynewp(t+1) = y_new;
%         thetanewp(t+1) = theta_new;
        phip(t+1) = phi;
        t = t + 1;
        
        % Lidar Sensors
%         
[flag_object_ahead,flag_stop_car,flag_Inerent_collision,flag_passadeira,flag_Person,flag_red_ligth,...
            flag_stopSignal,count1,old_value,path1_not_implemented,path2_not_implemented,x_people1,y_people1,x_people2 ,y_people2 ]= sensors(x,y,theta,dim,x_lidar,y_lidar,x_camera, ...
            y_camera,path2_not_implemented,path1_not_implemented,flag_Person,flag_red_ligth,...
            people1,people2,count1,cantos_0,v,flag_stopSignal,...
            flag_Inerent_collision,old_value,x_people1,y_people1,x_people2 ,y_people2 );

        
        error_odom(1,t) = x_odom;
        error_odom(2,t) = y_odom;
        %error_odom(3,t) = theta_odom;
        if ~flag_stop_car && exist('crsh','var')
            delete(crsh);
            countcol = 0;
        end
        if flag_stop_car && countcol == 0
%             disp('Car crash - Stopping the program');
            [icondata,iconcmap] = imread(string(file_path+"crash.jpg")); 
            crsh=msgbox('Car crash',...
         'There was a crash','custom',icondata,iconcmap);
            countcol = 1;
            colision = colision + 1;
        elseif flag_stop_car && countcol < 10
            countcol = countcol + 1;
        end
%         if flag_Inerent_collision && v == 0 && ~flag_Person
%             disp('Car is unable to follow this path');
%             break;
%         end
        if vel_max < 1
            disp('Energy budget too low');
        end
        start_v = 0;
        if( norm([x-xt(end),y-yt(end)]) < 0.5)
            fin = 1;
        end
    end    
    
    subplot(s1)
    if(t>1); delete(plt1); end
    plt1 = place_car([x/map_information.meters_from_MAP,y/map_information.meters_from_MAP],100,theta,phi,map_information.meters_from_MAP);
    
    
    subplot(s2)
    if(t>1); delete(plt2); end
    plt2 = place_car([x/map_information.meters_from_MAP,y/map_information.meters_from_MAP],100,theta,phi,map_information.meters_from_MAP);
    gap = 5;
    xlim([x-gap, x+gap]/map_information.meters_from_MAP)
    ylim([y-gap, y+gap]/map_information.meters_from_MAP)
    
    subplot(s3)
    halfGuageDisplay(v/max_velocity);
    
    pause(0.001);
    waitbar(E/energy_budget,wt,sprintf("Energy... %f.2", (E/energy_budget)*100));
    
    if exist('h','var') && (flag_red_ligth==0 && flag_passadeira==0 && flag_stopSignal==0 && flag_Person==0)
        delete(h);
        count=1;
        count2=1;
    end
end
toc

%% Close Energy Display

close(wt);

%% For the Plot of GPS_Breakups

X_breakups = xnewp(GPS_Breakups(:));
Y_breakups = ynewp(GPS_Breakups(:));


%% Timer Stoppage

stop(my_timer);
delete(timerfindall)
clear my_timer       


%% 
figure('WindowStyle', 'docked');
plot(xp,yp,'b'); hold on;
plot(xt,yt,'y'); axis equal;
plot(error_odom(1,:),error_odom(2,:),'r');
plot(xnewp,ynewp,'g');
plot(X_breakups,Y_breakups,'x','MarkerSize',12);
place_car([xp',yp'],1,thetapt,phip,map_information.meters_from_MAP);
title('Car Path','FontSize',14,'FontName','Arial');
ylabel('y (m)','FontSize',12,'FontName','Arial');
xlabel('x (m)','FontSize',12,'FontName','Arial');
legend('Actual Car Path','Car Initial Path','Odometry','Position Prediction','GPS BreakUp Points');
legend show;

% Error Plot
figure('WindowStyle', 'docked');
plot(dist_to_p);
title('Error of Path','FontSize',14,'FontName','Arial');
ylabel('Error','FontSize',12,'FontName','Arial');
xlabel('iterations','FontSize',12,'FontName','Arial');

%%
% MAP_control = openfig(string(file_path+"MAP.fig"));
% MAP_control.Name = 'control';
% hold on
% place_car([xp',yp']/map_information.meters_from_MAP,3,thetapt,phip,map_information.meters_from_MAP);
% plot(sampled_path(:,1),sampled_path(:,2),"y--");


%%
disp("Finito")
license('inuse')
[fList,pList] = matlab.codetools.requiredFilesAndProducts('path_planning.m');
%%
function my_start_fcn(obj, event)
    global start_v
    start_v = 1;
end
