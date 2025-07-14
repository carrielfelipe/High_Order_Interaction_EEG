%% === CARGAR DATOS DE ACTIVIDAD EN REGIONES (LORETA SOURCE-LEVEL DATA) ===
% Ruta al archivo con datos fuente por región
filename_region_data = 'Ongoing_EEG_Source_analysis_Loreta_para_redes/CN/new_s101_CH_-sLorRoi.txt';

% Detectar opciones de importación
opts = detectImportOptions(filename_region_data, ...
    'Delimiter', ' ', ...
    'ConsecutiveDelimitersRule', 'join', ...
    'ReadVariableNames', false);

% Leer archivo como tabla sin nombres de variables
tbl_raw_region = readtable(filename_region_data, opts);

% Filtrar solo columnas numéricas
is_numeric_col = varfun(@isnumeric, tbl_raw_region, 'OutputFormat', 'uniform');
region_data_matrix = table2array(tbl_raw_region(:, is_numeric_col));

% Reportar dimensiones
[n_samples, n_rois] = size(region_data_matrix);
fprintf('✔️ Datos de regiones cargados: %d muestras por %d regiones\n', n_samples, n_rois);

%% === CARGAR NOMBRES DE REGIONES ===
filename_rois = 'rois_export.xlsx';
tbl_rois = readtable(filename_rois);  % Asegúrate de que tenga la columna 'region'

% Convertir a texto (string array)
roi_names = string(tbl_rois.region);

% Verificar correspondencia con las columnas del archivo de datos
if length(roi_names) ~= n_rois
    error('❌ El número de regiones en el archivo ROI (%d) no coincide con las columnas de los datos (%d)', ...
        length(roi_names), n_rois);
end

%% === CREAR TABLA CON NOMBRES DE REGIONES ===
tbl_region_named = array2table(region_data_matrix, 'VariableNames', roi_names);

%% === CARGAR DEFINICIÓN DE REDES FUNCIONALES (RSNs) ===
filename_rsn = 'RSN_regiones.csv';
tbl_rsn = readtable(filename_rsn);  % Debe tener columnas: Red, Region

% Asegurar formato string
tbl_rsn.Red = string(tbl_rsn.Red);
tbl_rsn.Region = string(tbl_rsn.Region);

fprintf('✔️ Se cargaron %d regiones mapeadas a %d redes funcionales\n', ...
    height(tbl_rsn), numel(unique(tbl_rsn.Red)));



% Obtener lista única de redes funcionales
unique_networks = unique(tbl_rsn.Red);

% Recorrer cada red funcional
for i = 1:numel(unique_networks)
    
    current_network = unique_networks(i);
    
    % Obtener regiones asociadas a esta red
    regions_in_network = tbl_rsn.Region(tbl_rsn.Red == current_network);
    
    % Verificar que las regiones estén presentes en los nombres de columnas
    valid_regions = regions_in_network(ismember(regions_in_network, tbl_region_named.Properties.VariableNames));
    
    % Seleccionar columnas correspondientes
    tbl_sub = tbl_region_named(:, valid_regions);
    
    % Mostrar información
    fprintf('\n🔷 Red: %s\n', current_network);
    fprintf('Regiones asociadas (%d):\n', numel(valid_regions));
    disp(valid_regions')

    fprintf('Primeras 5 filas de datos:\n');
    disp(tbl_sub(1:5, :));  % Mostrar primeras 5 muestras para esas regiones
    
end


