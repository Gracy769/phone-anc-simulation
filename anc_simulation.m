% PHONE ANC SIMULATION -- MATLAB R2021b or newer; no toolboxes required.
% Run this script from its folder. Outputs are written to matlab_results/.
% Delays are hypothetical and must be measured before any phone app claim.
clear; close all; clc;
fs = 8000; duration = 4; seed = 7;
leadMs = 5; secondaryMs = 1; appLatenciesMs = [2, 20];
taps = 64; mu = 0.01;
out = fullfile(pwd, 'matlab_results');
if ~exist(out, 'dir'), mkdir(out); end
rng(seed);
N = fs * duration;
white = randn(N, 1);
colored = filter(0.17, [1 -0.83], white);
t = (0:N-1)' / fs;
x = 0.48 * sin(2*pi*120*t) + 0.70 * colored;
x = x / rootmean(x);
run1 = run_anc(x, fs, leadMs, secondaryMs, appLatenciesMs(1), taps, mu);
run2 = run_anc(x, fs, leadMs, secondaryMs, appLatenciesMs(2), taps, mu);
idx = floor(N/2)+1:N;
names = {sprintf('app_%gms', appLatenciesMs(1)); sprintf('app_%gms', appLatenciesMs(2))};
app_latency_ms = appLatenciesMs(:);
primary_lead_ms = repmat(leadMs, 2, 1);
secondary_delay_ms = repmat(secondaryMs, 2, 1);
noise_rms = [rootmean(run1.d(idx)); rootmean(run2.d(idx))];
residual_rms = [rootmean(run1.e(idx)); rootmean(run2.e(idx))];
reduction_db = 20*log10(noise_rms ./ residual_rms);
T = table(names, app_latency_ms, primary_lead_ms, secondary_delay_ms, ...
    noise_rms, residual_rms, reduction_db, 'VariableNames', ...
    {'scenario','app_latency_ms','primary_lead_ms','secondary_delay_ms', ...
    'noise_rms','residual_rms','reduction_db'});
writetable(T, fullfile(out, 'metrics.csv'));
disp(T);

% Signal-flow boxes.
fig = figure('Color','w','Position',[100 100 1150 370]);
ax = axes(fig); axis(ax,[0 12 0 3.5]); axis off; hold on;
box(ax, 0.1, 1.25, 'Ambient noise');
box(ax, 2.3, 2.25, 'Phone mic  x[n]');
box(ax, 4.8, 2.25, 'Phone app  FxLMS + delay');
box(ax, 8.0, 2.25, 'Earphone output');
box(ax, 2.3, 0.35, 'Acoustic primary path');
box(ax, 10.25, 1.25, 'Ear  e[n]');
arrow(ax, [1.3 2.15], [1.9 2.55]); arrow(ax, [3.6 4.55], [2.55 2.55]);
arrow(ax, [6.7 7.7], [2.55 2.55]); arrow(ax, [9.2 10.0], [2.55 1.65]);
arrow(ax, [1.3 2.1], [1.3 0.65]); arrow(ax, [4.2 10.0], [0.65 1.35]);
text(7,1.15,'At ear: residual = noise + antinoise','HorizontalAlignment','center','Color',[.6 .2 .25]);
title('Software ANC concept: both paths meet at the ear');
light_figure(fig);
exportgraphics(fig, fullfile(out,'01_signal_flow.png'),'Resolution',160);

% Waveform and adaptation plot.
fig = figure('Color','w','Position',[100 100 1050 680]);
start = 2*fs+1; span = round(0.06*fs); k = start:start+span-1;
subplot(2,1,1);
plot((0:span-1)/fs*1000, run1.d(k),'Color',[.2 .25 .32]); hold on;
plot((0:span-1)/fs*1000, run1.e(k),'Color',[.08 .43 .72]);
plot((0:span-1)/fs*1000, run2.e(k),'Color',[.78 .25 .25]);
grid on; xlabel('Time in selected window (ms)'); ylabel('Normalized acoustic pressure');
title('Waveform after adaptation: cancellation at ear');
legend('Without ANC','ANC: app 2 ms','ANC: app 20 ms');
subplot(2,1,2);
block = round(0.1*fs); blocks = floor(N/block); tb = ((1:blocks)-0.5)*block/fs;
plot(tb, blockrms(run1.d,block),'Color',[.2 .25 .32]); hold on;
plot(tb, blockrms(run1.e,block),'Color',[.08 .43 .72]);
plot(tb, blockrms(run2.e,block),'Color',[.78 .25 .25]);
grid on; xlabel('Simulation time (s)'); ylabel('RMS pressure, 0.1 s blocks');
title('Adaptation over time'); legend('Without ANC','ANC: app 2 ms','ANC: app 20 ms');
light_figure(fig);
exportgraphics(fig, fullfile(out,'02_waveform_and_learning.png'),'Resolution',160);

% Analytical timing-sensitivity curves for equal-amplitude single tone.
fig = figure('Color','w','Position',[100 100 900 470]);
f = linspace(20,1000,800); hold on;
errors = [.25 1 3];
for q = 1:numel(errors)
    residual = max(2*abs(sin(pi*f*errors(q)/1000)),1e-3);
    plot(f,-20*log10(residual),'LineWidth',1.5);
end
yline(0,'k-'); grid on; xlim([20 1000]); ylim([-10 32]);
xlabel('Noise frequency (Hz)'); ylabel('Idealized cancellation (dB)');
title('Sensitivity to phase/timing error for a single tone');
legend('0.25 ms error','1 ms error','3 ms error','Location','northeast');
text(35,-7,'Equal antinoise amplitude; illustrative analytical curve','FontSize',9);
light_figure(fig);
exportgraphics(fig, fullfile(out,'03_timing_sensitivity.png'),'Resolution',160);

% Animated wave interference at the ear, saved as a GIF.
fig = figure('Color','w','Position',[100 100 900 510]);
gifPath = fullfile(out,'04_anc_animation.gif');
width = round(0.05*fs); first = 2*fs+1;
for frame = 1:56
    i = first + (frame-1)*round(0.008*fs); k = i:i+width-1;
    clf(fig);
    annotation(fig,'textbox',[.04 .84 .2 .1],'String','Ambient noise', ...
        'EdgeColor',[.1 .4 .7],'BackgroundColor',[.9 .95 1],'HorizontalAlignment','center');
    annotation(fig,'textbox',[.29 .84 .2 .1],'String','Phone mic + app', ...
        'EdgeColor',[.1 .4 .7],'BackgroundColor',[.9 .95 1],'HorizontalAlignment','center');
    annotation(fig,'textbox',[.54 .84 .2 .1],'String','Earphone output', ...
        'EdgeColor',[.1 .4 .7],'BackgroundColor',[.9 .95 1],'HorizontalAlignment','center');
    annotation(fig,'textbox',[.79 .84 .17 .1],'String','Ear: sum', ...
        'EdgeColor',[.1 .4 .7],'BackgroundColor',[.9 .95 1],'HorizontalAlignment','center');
    ax = axes(fig,'Position',[.09 .16 .84 .58]); hold(ax,'on');
    tt = (0:width-1)/fs*1000;
    plot(ax,tt,run1.d(k),'Color',[.2 .25 .32],'LineWidth',1.3);
    plot(ax,tt,run1.y(k),'Color',[.85 .55 .12],'LineWidth',1.3);
    plot(ax,tt,run1.e(k),'Color',[.08 .43 .72],'LineWidth',1.3);
    xlim(ax,[0 50]); ylim(ax,[-2.8 2.8]); grid(ax,'on');
    xlabel(ax,'Time in moving window (ms)'); ylabel(ax,'Normalized pressure');
    title(ax,sprintf('Interference at ear | app latency 2 ms | t = %.2f s',i/fs));
    legend(ax,'Noise','Antinoise','Residual','Location','northeast');
    light_figure(fig);
    drawnow;
    img = frame2im(getframe(fig)); [indexed,map] = rgb2ind(img,256);
    if frame == 1
        imwrite(indexed,map,gifPath,'gif','LoopCount',inf,'DelayTime',0.09);
    else
        imwrite(indexed,map,gifPath,'gif','WriteMode','append','DelayTime',0.09);
    end
end
fprintf('Results saved to %s\n', out);

function r = run_anc(x,fs,leadMs,secondaryMs,appMs,taps,mu)
    N = numel(x); p = round(leadMs*fs/1000);
    s = round(secondaryMs*fs/1000); a = round(appMs*fs/1000); total = a+s;
    d = .85*shift(x,p) + .15*shift(x,p+3);
    xf = .92*shift(x,total) + .08*shift(x,total+2);
    xp = [zeros(taps-1,1);x]; xfp = [zeros(taps-1,1);xf];
    u = zeros(N,1); y = zeros(N,1); e = zeros(N,1); w = zeros(taps,1);
    for n = 1:N
        xv = flipud(xp(n:n+taps-1)); fv = flipud(xfp(n:n+taps-1));
        u(n) = -w'*xv;
        if n>total, y(n) = .92*u(n-total); end
        if n>total+2, y(n) = y(n)+.08*u(n-total-2); end
        e(n) = d(n)+y(n);
        w = w + mu*e(n)/(fv'*fv+.05)*fv;
        w = min(max(w,-2),2);
    end
    r = struct('d',d,'u',u,'y',y,'e',e);
end
function y = shift(x,n)
    y = [zeros(n,1);x(1:end-n)];
end
function z = rootmean(x)
    z = sqrt(mean(x.^2));
end
function r = blockrms(x,n)
    b = floor(numel(x)/n);
    r = sqrt(mean(reshape(x(1:b*n),n,b).^2,1));
end
function box(ax,x,y,label)
    text(ax,x,y,label,'BackgroundColor',[.9 .95 1],'EdgeColor',[.1 .4 .7], ...
        'Margin',9,'HorizontalAlignment','center','FontSize',9);
end
function arrow(ax,x,y)
    quiver(ax,x(1),y(1),diff(x),diff(y),0,'Color',[.15 .22 .32], ...
        'LineWidth',1.4,'MaxHeadSize',.2);
end
function light_figure(fig)
    set(fig,'Color','w');
    ax = findall(fig,'Type','axes');
    set(ax,'Color','w','XColor','k','YColor','k');
    tx = findall(fig,'Type','text');
    set(tx,'Color','k');
    lg = findall(fig,'Type','legend');
    if ~isempty(lg), set(lg,'Color','w','TextColor','k'); end
    tb = findall(fig,'Type','textboxshape');
    if ~isempty(tb), set(tb,'Color','k'); end
end
