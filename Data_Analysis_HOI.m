%% === CONFIGURACIÓN ===
base_dir = 'C:\Users\Felipe Carriel\Documents\Brain\High-Order-interactions\Ongoing_EEG_Source_analysis_Loreta_para_redes';
grupos = {'CN', 'AD', 'DFT'};
target_network = "DEFAULT";  % <<-- Cambiar si deseas calcular otra red
n_samples_to_use = 200000;  % <-- puedes cambiarlo según lo que necesites



% Archivos de apoyo
filename_rois = fullfile(base_dir, 'rois_export.xlsx');
filename_rsn  = fullfile(base_dir, 'RSN_regiones.csv');

% Crear carpetas HOI si no existen
for g = 1:length(grupos)
    out_dir = fullfile(base_dir, sprintf('%s_HOI', grupos{g}));
    if ~exist(out_dir, 'dir')
        mkdir(out_dir);
    end
end

%% === CARGAR NOMBRES DE REGIONES ===
tbl_rois = readtable(filename_rois);
roi_names = string(tbl_rois.region);

%% === CARGAR DEFINICIÓN DE REDES FUNCIONALES (RSNs) ===
tbl_rsn = readtable(filename_rsn);
tbl_rsn.Red = string(tbl_rsn.Red);
tbl_rsn.Region = string(tbl_rsn.Region);
unique_networks = unique(tbl_rsn.Red);

fprintf('✔️ Se cargaron %d regiones mapeadas a %d redes funcionales\n', ...
    height(tbl_rsn), numel(unique_networks));

%% === RECORRER CADA GRUPO Y SUJETOS ===
for g = 1:length(grupos)
    grupo = grupos{g};
    folder_path = fullfile(base_dir, grupo);
    out_path = fullfile(base_dir, sprintf('%s_HOI', grupo));

    files = dir(fullfile(folder_path, '*-sLorRoi.txt'));
    fprintf('\n🔸 Procesando grupo: %s (%d sujetos)\n', grupo, numel(files));

    Npatients = numel(files);  % número de sujetos
    for f = 1:Npatients
        file_path = fullfile(folder_path, files(f).name);
        fprintf('\n📄 Sujetos: %s\n', files(f).name);

        %% === CARGAR DATOS DE REGIONES ===
        opts = detectImportOptions(file_path, ...
            'Delimiter', ' ', ...
            'ConsecutiveDelimitersRule', 'join', ...
            'ReadVariableNames', false);
        tbl_raw = readtable(file_path, opts);

        is_numeric_col = varfun(@isnumeric, tbl_raw, 'OutputFormat', 'uniform');
        data_matrix = table2array(tbl_raw(:, is_numeric_col));

        [n_samples, n_rois] = size(data_matrix);
        if length(roi_names) ~= n_rois
            warning('⚠️ No coincide el número de regiones con nombres en archivo: %s', files(f).name);
            continue
        end

        tbl_named = array2table(data_matrix, 'VariableNames', roi_names);

        %% === EXTRAER DATOS DE LA RED DE INTERÉS ===
        regions_in_network = tbl_rsn.Region(tbl_rsn.Red == target_network);
        valid_regions = regions_in_network(ismember(regions_in_network, tbl_named.Properties.VariableNames));

        if isempty(valid_regions)
            continue
        end

        tbl_sub = tbl_named(:, valid_regions);
        data = table2array(tbl_sub);  % (T x m)
        m = size(data, 2);

                %% === CALCULAR HIGH ORDER INTERACTIONS DE NIVEL 3 a m ===
        for n = 3:m
            fprintf('🔺 Calculando HOI para red %s (n = %d)...\n', target_network, n);

            % Asegurarse de que no se excedan los samples disponibles
            max_samples = size(data, 1);
            n_use = min(n_samples_to_use, max_samples);

            data_cut = data(1:n_use, :)';  % Transponer para obtener (m x T)

            % Inicializar vectores de salida
            Red = zeros(1, m);
            Syn = zeros(1, m);

            try
                [Oinfo, Sinfo, red_, syn_] = high_order(data_cut, n);  % <- función externa
                Red(1,:) = red_;
                Syn(1,:) = syn_;
            catch ME
                warning(ME.identifier, '❌ Error en high_order(): %s', ME.message);
                continue
            end

            % Guardar resultados en .csv
            % Crear nombre base para guardar
            subject_id = erase(files(f).name, '-sLorRoi.txt');
            prefix_out = fullfile(out_path, sprintf('%s_%s_n%d', subject_id, strrep(target_network, ' ', '_'), n));
            
            % Guardar Oinfo y Sinfo
            writematrix(Oinfo, [prefix_out, '_Oinfo.csv']);
            writematrix(Sinfo, [prefix_out, '_Sinfo.csv']);
            
            % Guardar tabla con resumen por región
            T_summary = table(string(valid_regions), Red(:), Syn(:), ...
                'VariableNames', {'Region', 'Red', 'Syn'});
            writetable(T_summary, [prefix_out, '_Summary.csv']);

        end        
    end
end
