%% =========================================================
% IMU Analysis
%
% 適用本次 IMU Signal Detection System 匯出的 CSV
%
% CSV 前 10 行：
% Group
% Subject ID
% Part
% Motion
% Trial
% Sampling Rate
% Recording Duration
% Recording Date
% Recording Time Start
% 空白列
%
% 第 11 行開始：
% Timestamp, AccX, AccY, AccZ, GyroX, GyroY, GyroZ
%
%
% 功能：
%
% Part A
% 1. 讀取六軸 IMU 訊號
% 2. 自動計算 sampling rate
% 3. 畫三軸加速度與三軸角速度
% 4. 計算 mean / std / max / min
% 5. 計算 peak-to-peak
% 6. 計算 signal energy
% 7. 找出變化最大的 Acc / Gyro 軸
% 8. 估算週期性動作次數與週期
%
% Part B
% 9. 計算加速度合成向量
% 10. Band-pass filter
% 11. 步數候選峰值偵測
% 12. 輸入人工步數與人工行走時間
% 13. 計算步數誤差
% 14. 計算步頻
% 15. 計算平均步距
% 16. 計算步行速度
%
% Part C
% 17. 自動尋找變化最大的 Acc 軸
% 18. Low-pass filter
% 19. 自動偵測起立坐下次數
% 20. 與人工完成次數比較
%
% 最後：
% 21. 產生 Summary table
% 22. 匯出 IMU_Analysis_Summary.csv
% 23. 匯出 IMU_All_Features.csv
%
%
% 注意：
%
% 需要 Signal Processing Toolbox
%
% 自動 peak detection 的結果都必須
% 將偵測點畫回波形進行人工確認。
%% =========================================================

clear;
clc;
close all;


%% =========================================================
% 1. 選擇 CSV 資料
%% =========================================================

[fileNames, filePath] = uigetfile( ...
    '*.csv', ...
    '選擇 IMU CSV 資料', ...
    'MultiSelect', 'on');


if isequal(fileNames, 0)

    disp('沒有選擇檔案');
    return;

end


% 如果只選一個檔案
% 轉成 cell array
if ischar(fileNames)

    fileNames = {fileNames};

end


nFiles = length(fileNames);


%% =========================================================
% 2. 建立結果儲存空間
%% =========================================================

Result_File = strings(nFiles,1);

Result_Part = strings(nFiles,1);
Result_Motion = strings(nFiles,1);
Result_Trial = strings(nFiles,1);

Result_fs = nan(nFiles,1);
Result_Duration = nan(nFiles,1);

Result_MaxAccAxis = strings(nFiles,1);
Result_MaxGyroAxis = strings(nFiles,1);

% Part A
Result_RepetitionCount = nan(nFiles,1);
Result_Period = nan(nFiles,1);

% Part B
Result_IMUSteps = nan(nFiles,1);
Result_ManualSteps = nan(nFiles,1);

Result_StepError = nan(nFiles,1);
Result_StepErrorPercent = nan(nFiles,1);

Result_Cadence = nan(nFiles,1);
Result_StepLength = nan(nFiles,1);
Result_GaitSpeed = nan(nFiles,1);

% Part C
Result_SitStandCount = nan(nFiles,1);
Result_ManualSitStand = nan(nFiles,1);

Result_SitStandError = nan(nFiles,1);
Result_SitStandErrorPercent = nan(nFiles,1);

% 六軸完整特徵
AllFeatures = table;


%% =========================================================
% 3. 開始逐一分析
%% =========================================================

for k = 1:nFiles

    fileName = fileNames{k};

    fullName = ...
        fullfile(filePath, fileName);


    fprintf('\n');
    fprintf('============================================\n');
    fprintf('分析檔案：%s\n', fileName);
    fprintf('============================================\n');


    %% =====================================================
    % 3.1 讀取 CSV 前面的實驗資訊
    %% =====================================================

    Meta = readIMUMetadata(fullName);


    fprintf('\n實驗資訊：\n');

    fprintf('Part   = %s\n', Meta.Part);
    fprintf('Motion = %s\n', Meta.Motion);
    fprintf('Trial  = %s\n', Meta.Trial);


    %% =====================================================
    % 3.2 讀取真正的六軸資料
    %
    % 本次 CSV：
    %
    % 第 1~9 行 = metadata
    % 第 10 行 = 空白
    % 第 11 行 = column names
    %% =====================================================

    T = readtable( ...
        fullName, ...
        'NumHeaderLines', 10, ...
        'VariableNamingRule', 'preserve');


    %% =====================================================
    % 3.3 確認欄位
    %% =====================================================

    requiredColumns = { ...
        'Timestamp', ...
        'AccX', ...
        'AccY', ...
        'AccZ', ...
        'GyroX', ...
        'GyroY', ...
        'GyroZ'};


    if ~all(ismember( ...
            requiredColumns, ...
            T.Properties.VariableNames))

        warning( ...
            '檔案欄位格式不符合預期：%s', ...
            fileName);

        continue;

    end


    %% =====================================================
    % 3.4 取出資料
    %% =====================================================

    t = T.Timestamp;

    AccX = T.AccX;
    AccY = T.AccY;
    AccZ = T.AccZ;

    GyroX = T.GyroX;
    GyroY = T.GyroY;
    GyroZ = T.GyroZ;


    % 確保都是 column vector
    t = t(:);

    AccX = AccX(:);
    AccY = AccY(:);
    AccZ = AccZ(:);

    GyroX = GyroX(:);
    GyroY = GyroY(:);
    GyroZ = GyroZ(:);


    %% =====================================================
    % 4. Sampling Rate 與時間檢查
    %% =====================================================

    dt = median(diff(t));

    fs = 1 / dt;

    duration = ...
        t(end) - t(1);


    fprintf('\n基本資料：\n');

    fprintf( ...
        'Sampling Rate = %.2f Hz\n', ...
        fs);

    fprintf( ...
        '實際資料時間 = %.2f s\n', ...
        duration);

    fprintf( ...
        'Samples = %d\n', ...
        length(t));


    % 顯示 metadata 記錄的 sampling rate
    if strlength(Meta.SamplingRate) > 0

        fprintf( ...
            'CSV Metadata Sampling Rate = %s\n', ...
            Meta.SamplingRate);

    end


    %% =====================================================
    % 5. 六軸原始波形
    %% =====================================================

    figure( ...
        'Name', fileName, ...
        'NumberTitle', 'off');


    % -----------------------------------------------------
    % 三軸加速度
    % -----------------------------------------------------

    subplot(2,1,1);

    plot(t, AccX);
    hold on;

    plot(t, AccY);
    plot(t, AccZ);

    xlabel('Time (s)');

    ylabel('Acceleration (m/s^2)');

    title( ...
        ['3-axis Acceleration - ', fileName], ...
        'Interpreter', 'none');

    legend( ...
        'Acc X', ...
        'Acc Y', ...
        'Acc Z', ...
        'Location', 'best');

    grid on;


    % -----------------------------------------------------
    % 三軸角速度
    % -----------------------------------------------------

    subplot(2,1,2);

    plot(t, GyroX);
    hold on;

    plot(t, GyroY);
    plot(t, GyroZ);

    xlabel('Time (s)');

    ylabel('Angular Velocity (deg/s)');

    title('3-axis Gyroscope');

    legend( ...
        'Gyro X', ...
        'Gyro Y', ...
        'Gyro Z', ...
        'Location', 'best');

    grid on;


    %% =====================================================
    % 6. 靜止狀態與重力檢查
    %
    % 本次資料 Acc 單位為 m/s^2
    %
    % 靜止時：
    % 三軸向量合成大小應約 9.8 m/s^2
    %
    % Gyro 應接近 0 deg/s
    %% =====================================================

    MeanAccX = mean(AccX);
    MeanAccY = mean(AccY);
    MeanAccZ = mean(AccZ);

    MeanGyroX = mean(GyroX);
    MeanGyroY = mean(GyroY);
    MeanGyroZ = mean(GyroZ);


    GravityMagnitude = sqrt( ...
        MeanAccX^2 + ...
        MeanAccY^2 + ...
        MeanAccZ^2);


    fprintf('\n六軸平均值：\n');

    fprintf( ...
        'Acc X = %.4f m/s^2\n', ...
        MeanAccX);

    fprintf( ...
        'Acc Y = %.4f m/s^2\n', ...
        MeanAccY);

    fprintf( ...
        'Acc Z = %.4f m/s^2\n', ...
        MeanAccZ);


    fprintf( ...
        '平均加速度向量大小 = %.4f m/s^2\n', ...
        GravityMagnitude);


    fprintf( ...
        'Gyro X = %.4f deg/s\n', ...
        MeanGyroX);

    fprintf( ...
        'Gyro Y = %.4f deg/s\n', ...
        MeanGyroY);

    fprintf( ...
        'Gyro Z = %.4f deg/s\n', ...
        MeanGyroZ);


    %% =====================================================
    % 7. 六軸特徵分析
    %
    % mean
    % std
    % max
    % min
    % peak-to-peak
    % energy
    % peak number
    % period
    %% =====================================================

    Signals = [ ...
        AccX, ...
        AccY, ...
        AccZ, ...
        GyroX, ...
        GyroY, ...
        GyroZ];


    SignalNames = [ ...
        "AccX"; ...
        "AccY"; ...
        "AccZ"; ...
        "GyroX"; ...
        "GyroY"; ...
        "GyroZ"];


    MeanValue = zeros(6,1);
    StdValue = zeros(6,1);

    MaxValue = zeros(6,1);
    MinValue = zeros(6,1);

    PeakToPeak = zeros(6,1);

    Energy = zeros(6,1);

    PeakNumber = zeros(6,1);

    Period = nan(6,1);


    for s = 1:6

        x = Signals(:,s);


        % -------------------------------
        % Mean
        % -------------------------------

        MeanValue(s) = ...
            mean(x);


        % -------------------------------
        % Standard deviation
        % -------------------------------

        StdValue(s) = ...
            std(x);


        % -------------------------------
        % Maximum / Minimum
        % -------------------------------

        MaxValue(s) = ...
            max(x);

        MinValue(s) = ...
            min(x);


        % -------------------------------
        % Peak-to-Peak
        % -------------------------------

        PeakToPeak(s) = ...
            MaxValue(s) - MinValue(s);


        % -------------------------------
        % Signal Energy
        %
        % 先去除平均值
        % 避免 Acc 的重力 DC 成分
        % 主導 energy
        % -------------------------------

        x0 = ...
            x - mean(x);

        Energy(s) = ...
            sum(x0.^2);


        % -------------------------------
        % 通用 Peak Detection
        %
        % 這只是訊號特徵，
        % 不代表一定是步數。
        % -------------------------------

        prominence = ...
            0.50 * std(x0);

        minPeakDistance = ...
            max(1, round(0.30 * fs));


        if prominence > 0

            [~, loc] = findpeaks( ...
                x0, ...
                'MinPeakDistance', ...
                minPeakDistance, ...
                'MinPeakProminence', ...
                prominence);

        else

            loc = [];

        end


        PeakNumber(s) = ...
            length(loc);


        % -------------------------------
        % 週期
        % -------------------------------

        if length(loc) >= 2

            peakTime = ...
                t(loc);

            Period(s) = ...
                median(diff(peakTime));

        end

    end


    %% =====================================================
    % 8. 特徵表
    %% =====================================================

    FeatureTable = table( ...
        repmat(string(fileName),6,1), ...
        repmat(Meta.Part,6,1), ...
        repmat(Meta.Motion,6,1), ...
        SignalNames, ...
        MeanValue, ...
        StdValue, ...
        MaxValue, ...
        MinValue, ...
        PeakToPeak, ...
        Energy, ...
        PeakNumber, ...
        Period, ...
        'VariableNames',{ ...
        'File', ...
        'Part', ...
        'Motion', ...
        'Signal', ...
        'Mean', ...
        'Std', ...
        'Max', ...
        'Min', ...
        'PeakToPeak', ...
        'Energy', ...
        'PeakNumber', ...
        'Period_s'});


    fprintf('\n');
    fprintf('============================================\n');
    fprintf('六軸特徵分析\n');
    fprintf('============================================\n');

    disp(FeatureTable);


    % 合併所有檔案的特徵
    if isempty(AllFeatures)

        AllFeatures = ...
            FeatureTable;

    else

        AllFeatures = [ ...
            AllFeatures; ...
            FeatureTable];

    end


    %% =====================================================
    % 9. 找變化最大的 Acc 與 Gyro 軸
    %
    % 使用 standard deviation
    %% =====================================================

    [~, AccIndex] = ...
        max(StdValue(1:3));

    [~, GyroTemp] = ...
        max(StdValue(4:6));

    GyroIndex = ...
        GyroTemp + 3;


    MaxAccAxis = ...
        SignalNames(AccIndex);

    MaxGyroAxis = ...
        SignalNames(GyroIndex);


    fprintf('\n');

    fprintf( ...
        '變化最大的加速度軸 = %s\n', ...
        MaxAccAxis);

    fprintf( ...
        '變化最大的角速度軸 = %s\n', ...
        MaxGyroAxis);


    %% =====================================================
    % 10. Acc / Gyro 合成向量
    %% =====================================================

    AccMagnitude = sqrt( ...
        AccX.^2 + ...
        AccY.^2 + ...
        AccZ.^2);


    GyroMagnitude = sqrt( ...
        GyroX.^2 + ...
        GyroY.^2 + ...
        GyroZ.^2);


    %% =====================================================
    % 11. Part A 分析
    %% =====================================================

    PartA_RepetitionCount = NaN;
    PartA_Period = NaN;


    if strcmpi(Meta.Part, "Part A")

        fprintf('\n');
        fprintf('============================================\n');
        fprintf('Part A 動作分析\n');
        fprintf('============================================\n');


        % 靜止資料不做動作次數偵測
        if contains(Meta.Motion, "靜止")

            fprintf( ...
                '此筆為靜止資料，不進行動作次數偵測。\n');


        else

            %% ---------------------------------------------
            % 使用變化最大的 Gyro 軸
            %
            % 本次實際資料：
            %
            % 上下抬手 -> Gyro Y
            % 左右揮手 -> Gyro Z
            %
            % 因此用最大變化軸較適合不同動作。
            %% ---------------------------------------------

            ActionSignal = ...
                Signals(:,GyroIndex);

            ActionSignal0 = ...
                ActionSignal - ...
                mean(ActionSignal);


            %% ---------------------------------------------
            % Low-pass filter
            %
            % 人體重複手部動作主要是低頻
            %% ---------------------------------------------

            cutoff = ...
                min(3, 0.40*fs);


            [bA, aA] = butter( ...
                3, ...
                cutoff/(fs/2), ...
                'low');


            ActionFiltered = filtfilt( ...
                bA, ...
                aA, ...
                ActionSignal0);


            %% ---------------------------------------------
            % 動作次數偵測
            %% ---------------------------------------------

            minDistance = ...
                round(0.50 * fs);

            actionProminence = ...
                0.50 * std(ActionFiltered);


            [ActionAmp, ActionLoc] = findpeaks( ...
                ActionFiltered, ...
                'MinPeakDistance', ...
                minDistance, ...
                'MinPeakProminence', ...
                actionProminence);


            PartA_RepetitionCount = ...
                length(ActionLoc);


            if length(ActionLoc) >= 2

                PartA_Period = ...
                    median(diff(t(ActionLoc)));

            end


            fprintf( ...
                '使用訊號 = %s\n', ...
                MaxGyroAxis);

            fprintf( ...
                '動作候選次數 = %d\n', ...
                PartA_RepetitionCount);

            fprintf( ...
                '動作週期 = %.3f s\n', ...
                PartA_Period);


            %% ---------------------------------------------
            % 畫出動作偵測結果
            %% ---------------------------------------------

            figure( ...
                'Name', ...
                ['Part A - ', fileName], ...
                'NumberTitle', 'off');


            h = gobjects(0);
            names = {};


            h1 = plot( ...
                t, ...
                ActionFiltered);

            hold on;

            h(end+1) = h1;
            names{end+1} = ...
                char(MaxGyroAxis);


            if ~isempty(ActionLoc)

                h2 = plot( ...
                    t(ActionLoc), ...
                    ActionAmp, ...
                    'ro', ...
                    'MarkerSize', 7);

                h(end+1) = h2;

                names{end+1} = ...
                    'Detected Action';

            end


            xlabel('Time (s)');

            ylabel('Angular Velocity');

            title(sprintf( ...
                '%s | Detected = %d', ...
                Meta.Motion, ...
                PartA_RepetitionCount));


            legend( ...
                h, ...
                names, ...
                'Location', 'best');

            grid on;

        end

    end


    %% =====================================================
    % 12. Part B 行走分析
    %% =====================================================

    IMUStepCount = NaN;

    ManualSteps = NaN;

    StepError = NaN;
    StepErrorPercent = NaN;

    Cadence = NaN;
    StepLength = NaN;
    GaitSpeed = NaN;


    if strcmpi(Meta.Part, "Part B")

        fprintf('\n');
        fprintf('============================================\n');
        fprintf('Part B 行走分析\n');
        fprintf('============================================\n');


        %% ---------------------------------------------
        % 使用三軸 Acc 合成向量
        %
        % 優點：
        % 比較不受感測器方向影響
        %% ---------------------------------------------

        WalkSignal = ...
            AccMagnitude - ...
            mean(AccMagnitude);


        %% ---------------------------------------------
        % 0.5 - 5 Hz Band-pass Filter
        %% ---------------------------------------------

        lowCut = 0.5;

        highCut = ...
            min(5, 0.40*fs);


        [bWalk, aWalk] = butter( ...
            3, ...
            [lowCut highCut]/(fs/2), ...
            'bandpass');


        WalkFiltered = filtfilt( ...
            bWalk, ...
            aWalk, ...
            WalkSignal);


        %% ---------------------------------------------
        % Step Candidate Detection
        %
        % 注意：
        % 手腕 IMU 的 peak 不一定 1:1 對應一步
        %
        % 因此必須與人工計數比較。
        %% ---------------------------------------------

        StepMinDistance = ...
            round(0.30 * fs);

        StepProminence = ...
            0.35 * std(WalkFiltered);


        [StepAmp, StepLoc] = findpeaks( ...
            WalkFiltered, ...
            'MinPeakDistance', ...
            StepMinDistance, ...
            'MinPeakProminence', ...
            StepProminence);


        IMUStepCount = ...
            length(StepLoc);


        fprintf( ...
            'IMU 步數候選峰 = %d\n', ...
            IMUStepCount);


        %% ---------------------------------------------
        % 畫出 Step Detection
        %% ---------------------------------------------

        figure( ...
            'Name', ...
            ['Part B - ', fileName], ...
            'NumberTitle', 'off');


        h = gobjects(0);
        names = {};


        h1 = plot( ...
            t, ...
            WalkFiltered);

        hold on;

        h(end+1) = h1;

        names{end+1} = ...
            'Filtered Acc Magnitude';


        if ~isempty(StepLoc)

            h2 = plot( ...
                t(StepLoc), ...
                StepAmp, ...
                'ro', ...
                'MarkerSize', 7);

            h(end+1) = h2;

            names{end+1} = ...
                'Step Candidate';

        end


        xlabel('Time (s)');

        ylabel('Dynamic Acc Magnitude');

        title(sprintf( ...
            'Walking Step Candidates = %d', ...
            IMUStepCount));


        legend( ...
            h, ...
            names, ...
            'Location', 'best');

        grid on;


        %% ---------------------------------------------
        % 輸入人工紀錄
        %
        % 手冊 Part B：
        %
        % 距離 = 4 m
        % 人工步數
        % 人工碼錶時間
        %% ---------------------------------------------

        answerB = inputdlg( ...
            { ...
            '實際行走距離 (m)：', ...
            '人工計數步數：', ...
            '人工行走時間 (s)：'}, ...
            ['Part B - ', fileName], ...
            [1 40], ...
            {'4','',''});


        if ~isempty(answerB)

            Distance_m = ...
                str2double(answerB{1});

            ManualSteps = ...
                str2double(answerB{2});

            ManualTime = ...
                str2double(answerB{3});


            if isfinite(ManualSteps) && ...
               ManualSteps > 0

                StepError = ...
                    abs( ...
                    IMUStepCount - ...
                    ManualSteps);

                StepErrorPercent = ...
                    StepError / ...
                    ManualSteps * 100;

            end


            if isfinite(ManualTime) && ...
               ManualTime > 0


                % -------------------------
                % IMU 推算步頻
                % -------------------------

                Cadence = ...
                    IMUStepCount / ...
                    ManualTime * 60;


                % -------------------------
                % 步行速度
                %
                % 使用人工碼錶時間
                % 不使用 CSV 錄製總時間
                % -------------------------

                if isfinite(Distance_m)

                    GaitSpeed = ...
                        Distance_m / ...
                        ManualTime;

                end

            end


            % -----------------------------
            % 平均步距
            % -----------------------------

            if IMUStepCount > 0 && ...
               isfinite(Distance_m)

                StepLength = ...
                    Distance_m / ...
                    IMUStepCount;

            end


            fprintf('\nPart B 結果：\n');

            fprintf( ...
                '人工步數 = %.0f\n', ...
                ManualSteps);

            fprintf( ...
                'IMU 候選步數 = %.0f\n', ...
                IMUStepCount);

            fprintf( ...
                '步數絕對誤差 = %.0f\n', ...
                StepError);

            fprintf( ...
                '步數相對誤差 = %.2f %%\n', ...
                StepErrorPercent);

            fprintf( ...
                '步頻 = %.2f step/min\n', ...
                Cadence);

            fprintf( ...
                '平均步距 = %.3f m/step\n', ...
                StepLength);

            fprintf( ...
                '步行速度 = %.3f m/s\n', ...
                GaitSpeed);

        end

    end


    %% =====================================================
    % 13. Part C 起立坐下分析
    %% =====================================================

    SitStandCount = NaN;

    ManualSitStand = NaN;

    SitStandError = NaN;
    SitStandErrorPercent = NaN;


    if strcmpi(Meta.Part, "Part C")

        fprintf('\n');
        fprintf('============================================\n');
        fprintf('Part C 起立坐下分析\n');
        fprintf('============================================\n');


        %% ---------------------------------------------
        % 自動選擇 Acc X/Y/Z 中
        % 標準差最大的軸
        %
        % 本次實際資料三筆皆為 AccY
        %% ---------------------------------------------

        AccSignals = [ ...
            AccX, ...
            AccY, ...
            AccZ];


        AccNames = [ ...
            "AccX", ...
            "AccY", ...
            "AccZ"];


        AccStd = [ ...
            std(AccX), ...
            std(AccY), ...
            std(AccZ)];


        [~, BestAccIndex] = ...
            max(AccStd);


        SitStandSignal = ...
            AccSignals(:,BestAccIndex);


        SitStandAxis = ...
            AccNames(BestAccIndex);


        fprintf( ...
            '起立坐下主要軸 = %s\n', ...
            SitStandAxis);


        %% ---------------------------------------------
        % 去除 DC
        %% ---------------------------------------------

        SitStand0 = ...
            SitStandSignal - ...
            mean(SitStandSignal);


        %% ---------------------------------------------
        % 2 Hz Low-pass
        %% ---------------------------------------------

        cutOff = 2;


        [bSit, aSit] = butter( ...
            3, ...
            cutOff/(fs/2), ...
            'low');


        SitStandFiltered = filtfilt( ...
            bSit, ...
            aSit, ...
            SitStand0);


        %% ---------------------------------------------
        % 分別找正峰與負峰
        %
        % 感測器方向不同時，
        % 起立特徵可能朝正或負。
        %% ---------------------------------------------

        MinSitDistance = ...
            round(1.40 * fs);


        SitProminence = ...
            0.60 * std(SitStandFiltered);


        [PosAmp, PosLoc, ~, PosProm] = findpeaks( ...
            SitStandFiltered, ...
            'MinPeakDistance', ...
            MinSitDistance, ...
            'MinPeakProminence', ...
            SitProminence);


        [NegAmp, NegLoc, ~, NegProm] = findpeaks( ...
            -SitStandFiltered, ...
            'MinPeakDistance', ...
            MinSitDistance, ...
            'MinPeakProminence', ...
            SitProminence);


        %% ---------------------------------------------
        % 選擇較明顯的峰值方向
        %% ---------------------------------------------

        if isempty(PosProm)

            PosScore = 0;

        else

            PosScore = ...
                median(PosProm);

        end


        if isempty(NegProm)

            NegScore = 0;

        else

            NegScore = ...
                median(NegProm);

        end


        if PosScore >= NegScore

            SitLoc = PosLoc;

            PeakDirection = ...
                "Positive";

        else

            SitLoc = NegLoc;

            PeakDirection = ...
                "Negative";

        end


        SitStandCount = ...
            length(SitLoc);


        fprintf( ...
            '使用峰值方向 = %s\n', ...
            PeakDirection);

        fprintf( ...
            'IMU 起立坐下候選次數 = %d\n', ...
            SitStandCount);


        %% ---------------------------------------------
        % 畫出偵測結果
        %% ---------------------------------------------

        figure( ...
            'Name', ...
            ['Part C - ', fileName], ...
            'NumberTitle', 'off');


        h = gobjects(0);
        names = {};


        h1 = plot( ...
            t, ...
            SitStandFiltered);

        hold on;


        h(end+1) = h1;

        names{end+1} = ...
            char(SitStandAxis);


        if ~isempty(SitLoc)

            h2 = plot( ...
                t(SitLoc), ...
                SitStandFiltered(SitLoc), ...
                'ro', ...
                'MarkerSize', 7);

            h(end+1) = h2;

            names{end+1} = ...
                'Detected Cycle';

        end


        xlabel('Time (s)');

        ylabel('Acceleration (m/s^2)');


        title(sprintf( ...
            'Sit-to-Stand Detection = %d', ...
            SitStandCount));


        legend( ...
            h, ...
            names, ...
            'Location', 'best');

        grid on;


        %% ---------------------------------------------
        % 根據檔名提供預設人工次數
        %% ---------------------------------------------

        defaultCount = '';


        if contains( ...
                Meta.Motion, ...
                "5 次")

            defaultCount = '5';

        elseif contains( ...
                Meta.Motion, ...
                "10 次")

            defaultCount = '10';

        end


        %% ---------------------------------------------
        % 人工紀錄
        %% ---------------------------------------------

        answerC = inputdlg( ...
            { ...
            '人工完成次數：', ...
            '人工完成時間 (s)：'}, ...
            ['Part C - ', fileName], ...
            [1 40], ...
            {defaultCount,''});


        if ~isempty(answerC)

            ManualSitStand = ...
                str2double(answerC{1});

            ManualSitTime = ...
                str2double(answerC{2});


            if isfinite(ManualSitStand) && ...
               ManualSitStand > 0

                SitStandError = ...
                    abs( ...
                    SitStandCount - ...
                    ManualSitStand);

                SitStandErrorPercent = ...
                    SitStandError / ...
                    ManualSitStand * 100;

            end


            fprintf('\nPart C 結果：\n');

            fprintf( ...
                '人工次數 = %.0f\n', ...
                ManualSitStand);

            fprintf( ...
                'IMU 偵測次數 = %.0f\n', ...
                SitStandCount);

            fprintf( ...
                '絕對誤差 = %.0f 次\n', ...
                SitStandError);

            fprintf( ...
                '相對誤差 = %.2f %%\n', ...
                SitStandErrorPercent);


            if isfinite(ManualSitTime) && ...
               ManualSitTime > 0

                fprintf( ...
                    '完成時間 = %.2f s\n', ...
                    ManualSitTime);

                fprintf( ...
                    '平均每次週期 = %.2f s\n', ...
                    ManualSitTime / ...
                    ManualSitStand);

            end

        end

    end


    %% =====================================================
    % 14. 儲存 Summary
    %% =====================================================

    Result_File(k) = ...
        string(fileName);

    Result_Part(k) = ...
        Meta.Part;

    Result_Motion(k) = ...
        Meta.Motion;

    Result_Trial(k) = ...
        Meta.Trial;

    Result_fs(k) = ...
        fs;

    Result_Duration(k) = ...
        duration;

    Result_MaxAccAxis(k) = ...
        MaxAccAxis;

    Result_MaxGyroAxis(k) = ...
        MaxGyroAxis;


    % Part A
    Result_RepetitionCount(k) = ...
        PartA_RepetitionCount;

    Result_Period(k) = ...
        PartA_Period;


    % Part B
    Result_IMUSteps(k) = ...
        IMUStepCount;

    Result_ManualSteps(k) = ...
        ManualSteps;

    Result_StepError(k) = ...
        StepError;

    Result_StepErrorPercent(k) = ...
        StepErrorPercent;

    Result_Cadence(k) = ...
        Cadence;

    Result_StepLength(k) = ...
        StepLength;

    Result_GaitSpeed(k) = ...
        GaitSpeed;


    % Part C
    Result_SitStandCount(k) = ...
        SitStandCount;

    Result_ManualSitStand(k) = ...
        ManualSitStand;

    Result_SitStandError(k) = ...
        SitStandError;

    Result_SitStandErrorPercent(k) = ...
        SitStandErrorPercent;

end


%% =========================================================
% 15. Summary Table
%% =========================================================

Summary = table( ...
    Result_File, ...
    Result_Part, ...
    Result_Motion, ...
    Result_Trial, ...
    Result_fs, ...
    Result_Duration, ...
    Result_MaxAccAxis, ...
    Result_MaxGyroAxis, ...
    Result_RepetitionCount, ...
    Result_Period, ...
    Result_IMUSteps, ...
    Result_ManualSteps, ...
    Result_StepError, ...
    Result_StepErrorPercent, ...
    Result_Cadence, ...
    Result_StepLength, ...
    Result_GaitSpeed, ...
    Result_SitStandCount, ...
    Result_ManualSitStand, ...
    Result_SitStandError, ...
    Result_SitStandErrorPercent, ...
    'VariableNames',{ ...
    'File', ...
    'Part', ...
    'Motion', ...
    'Trial', ...
    'Fs_Hz', ...
    'Duration_s', ...
    'Max_Acc_Axis', ...
    'Max_Gyro_Axis', ...
    'PartA_Repetition', ...
    'PartA_Period_s', ...
    'IMU_Step_Count', ...
    'Manual_Step_Count', ...
    'Step_Error', ...
    'Step_Error_percent', ...
    'Cadence_step_per_min', ...
    'Step_Length_m', ...
    'Gait_Speed_m_per_s', ...
    'SitStand_IMU_Count', ...
    'SitStand_Manual_Count', ...
    'SitStand_Error', ...
    'SitStand_Error_percent'});


fprintf('\n');
fprintf('============================================\n');
fprintf('IMU Analysis Summary\n');
fprintf('============================================\n');

disp(Summary);


%% =========================================================
% 16. 匯出 Summary
%% =========================================================

summaryFile = ...
    fullfile( ...
    filePath, ...
    'IMU_Analysis_Summary.csv');


writetable( ...
    Summary, ...
    summaryFile);


fprintf('\n');
fprintf('Summary 已匯出：\n');
fprintf('%s\n', summaryFile);


%% =========================================================
% 17. 匯出所有六軸 Feature
%% =========================================================

featureFile = ...
    fullfile( ...
    filePath, ...
    'IMU_All_Features.csv');


writetable( ...
    AllFeatures, ...
    featureFile);


fprintf('\n');
fprintf('Feature Table 已匯出：\n');
fprintf('%s\n', featureFile);

fprintf('\n');
fprintf('全部分析完成。\n');


%% =========================================================
% Local Function
%
% 讀取 CSV 前 9 行 Metadata
%% =========================================================

function Meta = readIMUMetadata(fullName)

    Meta.Part = "";
    Meta.Motion = "";
    Meta.Trial = "";

    Meta.SamplingRate = "";
    Meta.RecordingDuration = "";

    Meta.Group = "";
    Meta.SubjectID = "";

    Meta.RecordingDate = "";
    Meta.RecordingTime = "";


    fid = fopen( ...
        fullName, ...
        'r');


    if fid == -1

        error( ...
            '無法開啟檔案：%s', ...
            fullName);

    end


    for i = 1:9

        line = ...
            fgetl(fid);


        if ~ischar(line)

            break;

        end


        lineString = ...
            string(line);


        commaLocation = ...
            find( ...
            char(lineString) == ',', ...
            1, ...
            'first');


        if isempty(commaLocation)

            continue;

        end


        key = strtrim( ...
            extractBefore( ...
            lineString, ...
            commaLocation));


        value = strtrim( ...
            extractAfter( ...
            lineString, ...
            commaLocation));


        switch lower(key)

            case "group"

                Meta.Group = value;


            case "subject id"

                Meta.SubjectID = value;


            case "part"

                Meta.Part = value;


            case "motion"

                Meta.Motion = value;


            case "trial"

                Meta.Trial = value;


            case "sampling rate"

                Meta.SamplingRate = value;


            case "recording duration"

                Meta.RecordingDuration = value;


            case "recording date"

                Meta.RecordingDate = value;


            case "recording time start"

                Meta.RecordingTime = value;

        end

    end


    fclose(fid);

end
