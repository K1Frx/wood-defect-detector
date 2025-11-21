% check_raw_data.m
% Sprawdzenie surowych danych bez dekompresji

jsonFile = fullfile('dataset','ann','100000077.bmp.json');

fprintf('🔍 ANALIZA SUROWYCH DANYCH (bez zlib)\n');
fprintf('====================================\n\n');

txt = fileread(jsonFile);
data = jsondecode(txt);

% Sprawdź WSZYSTKIE obiekty bitmap
numBitmaps = 0;
for i = 1:length(data.objects)
    obj = data.objects{i};
    
    if strcmp(obj.geometryType, 'bitmap')
        numBitmaps = numBitmaps + 1;
        
        fprintf('📌 BITMAP #%d: %s\n', numBitmaps, obj.classTitle);
        fprintf('   Origin: [%d, %d]\n', obj.bitmap.origin(1), obj.bitmap.origin(2));
        
        % Dekoduj base64
        bitmapData = obj.bitmap.data;
        binaryData = matlab.net.base64decode(bitmapData);
        
        fprintf('   Base64 → %d bajtów\n', length(binaryData));
        fprintf('   Pierwsze 16 bajtów: %s\n', mat2str(binaryData(1:min(16,end))'));
        
        % Sprawdź czy to PNG bezpośrednio
        pngSignature = uint8([137, 80, 78, 71, 13, 10, 26, 10]);
        isPNG = false;
        if length(binaryData) >= 8
            isPNG = isequal(binaryData(1:8), pngSignature);  % POPRAWIONE
        end
        
        if isPNG
            fprintf('   ✓✓✓ TO JEST PNG! (bez zlib)\n');
            
            % Zapisz i wczytaj jako PNG
            tempFile = fullfile(tempdir, sprintf('direct_png_%d.png', numBitmaps));
            fid = fopen(tempFile, 'wb');
            fwrite(fid, binaryData, 'uint8');
            fclose(fid);
            
            try
                img = imread(tempFile);
                delete(tempFile);
                
                fprintf('   ✓ Wczytano jako PNG: %dx%d\n', size(img,1), size(img,2));
                fprintf('   Unikalne wartości: %s\n', mat2str(unique(img(1:min(100,end)))'));
                
                % Pokaż
                figure('Name', sprintf('BITMAP #%d: %s', numBitmaps, obj.classTitle));
                subplot(1,2,1);
                imshow(img);
                title('Oryginalna maska');
                
                subplot(1,2,2);
                % Kolorowa wersja
                if size(img,3) == 1
                    mask = img > 0;
                    maskRGB = cat(3, double(mask), double(mask)*0.8, zeros(size(mask)));
                    imshow(maskRGB);
                    title(sprintf('Kolorowa\n%d pikseli aktywnych', sum(mask(:))));
                else
                    imshow(img);
                    title('RGB');
                end
                
            catch ME
                fprintf('   ❌ Błąd odczytu PNG: %s\n', ME.message);
            end
            
        % Sprawdź czy to JPEG
        elseif length(binaryData) >= 2 && binaryData(1) == 255 && binaryData(2) == 216
            fprintf('   ✓✓✓ TO JEST JPEG!\n');
            
        % Sprawdź czy to zlib (0x78 = 120)
        elseif binaryData(1) == 120
            fprintf('   → To ZLIB, próba dekompresji...\n');
            
            try
                % Dekompresja
                import java.util.zip.Inflater;
                import java.io.ByteArrayOutputStream;
                
                inflater = Inflater();
                inflater.setInput(binaryData);
                
                outputStream = ByteArrayOutputStream();
                buffer = zeros(1024, 1, 'uint8');
                
                while ~inflater.finished()
                    count = inflater.inflate(buffer);
                    if count > 0
                        outputStream.write(buffer, 0, count);
                    end
                end
                
                decompressed = outputStream.toByteArray();
                inflater.end();
                
                fprintf('   Zlib → %d bajtów\n', length(decompressed));
                
                if length(decompressed) > 0
                    fprintf('   Pierwsze 20: %s\n', mat2str(decompressed(1:min(20,end))'));
                    fprintf('   Suma wartości: %d\n', sum(double(decompressed)));
                    fprintf('   Niezerowe bajty: %d / %d (%.1f%%)\n', ...
                            sum(decompressed~=0), length(decompressed), ...
                            100*sum(decompressed~=0)/length(decompressed));
                    
                    % Sprawdź czy po dekompresji to PNG
                    isPNGAfterZlib = false;
                    if length(decompressed) >= 8
                        isPNGAfterZlib = isequal(decompressed(1:8), pngSignature);
                    end
                    
                    if isPNGAfterZlib
                        fprintf('   ✓✓✓ Po zlib: PNG!\n');
                        
                        tempFile = fullfile(tempdir, sprintf('zlib_png_%d.png', numBitmaps));
                        fid = fopen(tempFile, 'wb');
                        fwrite(fid, decompressed, 'uint8');
                        fclose(fid);
                        
                        img = imread(tempFile);
                        delete(tempFile);
                        
                        fprintf('   ✓ Wczytano: %dx%d\n', size(img,1), size(img,2));
                        
                        % Pokaż
                        figure('Name', sprintf('ZLIB→PNG #%d: %s', numBitmaps, obj.classTitle));
                        subplot(1,2,1);
                        imshow(img);
                        title('Maska po zlib');
                        
                        subplot(1,2,2);
                        if size(img,3) == 1
                            mask = img > 0;
                        else
                            mask = rgb2gray(img) > 0;
                        end
                        maskRGB = cat(3, double(mask), double(mask)*0.8, zeros(size(mask)));
                        imshow(maskRGB);
                        title(sprintf('%d pikseli', sum(mask(:))));
                        
                    else
                        % To nie PNG, próbuj jako raw bitmap
                        fprintf('   → Po zlib: RAW DATA (nie PNG)\n');
                        
                        % Spróbuj różnych interpretacji
                        totalBytes = length(decompressed);
                        
                        % Szukaj wymiarów dla raw 8-bit
                        foundDim = false;
                        for w = 5:100
                            if mod(totalBytes, w) == 0
                                h = totalBytes / w;
                                if h >= 5 && h <= 100
                                    fprintf('   Możliwy wymiar 8-bit: %dx%d\n', h, w);
                                    
                                    if ~foundDim  % Pokaż tylko pierwszy
                                        img8bit = reshape(decompressed, [w, h])';
                                        
                                        figure('Name', sprintf('RAW 8-bit #%d: %s', numBitmaps, obj.classTitle));
                                        subplot(1,3,1);
                                        imagesc(img8bit);
                                        colormap(hot);
                                        title(sprintf('Raw 8-bit %dx%d', h, w));
                                        colorbar;
                                        
                                        subplot(1,3,2);
                                        mask = img8bit > 0;
                                        imshow(mask);
                                        title(sprintf('Binarna\n%d pikseli', sum(mask(:))));
                                        
                                        subplot(1,3,3);
                                        maskRGB = cat(3, double(mask), double(mask)*0.8, zeros(size(mask)));
                                        imshow(maskRGB);
                                        title('Kolorowa');
                                        
                                        foundDim = true;
                                    end
                                    
                                    if foundDim, break; end
                                end
                            end
                        end
                        
                        if ~foundDim
                            fprintf('   ⚠ Nie znaleziono odpowiednich wymiarów\n');
                        end
                    end
                else
                    fprintf('   ❌ Dekompresja dała 0 bajtów!\n');
                end
                
            catch ME
                fprintf('   ❌ Błąd zlib: %s\n', ME.message);
                fprintf('      Typ: %s\n', ME.identifier);
            end
        else
            fprintf('   ❌ Nieznany format!\n');
            fprintf('   Magic bytes: 0x%02X 0x%02X\n', binaryData(1), binaryData(2));
        end
        
        fprintf('\n');
    end
end

fprintf('====================================\n');
fprintf('Znaleziono %d bitmap\n', numBitmaps);