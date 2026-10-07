%% =========================================================
% EMG Analysis
%
% 適用本次 EMG 實驗匯出的 CSV：
%
% Time, Raw_wave, Rect_wave
%
% 本程式實際分析流程：
%
% 1. 一次選擇多個 CSV
% 2. 自動依檔名排序
% 3. 由 Time 自動計算 sampling rate
% 4. 讀取 Raw_wave
% 5. 去除 DC offset
% 6. 全波整流
% 7. 150 ms moving-average envelope
% 8. 計算：
%       - 整流後平均振幅
%       - 最大振幅
%       - Peak-to-Peak
%       - RMS
%       - 相對靜止狀態倍數
% 9. 輕度握拳 / 用力握拳：
%       可人工選擇三個實際握拳區段
% 10. 持續收縮：
%       每 5 秒分析一次
% 11. 比較前 5 秒與末 5 秒
% 12. 匯出 Summary 與 Fatigue Table
%
%
% 注意：
%
% 儀器雖已輸出 Rect_wave，
% 但依實驗手冊流程：
%
% Raw -> 去 DC -> Rectification
%
% 因此本程式使用 Raw_wave 自行重新處理。
%
%% =========================================================

clear;
clc;
close all;


%% =========================================================
% 1. 使用者設定
%% =========================================================

% Envelope window
% 手冊建議 100 ~ 200 ms
% 本程式使用中間值 150 ms
envelopeWindow_ms = 150;


% ---------------------------------------------------------
% 實驗檔案順序
%
% 如果你當天錄製順序不同，
% 只要修改下面名稱即可。
%
% 目前依你提供的資料推測：
%
% 01 = MVC
% 02 = 靜止
% 03 = 輕度握拳
% 04 = 用力握拳
% 05 = 持續收縮
% 06 = 自訂動作
% ---------------------------------------------------------

testNames = { ...
    'MVC'; ...
    '靜止狀態'; ...
    '輕度握拳'; ...
    '用力握拳'; ...
    '持續收縮'; ...
    '自訂動作'};


% 是否人工選擇
% 輕度握拳 / 用力握拳的三個實際收縮區段
%
% true  = 建議，用滑鼠選
% false = 直接使用整份檔案平均
useManualGripSegments = true;


%% =========================================================
% 2. 選擇所有 EMG CSV
%% =========================================================

[fileNames, filePath] = uigetfile( ...
    '*.csv', ...
    '選擇同一位受試者的所有 EMG CSV', ...
    'MultiSelect','on');


if isequal(fileNames,0)

    disp('沒有選擇檔案');
    return;

end


% 若只選一個檔案
if ischar(fileNames)

    fileNames = {fileNames};

end


% ---------------------------------------------------------
% 依照檔名排序
%
% 讓：
%
% _01
% _02
% _03
%
% 維持正確順序
% ---------------------------------------------------------

fileNames = sort(fileNames);

nFiles = length(fileNames);


fprintf('\n');
fprintf('============================================\n');
fprintf('EMG Analysis\n');
fprintf('共選取 %d 個檔案\n',nFiles);
fprintf('============================================\n');


%% =========================================================
% 3. 建立結果儲存空間
%% =========================================================

Result_File = strings(nFiles,1);

Result_Test = strings(nFiles,1);

Result_fs = nan(nFiles,1);

Result_Duration = nan(nFiles,1);

Result_DC = nan(nFiles,1);

Result_MeanRectified = nan(nFiles,1);

Result_MaxAmplitude = nan(nFiles,1);

Result_PeakToPeak = nan(nFiles,1);

Result_RMS = nan(nFiles,1);

Result_RelativeRest = nan(nFiles,1);


% 儲存每個檔案的資料
AllTime = cell(nFiles,1);

AllRaw = cell(nFiles,1);

AllDC = cell(nFiles,1);

AllRect = cell(nFiles,1);

AllEnvelope = cell(nFiles,1);


%% =========================================================
% 4. 逐一讀取並處理 CSV
%% =========================================================

for k = 1:nFiles

    fileName = fileNames{k};

    fullName = ...
        fullfile(filePath,fileName);


    fprintf('\n');
    fprintf('============================================\n');
    fprintf('分析檔案：%s\n',fileName);

    if k <= length(testNames)

        fprintf('測試項目：%s\n',testNames{k});

    end

    fprintf('============================================\n');


    %% -----------------------------------------------------
    % 4.1 讀取 CSV
    %% -----------------------------------------------------

    T = readtable( ...
        fullName, ...
        'VariableNamingRule','preserve');


    %% -----------------------------------------------------
    % 4.2 確認欄位
    %% -----------------------------------------------------

    requiredColumns = { ...
        'Time', ...
        'Raw_wave', ...
        'Rect_wave'};


    if ~all(ismember( ...
            requiredColumns, ...
            T.Properties.VariableNames))

        warning( ...
            '檔案格式不符合預期：%s', ...
            fileName);

        continue;

    end


    %% -----------------------------------------------------
    % 4.3 讀取資料
    %% -----------------------------------------------------

    t = T.Time(:);

    Raw = T.Raw_wave(:);

    RectFromMachine = T.Rect_wave(:);


    %% -----------------------------------------------------
    % 4.4 移除 NaN
    %% -----------------------------------------------------

    valid = ...
        isfinite(t) & ...
        isfinite(Raw);


    t = t(valid);

    Raw = Raw(valid);

    RectFromMachine = ...
        RectFromMachine(valid);


    %% =====================================================
    % 5. Sampling Rate
    %% =====================================================

    dt = ...
        median(diff(t));


    fs = ...
        1 / dt;


    duration = ...
        t(end)-t(1);


    fprintf( ...
        'Sampling Rate = %.2f Hz\n', ...
        fs);

    fprintf( ...
        'Duration      = %.2f s\n', ...
        duration);

    fprintf( ...
        'Samples       = %d\n', ...
        length(t));


    %% =====================================================
    % 6. DC Offset Removal
    %
    % 手冊：
    % 去除直流偏移
    %
    % EMG_DC = Raw - mean(Raw)
    %% =====================================================

    DCoffset = ...
        mean(Raw);


    EMG_DC = ...
        Raw - DCoffset;


    %% =====================================================
    % 7. Full-wave Rectification
    %% =====================================================

    EMG_Rectified = ...
        abs(EMG_DC);


    %% =====================================================
    % 8. Envelope
    %
    % 150 ms Moving Average
    %% =====================================================

    windowSamples = ...
        round( ...
        envelopeWindow_ms/1000 * fs);


    windowSamples = ...
        max(windowSamples,1);


    EMG_Envelope = ...
        movmean( ...
        EMG_Rectified, ...
        windowSamples);


    %% =====================================================
    % 9. 基本指標
    %% =====================================================

    MeanRectified = ...
        mean(EMG_Rectified);


    MaxAmplitude = ...
        max(EMG_Rectified);


    PeakToPeak = ...
        max(EMG_DC) - ...
        min(EMG_DC);


    RMSvalue = ...
        sqrt( ...
        mean(EMG_DC.^2));


    fprintf('\n');

    fprintf( ...
        'DC Offset = %.6f\n', ...
        DCoffset);

    fprintf( ...
        '整流後平均振幅 = %.6f\n', ...
        MeanRectified);

    fprintf( ...
        '最大振幅 = %.6f\n', ...
        MaxAmplitude);

    fprintf( ...
        'Peak-to-Peak = %.6f\n', ...
        PeakToPeak);

    fprintf( ...
        'RMS = %.6f\n', ...
        RMSvalue);


    %% =====================================================
    % 10. 儲存資料
    %% =====================================================

    Result_File(k) = ...
        string(fileName);


    if k <= length(testNames)

        Result_Test(k) = ...
            string(testNames{k});

    else

        Result_Test(k) = ...
            "Unknown";

    end


    Result_fs(k) = ...
        fs;

    Result_Duration(k) = ...
        duration;

    Result_DC(k) = ...
        DCoffset;

    Result_MeanRectified(k) = ...
        MeanRectified;

    Result_MaxAmplitude(k) = ...
        MaxAmplitude;

    Result_PeakToPeak(k) = ...
        PeakToPeak;

    Result_RMS(k) = ...
        RMSvalue;


    AllTime{k} = ...
        t;

    AllRaw{k} = ...
        Raw;

    AllDC{k} = ...
        EMG_DC;

    AllRect{k} = ...
        EMG_Rectified;

    AllEnvelope{k} = ...
        EMG_Envelope;


    %% =====================================================
    % 11. 每個檔案波形
    %% =====================================================

    figure( ...
        'Name', ...
        sprintf('%s - %s', ...
        fileName, ...
        Result_Test(k)), ...
        'NumberTitle','off');


    % -----------------------------------------------------
    % Raw
    % -----------------------------------------------------

    subplot(3,1,1);

    plot(t,Raw);

    xlabel('Time (s)');

    ylabel('EMG (mV)');

    title(sprintf( ...
        '%s - Raw EMG', ...
        Result_Test(k)));

    grid on;


    % -----------------------------------------------------
    % Rectified
    % -----------------------------------------------------

    subplot(3,1,2);

    plot( ...
        t, ...
        EMG_Rectified);

    xlabel('Time (s)');

    ylabel('|EMG| (mV)');

    title('Full-wave Rectified EMG');

    grid on;


    % -----------------------------------------------------
    % Envelope
    % -----------------------------------------------------

    subplot(3,1,3);

    plot( ...
        t, ...
        EMG_Envelope);

    xlabel('Time (s)');

    ylabel('Envelope (mV)');

    title(sprintf( ...
        'EMG Envelope (%d ms Moving Average)', ...
        envelopeWindow_ms));

    grid on;

end


%% =========================================================
% 12. 人工選擇握拳區段
%
% 輕度握拳 = 第 3 個檔案
% 用力握拳 = 第 4 個檔案
%
% 每個動作：
%
% 輕握 5 秒
% 放鬆 5 秒
%
% 共 3 次
%
% 所以選擇三段真正「握拳」的區域
%% =========================================================

if useManualGripSegments

    gripFiles = [3 4];


    for g = 1:length(gripFiles)

        k = gripFiles(g);


        if k > nFiles

            continue;

        end


        t = ...
            AllTime{k};

        EMG_Rectified = ...
            AllRect{k};

        EMG_Envelope = ...
            AllEnvelope{k};


        figure( ...
            'Name', ...
            ['選擇 ',char(Result_Test(k))], ...
            'NumberTitle','off');


        plot( ...
            t, ...
            EMG_Envelope);

        xlabel('Time (s)');

        ylabel('Envelope (mV)');

        title({ ...
            char(Result_Test(k)), ...
            '請依序點選 3 個握拳區段的「開始、結束」', ...
            '總共點 6 個點'});

        grid on;

        hold on;


        %% -------------------------------------------------
        % 使用者點 6 個點
        %% -------------------------------------------------

        [x,~] = ...
            ginput(6);


        x = sort(x);


        contractionMean = ...
            zeros(3,1);

        contractionMax = ...
            zeros(3,1);

        contractionRMS = ...
            zeros(3,1);


        for j = 1:3

            startTime = ...
                x(2*j-1);

            endTime = ...
                x(2*j);


            idx = ...
                t >= startTime & ...
                t <= endTime;


            contractionMean(j) = ...
                mean( ...
                EMG_Rectified(idx));


            contractionMax(j) = ...
                max( ...
                EMG_Rectified(idx));


            EMG_DC = ...
                AllDC{k};


            contractionRMS(j) = ...
                sqrt( ...
                mean( ...
                EMG_DC(idx).^2));


            xline( ...
                startTime, ...
                '--');

            xline( ...
                endTime, ...
                '--');

        end


        %% -------------------------------------------------
        % 三次握拳平均
        %% -------------------------------------------------

        Result_MeanRectified(k) = ...
            mean(contractionMean);


        Result_MaxAmplitude(k) = ...
            max(contractionMax);


        Result_RMS(k) = ...
            mean(contractionRMS);


        fprintf('\n');
        fprintf('============================================\n');

        fprintf( ...
            '%s：三次實際握拳區段\n', ...
            Result_Test(k));

        fprintf('============================================\n');


        fprintf( ...
            '平均整流振幅 = %.6f\n', ...
            Result_MeanRectified(k));

        fprintf( ...
            '最大振幅 = %.6f\n', ...
            Result_MaxAmplitude(k));

        fprintf( ...
            '平均 RMS = %.6f\n', ...
            Result_RMS(k));

    end

end


%% =========================================================
% 13. 相對於靜止狀態
%
% 本次：
% 第 2 個檔案 = 靜止
%% =========================================================

restIndex = 2;


if nFiles >= restIndex

    RestAmplitude = ...
        Result_MeanRectified(restIndex);


    Result_RelativeRest = ...
        Result_MeanRectified / ...
        RestAmplitude;

end


%% =========================================================
% 14. Summary Table
%% =========================================================

Summary = table( ...
    Result_File, ...
    Result_Test, ...
    Result_fs, ...
    Result_Duration, ...
    Result_DC, ...
    Result_MeanRectified, ...
    Result_MaxAmplitude, ...
    Result_PeakToPeak, ...
    Result_RMS, ...
    Result_RelativeRest, ...
    'VariableNames',{ ...
    '檔案名稱', ...
    '測試項目', ...
    '取樣率_Hz', ...
    '資料長度_s', ...
    'DC_Offset_mV', ...
    '整流後平均振幅_mV', ...
    '最大振幅_mV', ...
    '峰對峰振幅_mV', ...
    'RMS_mV', ...
    '相對靜止倍數'});


fprintf('\n');
fprintf('============================================\n');
fprintf('EMG Summary\n');
fprintf('============================================\n');

disp(Summary);


%% =========================================================
% 15. 持續收縮分析
%
% 第 5 個檔案
%% =========================================================

fatigueIndex = 5;


FatigueTable = table;


if nFiles >= fatigueIndex

    t = ...
        AllTime{fatigueIndex};

    EMG_Rectified = ...
        AllRect{fatigueIndex};

    EMG_DC = ...
        AllDC{fatigueIndex};


    totalDuration = ...
        t(end)-t(1);


    fprintf('\n');
    fprintf('============================================\n');
    fprintf('持續收縮分析\n');
    fprintf('============================================\n');


    fprintf( ...
        '實際記錄時間 = %.2f s\n', ...
        totalDuration);


    if totalDuration < 29.5

        warning([ ...
            '持續收縮資料未滿 30 秒。' ...
            '程式會依實際資料長度分析，' ...
            '不會自動補足缺少的時間。']);

    end


    %% -----------------------------------------------------
    % 每 5 秒切一段
    %% -----------------------------------------------------

    segmentLength = 5;


    segmentStart = ...
        (0:segmentLength:totalDuration)';


    % 最後一個開始時間若正好等於結束
    % 則移除
    segmentStart( ...
        segmentStart >= totalDuration) = [];


    nSegments = ...
        length(segmentStart);


    SegmentEnd = ...
        zeros(nSegments,1);

    SegmentDuration = ...
        zeros(nSegments,1);

    SegmentMean = ...
        zeros(nSegments,1);

    SegmentMax = ...
        zeros(nSegments,1);

    SegmentRMS = ...
        zeros(nSegments,1);


    for s = 1:nSegments

        startTime = ...
            segmentStart(s);


        endTime = ...
            min( ...
            startTime + segmentLength, ...
            totalDuration);


        idx = ...
            t >= startTime & ...
            t <= endTime;


        SegmentEnd(s) = ...
            endTime;


        SegmentDuration(s) = ...
            endTime-startTime;


        SegmentMean(s) = ...
            mean( ...
            EMG_Rectified(idx));


        SegmentMax(s) = ...
            max( ...
            EMG_Rectified(idx));


        SegmentRMS(s) = ...
            sqrt( ...
            mean( ...
            EMG_DC(idx).^2));

    end


    %% -----------------------------------------------------
    % Fatigue Table
    %% -----------------------------------------------------

    FatigueTable = table( ...
        segmentStart, ...
        SegmentEnd, ...
        SegmentDuration, ...
        SegmentMean, ...
        SegmentMax, ...
        SegmentRMS, ...
        'VariableNames',{ ...
        '開始時間_s', ...
        '結束時間_s', ...
        '實際區段長度_s', ...
        '整流後平均振幅_mV', ...
        '最大振幅_mV', ...
        'RMS_mV'});


    disp(FatigueTable);


    %% =====================================================
    % 16. Fatigue Trend
    %% =====================================================

    segmentCenter = ...
        (segmentStart + SegmentEnd)/2;


    figure( ...
        'Name', ...
        '30 秒持續收縮分析', ...
        'NumberTitle','off');


    plot( ...
        segmentCenter, ...
        SegmentMean, ...
        '-o', ...
        'LineWidth',1.5);


    xlabel( ...
        '持續收縮時間 (s)');


    ylabel( ...
        '整流後平均振幅 (mV)');


    title( ...
        '持續收縮：每 5 秒平均 EMG 振幅');


    grid on;


    %% =====================================================
    % 17. 前 5 秒 vs 最後 5 秒
    %
    % 即使整段只有 28 秒，
    % 還是可以比較真正的：
    %
    % 0~5 秒
    %
    % 與
    %
    % 最後 5 秒
    %% =====================================================

    firstIdx = ...
        t >= 0 & ...
        t <= 5;


    lastStart = ...
        max( ...
        0, ...
        totalDuration-5);


    lastIdx = ...
        t >= lastStart & ...
        t <= totalDuration;


    First5Mean = ...
        mean( ...
        EMG_Rectified(firstIdx));


    Last5Mean = ...
        mean( ...
        EMG_Rectified(lastIdx));


    FatigueChangePercent = ...
        (Last5Mean-First5Mean) / ...
        First5Mean * 100;


    fprintf('\n');

    fprintf( ...
        '前 5 秒平均振幅 = %.6f mV\n', ...
        First5Mean);


    fprintf( ...
        '末 5 秒平均振幅 = %.6f mV\n', ...
        Last5Mean);


    fprintf( ...
        '振幅變化率 = %.2f %%\n', ...
        FatigueChangePercent);

end


%% =========================================================
% 18. 六個實驗的平均振幅比較圖
%% =========================================================

figure( ...
    'Name', ...
    '不同實驗 EMG 振幅比較', ...
    'NumberTitle','off');


bar( ...
    Result_MeanRectified);


xticks(1:nFiles);

xticklabels( ...
    Result_Test);


xtickangle(30);


ylabel( ...
    '整流後平均振幅 (mV)');


title( ...
    '不同肌肉活動狀態的 EMG 平均振幅');


grid on;


%% =========================================================
% 19. 匯出結果
%% =========================================================

summaryFile = ...
    fullfile( ...
    filePath, ...
    'EMG_Analysis_Summary.csv');


writetable( ...
    Summary, ...
    summaryFile);


fprintf('\n');
fprintf('Summary 已匯出：\n');
fprintf('%s\n',summaryFile);


if ~isempty(FatigueTable)

    fatigueFile = ...
        fullfile( ...
        filePath, ...
        'EMG_Fatigue_Analysis.csv');


    writetable( ...
        FatigueTable, ...
        fatigueFile);


    fprintf('\n');
    fprintf('Fatigue Table 已匯出：\n');
    fprintf('%s\n',fatigueFile);

end


fprintf('\n');
fprintf('============================================\n');
fprintf('EMG Analysis 完成\n');
fprintf('============================================\n');
