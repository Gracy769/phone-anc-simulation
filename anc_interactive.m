function fig = anc_interactive(mode)
% ANC_INTERACTIVE  Live, single-tone phone ANC timing demonstration.
% Run: anc_interactive
% Optional: f = anc_interactive('smoke'); exportapp(f,'preview.png');
%
% Drag any slider. Waveforms, frequency-response curve, and reduction in dB
% update immediately. All delays are assumptions, not phone measurements.
% Core MATLAB only; tested with MATLAB R2025b.

if nargin < 1, mode = ''; end
sampleCount = 800;
earphoneMs = 1.0;
state.frequencyHz = 120;
state.appMs = 4;
state.leadMs = 5;
state.gain = 1;

fig = uifigure('Name','Interactive phone ANC simulation', ...
    'Position',[100 80 1240 780],'Color',[0.96 0.97 0.99]);
fig.CloseRequestFcn = @(src,~) delete(src);

header = uilabel(fig,'Position',[30 738 1170 28], ...
    'Text','PHONE ANC | Interactive timing and phase simulation', ...
    'FontSize',20,'FontWeight','bold','FontColor',[0.10 0.18 0.30]);
subtitle = uilabel(fig,'Position',[31 711 1170 20], ...
    'Text','Phone mic reference → app delay → earphone → antinoise at ear  |  Single steady tone', ...
    'FontSize',12,'FontColor',[0.30 0.37 0.46]);

controls = uipanel(fig,'Title','Change assumptions live','Position',[25 170 330 515], ...
    'BackgroundColor',[1 1 1],'ForegroundColor',[0.10 0.18 0.30], ...
    'FontWeight','bold');
frequencyLabel = controlLabel(controls,445,'Noise frequency: 120 Hz');
frequencySlider = slider(controls,408,[40 1000],120,[40 120 500 1000], ...
    @(v) change('frequencyHz',v));
latencyLabel = controlLabel(controls,353,'App input-to-output delay: 4.0 ms');
latencySlider = slider(controls,316,[0 30],4,[0 4 10 20 30], ...
    @(v) change('appMs',v));
leadLabel = controlLabel(controls,261,'Mic lead before noise reaches ear: 5.0 ms');
leadSlider = slider(controls,224,[0 10],5,[0 2 5 10], ...
    @(v) change('leadMs',v));
gainLabel = controlLabel(controls,169,'Antinoise amplitude: 1.00 × noise');
gainSlider = slider(controls,132,[0 1.5],1,[0 0.5 1 1.5], ...
    @(v) change('gain',v));
uilabel(controls,'Position',[16 38 300 65], ...
    'Text',sprintf('Fixed earphone path: %.1f ms\n\nIdealized model; audio is not played.',earphoneMs), ...
    'FontSize',11,'FontColor',[0.36 0.42 0.48]);

waveAx = uiaxes(fig,'Position',[385 375 825 305]);
waveAx.Color = [1 1 1]; waveAx.XColor = [.15 .20 .27]; waveAx.YColor = [.15 .20 .27];
waveAx.FontSize = 11; waveAx.Box = 'on'; grid(waveAx,'on'); hold(waveAx,'on');
ttMs = linspace(0,40,sampleCount);
noiseLine = plot(waveAx,ttMs,zeros(size(ttMs)),'LineWidth',1.8, ...
    'Color',[.18 .24 .33],'DisplayName','Noise at ear');
antiLine = plot(waveAx,ttMs,zeros(size(ttMs)),'LineWidth',1.8, ...
    'Color',[.94 .55 .10],'DisplayName','Antinoise at ear');
residualLine = plot(waveAx,ttMs,zeros(size(ttMs)),'LineWidth',2.0, ...
    'Color',[.08 .43 .75],'DisplayName','Residual at ear');
xlim(waveAx,[0 40]); ylim(waveAx,[-2.6 2.6]);
xlabel(waveAx,'Time (ms)'); ylabel(waveAx,'Normalized acoustic pressure');
title(waveAx,'Wave interference at the ear','Color',[.10 .18 .30]);
waveLegend = legend(waveAx,'Location','northeast');
waveLegend.Color = [1 1 1];
waveLegend.TextColor = [.1 .1 .1];

responseAx = uiaxes(fig,'Position',[385 70 825 270]);
responseAx.Color = [1 1 1]; responseAx.XColor = [.15 .20 .27];
responseAx.YColor = [.15 .20 .27]; responseAx.FontSize = 11;
responseAx.Box = 'on'; grid(responseAx,'on'); hold(responseAx,'on');
freqAxis = linspace(20,1200,700);
responseLine = plot(responseAx,freqAxis,zeros(size(freqAxis)), ...
    'LineWidth',2,'Color',[.08 .43 .75]);
frequencyMarker = plot(responseAx,120,0,'o','MarkerSize',9, ...
    'MarkerFaceColor',[.85 .20 .20],'MarkerEdgeColor','w');
yline(responseAx,0,'--','Color',[.5 .5 .5]);
xlim(responseAx,[20 1200]); ylim(responseAx,[-10 42]);
xlabel(responseAx,'Noise frequency (Hz)'); ylabel(responseAx,'Reduction (dB)');
title(responseAx,'Predicted cancellation versus frequency','Color',[.10 .18 .30]);

resultBox = uipanel(fig,'Position',[25 23 330 130], ...
    'BackgroundColor',[.90 .95 1.00],'ForegroundColor',[.1 .25 .40]);
resultLabel = uilabel(resultBox,'Position',[15 73 300 40], ...
    'Text','','FontSize',20,'FontWeight','bold','FontColor',[.05 .35 .60]);
timingLabel = uilabel(resultBox,'Position',[15 40 300 28], ...
    'Text','','FontSize',11,'FontColor',[.20 .30 .40]);
statusLabel = uilabel(resultBox,'Position',[15 10 300 32], ...
    'Text','','FontSize',10,'FontColor',[.55 .22 .20], ...
    'WordWrap','on');

render();
if strcmp(mode,'smoke')
    % Automated UI smoke check: move a slider through its callback.
    latencySlider.Value = 8;
    change('appMs',8);
    latencySlider.Value = 4;
    change('appMs',4);
    drawnow;
end

    function change(field,value)
        state.(field) = value;
        render();
    end

    function render()
        frequencyLabel.Text = sprintf('Noise frequency: %.0f Hz',state.frequencyHz);
        latencyLabel.Text = sprintf('App input-to-output delay: %.1f ms',state.appMs);
        leadLabel.Text = sprintf('Mic lead before noise reaches ear: %.1f ms',state.leadMs);
        gainLabel.Text = sprintf('Antinoise amplitude: %.2f × noise',state.gain);

        % Relative arrival mismatch at ear. Positive means antinoise is late.
        mismatchMs = state.appMs + earphoneMs - state.leadMs;
        phase = 2*pi*state.frequencyHz*mismatchMs/1000;
        noise = sin(2*pi*state.frequencyHz*ttMs/1000);
        antinoise = -state.gain*sin(2*pi*state.frequencyHz*ttMs/1000-phase);
        residual = noise + antinoise;
        noiseLine.YData = noise;
        antiLine.YData = antinoise;
        residualLine.YData = residual;

        ratio = sqrt(max(1 + state.gain^2 - 2*state.gain*cos(phase),1e-12));
        db = -20*log10(ratio);
        if db > 60
            resultLabel.Text = 'Reduction: ≥60 dB (ideal)';
        else
            resultLabel.Text = sprintf('Reduction: %.1f dB',db);
        end
        timingLabel.Text = sprintf('Ear arrival mismatch: %+.1f ms',mismatchMs);
        if mismatchMs > 0
            statusLabel.Text = 'Antinoise arrives late; broadband cancellation is not causal in this geometry.';
        elseif mismatchMs < 0
            statusLabel.Text = 'Antinoise has an arrival-time lead; timing still needs accurate phase control.';
        else
            statusLabel.Text = 'Arrival times match in this idealized setup.';
        end

        phi = 2*pi*freqAxis*mismatchMs/1000;
        ratioCurve = sqrt(max(1 + state.gain^2 - 2*state.gain*cos(phi),1e-12));
        dbCurve = max(-10,min(42,-20*log10(ratioCurve)));
        responseLine.YData = dbCurve;
        frequencyMarker.XData = state.frequencyHz;
        frequencyMarker.YData = max(-10,min(42,db));
        drawnow limitrate;
    end
end

function label = controlLabel(parent,y,caption)
label = uilabel(parent,'Position',[16 y 300 30], ...
    'Text',caption,'FontSize',12,'FontWeight','bold', ...
    'FontColor',[.12 .23 .36]);
end

function control = slider(parent,y,limits,value,ticks,handler)
control = uislider(parent,'Position',[22 y 280 3], ...
    'Limits',limits,'Value',value,'MajorTicks',ticks);
control.ValueChangingFcn = @(~,event) handler(event.Value);
control.ValueChangedFcn = @(src,~) handler(src.Value);
end
