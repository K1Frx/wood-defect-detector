% preview_preprocessed_data.m
% Skrypt do podglądu przetworzonych danych z maskami defektów

% ============== ŁADOWANIE DANYCH ==============
fprintf('📊 PODGLĄD PRZETWORZONYCH DANYCH\n');
fprintf('====================================\n\n');

preprocessDir = 'dataset_preprocessed';
summaryFile = fullfile(preprocessDir, 'preprocess_summary.mat');

if ~exist(summaryFile, 'file')
    error('❌ Nie znaleziono pliku preprocess_summary.mat\n   Uruchom najpierw preprocess_wood_defects.m');
end

% Wczytaj dane
load(summaryFile);

fprintf('✓ Wczytano dane preprocessing:\n');
fprintf('  - Liczba obrazów: %d\n', length(imgPaths));
fprintf('  - Liczba klas: %d\n', length(targetClasses));
fprintf('  - Klasy: %s\n\n', strjoin(targetClasses, ', '));

% ============== STATYSTYKI ==============
fprintf('📈 STATYSTYKI DEFEKTÓW:\n');
fprintf('====================================\n');

totalDefects = 0;
for i = 1:length(labelsAll)
    totalDefects = totalDefects + length(labelsAll{i});
end

fprintf('Całkowita liczba defektów: %d\n\n', totalDefects);

for i = 1:length(targetClasses)
    className = targetClasses{i};
    count = classStats(className);
    percentage = (count / max(totalDefects, 1)) * 100;
    fprintf('   %s: %d (%.1f%%)\n', className, count, percentage);
end
fprintf('====================================\n\n');

% ============== WYKRES STATYSTYK ==============
figure('Name', 'Statystyki klas defektów', 'Position', [100, 100, 800, 500]);

classNames = targetClasses;
classCounts = zeros(1, length(targetClasses));
for i = 1:length(targetClasses)
    classCounts(i) = classStats(targetClasses{i});
end

subplot(1,2,1);
bar(classCounts);
set(gca, 'XTickLabel', classNames);
xtickangle(45);
ylabel('Liczba instancji');
title('Rozkład klas defektów');
grid on;

subplot(1,2,2);
pie(classCounts, classNames);
title('Procentowy udział klas');

% ============== MENU INTERAKTYWNE ==============
fprintf('🖼️  INTERAKTYWNY PODGLĄD\n');
fprintf('====================================\n');
fprintf('Wybierz opcję:\n');
fprintf('  1 - Pokaż wszystkie obrazy z defektami\n');
fprintf('  2 - Pokaż losowe 9 obrazów\n');
fprintf('  3 - Pokaż obrazy konkretnej klasy\n');
fprintf('  4 - Szczegółowy podgląd pojedynczego obrazu\n');
fprintf('  5 - Porównanie przed/po preprocessingu\n');
fprintf('  0 - Wyjście\n\n');

while true
    choice = input('Wybór: ');
    
    if choice == 0
        fprintf('👋 Do widzenia!\n');
        break;
    end
    
    switch choice
        case 1
            % Pokaż wszystkie obrazy z defektami
            showAllImagesWithDefects(imgPaths, masksAll, labelsAll, targetClasses, classToValue);
            
        case 2
            % Pokaż losowe 9 obrazów
            showRandomImages(imgPaths, masksAll, labelsAll, targetClasses, classToValue);
            
        case 3
            % Pokaż obrazy konkretnej klasy
            fprintf('\nWybierz klasę:\n');
            for i = 1:length(targetClasses)
                fprintf('  %d - %s\n', i, targetClasses{i});
            end
            classChoice = input('Numer klasy: ');
            
            if classChoice >= 1 && classChoice <= length(targetClasses)
                selectedClass = targetClasses{classChoice};
                showClassImages(imgPaths, masksAll, labelsAll, selectedClass, targetClasses, classToValue);
            else
                fprintf('❌ Nieprawidłowy wybór\n');
            end
            
        case 4
            % Szczegółowy podgląd
            fprintf('\nPodaj numer obrazu (1-%d): ', length(imgPaths));
            imgNum = input('');
            
            if imgNum >= 1 && imgNum <= length(imgPaths)
                showDetailedView(imgPaths{imgNum}, masksAll{imgNum}, labelsAll{imgNum}, ...
                                targetClasses, classToValue, imgSizes(imgNum,:));
            else
                fprintf('❌ Nieprawidłowy numer\n');
            end
            
        case 5
            % Porównanie przed/po
            showBeforeAfterComparison(imgPaths, masksAll, labelsAll);
            
        otherwise
            fprintf('❌ Nieprawidłowy wybór\n');
    end
    
    fprintf('\n');
end

% ============== FUNKCJE POMOCNICZE ==============

function showAllImagesWithDefects(imgPaths, masksAll, labelsAll, targetClasses, classToValue)
    % Znajdź obrazy z defektami
    idxWithDefects = find(cellfun(@(x) ~isempty(x), labelsAll));
    
    if isempty(idxWithDefects)
        fprintf('❌ Brak obrazów z defektami\n');
        return;
    end
    
    fprintf('Znaleziono %d obrazów z defektami\n', length(idxWithDefects));
    
    % Pokaż w siatce 3x3
    numPages = ceil(length(idxWithDefects) / 9);
    
    for page = 1:numPages
        startIdx = (page-1)*9 + 1;
        endIdx = min(page*9, length(idxWithDefects));
        
        figure('Name', sprintf('Obrazy z defektami (strona %d/%d)', page, numPages), ...
               'Position', [50, 50, 1600, 1200]);
        
        for i = startIdx:endIdx
            idx = idxWithDefects(i);
            subplot(3, 3, i - startIdx + 1);
            
            img = imread(imgPaths{idx});
            mask = masksAll{idx};
            
            imshow(img); hold on;
            
            % Nakładka maski
            colorMap = [0 0 0; 1 0 0; 0 1 0; 0 0 1; 1 1 0];
            h = imshow(mask, colorMap);
            set(h, 'AlphaData', double(mask > 0) * 0.4);
            
            title(sprintf('#%d: %s', idx, strjoin(labelsAll{idx}, ', ')), ...
                  'Interpreter', 'none', 'FontSize', 8);
            hold off;
        end
    end
end

function showRandomImages(imgPaths, masksAll, labelsAll, targetClasses, classToValue)
    numImages = min(9, length(imgPaths));
    randomIdx = randperm(length(imgPaths), numImages);
    
    figure('Name', 'Losowe 9 obrazów', 'Position', [50, 50, 1600, 1200]);
    
    for i = 1:numImages
        idx = randomIdx(i);
        subplot(3, 3, i);
        
        img = imread(imgPaths{idx});
        mask = masksAll{idx};
        
        imshow(img); hold on;
        
        if any(mask(:) > 0)
            colorMap = [0 0 0; 1 0 0; 0 1 0; 0 0 1; 1 1 0];
            h = imshow(mask, colorMap);
            set(h, 'AlphaData', double(mask > 0) * 0.4);
            
            title(sprintf('#%d: %s', idx, strjoin(labelsAll{idx}, ', ')), ...
                  'Interpreter', 'none', 'FontSize', 8);
        else
            title(sprintf('#%d: Brak defektów', idx), 'FontSize', 8);
        end
        hold off;
    end
end

function showClassImages(imgPaths, masksAll, labelsAll, selectedClass, targetClasses, classToValue)
    % Znajdź obrazy z wybraną klasą
    idxWithClass = [];
    for i = 1:length(labelsAll)
        if ismember(selectedClass, labelsAll{i})
            idxWithClass(end+1) = i;
        end
    end
    
    if isempty(idxWithClass)
        fprintf('❌ Brak obrazów z klasą "%s"\n', selectedClass);
        return;
    end
    
    fprintf('Znaleziono %d obrazów z klasą "%s"\n', length(idxWithClass), selectedClass);
    
    % Pokaż w siatce
    numToShow = min(9, length(idxWithClass));
    
    figure('Name', sprintf('Klasa: %s (%d obrazów)', selectedClass, length(idxWithClass)), ...
           'Position', [50, 50, 1600, 1200]);
    
    for i = 1:numToShow
        idx = idxWithClass(i);
        subplot(3, 3, i);
        
        img = imread(imgPaths{idx});
        mask = masksAll{idx};
        
        % Wyświetl tylko wybraną klasę
        classValue = classToValue(selectedClass);
        classMask = (mask == classValue);
        
        imshow(img); hold on;
        
        % Czerwona maska dla wybranej klasy
        h = imshow(classMask);
        set(h, 'AlphaData', double(classMask) * 0.5);
        colormap([0 0 0; 1 0 0]);
        
        title(sprintf('#%d', idx), 'FontSize', 8);
        hold off;
    end
end

function showDetailedView(imgPath, mask, labels, targetClasses, classToValue, imgSize)
    [~, imgName] = fileparts(imgPath);
    
    figure('Name', sprintf('Szczegóły: %s', imgName), 'Position', [50, 50, 1800, 900]);
    
    img = imread(imgPath);
    
    % Oryginalny obraz
    subplot(2,3,1);
    imshow(img);
    title(sprintf('Obraz\n%dx%d px', imgSize(1), imgSize(2)));
    
    % Maska segmentacji
    subplot(2,3,2);
    colorMap = [0 0 0; 1 0 0; 0 1 0; 0 0 1; 1 1 0];
    imshow(mask, colorMap);
    title(sprintf('Maska\n%d defektów', length(labels)));
    
    % Nakładka
    subplot(2,3,3);
    imshow(img); hold on;
    h = imshow(mask, colorMap);
    set(h, 'AlphaData', double(mask > 0) * 0.5);
    title('Nakładka');
    hold off;
    
    % Poszczególne klasy
    numClasses = length(labels);
    for i = 1:min(3, numClasses)
        subplot(2, 3, 3 + i);
        
        className = labels{i};
        classValue = classToValue(className);
        classMask = (mask == classValue);
        
        imshow(img); hold on;
        h = imshow(classMask);
        set(h, 'AlphaData', double(classMask) * 0.6);
        colormap([0 0 0; 1 0 0]);
        
        numPixels = sum(classMask(:));
        title(sprintf('%s\n%d pikseli', className, numPixels), 'Interpreter', 'none');
        hold off;
    end
    
    % Informacje tekstowe
    if numClasses == 0
        subplot(2,3,4);
        axis off;
        text(0.5, 0.5, 'Brak defektów', ...
             'HorizontalAlignment', 'center', 'FontSize', 14);
    end
end

function showBeforeAfterComparison(imgPaths, masksAll, labelsAll)
    % Znajdź obrazy z defektami
    idxWithDefects = find(cellfun(@(x) ~isempty(x), labelsAll));
    
    if isempty(idxWithDefects)
        fprintf('❌ Brak obrazów z defektami\n');
        return;
    end
    
    % Pokaż pierwsze 3
    numToShow = min(3, length(idxWithDefects));
    
    for i = 1:numToShow
        idx = idxWithDefects(i);
        [~, baseName] = fileparts(imgPaths{idx});
        
        % Znajdź oryginalny plik
        origFile = fullfile('dataset', 'img', [baseName '.bmp']);
        
        if ~exist(origFile, 'file')
            fprintf('⚠ Nie znaleziono oryginalnego pliku: %s\n', origFile);
            continue;
        end
        
        figure('Name', sprintf('Porównanie: %s', baseName), 'Position', [50, 50, 1600, 500]);
        
        origImg = imread(origFile);
        processedImg = imread(imgPaths{idx});
        mask = masksAll{idx};
        
        % Oryginalny
        subplot(1,3,1);
        imshow(origImg);
        title('Przed preprocessingiem');
        
        % Po preprocessingu
        subplot(1,3,2);
        imshow(processedImg);
        title('Po equalizacji histogramu');
        
        % Z maską
        subplot(1,3,3);
        imshow(processedImg); hold on;
        colorMap = [0 0 0; 1 0 0; 0 1 0; 0 0 1; 1 1 0];
        h = imshow(mask, colorMap);
        set(h, 'AlphaData', double(mask > 0) * 0.5);
        title(sprintf('Z maską (%s)', strjoin(labelsAll{idx}, ', ')));
        hold off;
    end
end